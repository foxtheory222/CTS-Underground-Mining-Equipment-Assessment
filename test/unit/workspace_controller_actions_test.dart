import 'dart:io';
import 'dart:typed_data';

import 'package:cts_underground_mining_assessment/core/underground_template.dart';
import 'package:cts_underground_mining_assessment/core/workspace_controller.dart';
import 'package:cts_underground_mining_assessment/core/workspace_models.dart';
import 'package:cts_underground_mining_assessment/data/models/inspection_enums.dart';
import 'package:cts_underground_mining_assessment/data/repositories/inspection_repository.dart';
import 'package:cts_underground_mining_assessment/services/backup_service.dart';
import 'package:cts_underground_mining_assessment/services/document_number_service.dart';
import 'package:cts_underground_mining_assessment/services/email_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/persistence_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late TestAppDatabase database;
  late InspectionRepository repository;
  late FakeEmailShareAdapter emailAdapter;
  late AppWorkspaceController controller;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'workspace_controller_actions_test_',
    );
    database = TestAppDatabase(tempDir);
    repository = InspectionRepository(
      database: database,
      documentNumberService: DocumentNumberService(),
    );
    emailAdapter = FakeEmailShareAdapter();
    controller = AppWorkspaceController(
      repository: repository,
      autoLoad: false,
      emailService: EmailService(
        shareAdapter: emailAdapter,
        recipientStore: JsonFileRecipientStore(
          documentsDirectoryProvider: () async => tempDir,
        ),
      ),
      backupService: BackupService(
        documentsDirectoryProvider: () async => tempDir,
      ),
      reportDirectoryProvider: (inspectionId) async {
        final directory = Directory(
          p.join(tempDir.path, 'reports', inspectionId),
        );
        await directory.create(recursive: true);
        return directory;
      },
      signatureDirectoryProvider: (inspectionId) async {
        final directory = Directory(
          p.join(tempDir.path, 'signatures', inspectionId),
        );
        await directory.create(recursive: true);
        return directory;
      },
    );
  });

  tearDown(() async {
    await database.close();
    controller.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'generates, shares, marks emailed, and exports persisted reports',
    () async {
      final inspection = buildInspection(
        id: 'report-actions',
        documentNumber: '20260420-2001',
        status: InspectionStatus.inProgress,
        signatureFilePath: p.join(tempDir.path, 'signature.png'),
      );
      fillRequiredResponses(inspection);
      final saved = await repository.saveInspection(inspection);
      expect(saved.status, InspectionStatus.complete);
      await controller.refresh();

      final pdf = await controller.generatePdfForInspection(saved.id);
      expect(await pdf.exists(), isTrue);
      expect(await pdf.length(), greaterThan(0));

      final exportResult = await controller.exportInspectionBundle(saved.id);
      expect(await exportResult.archiveFile.exists(), isTrue);
      expect(exportResult.exportedFileCount, greaterThanOrEqualTo(2));

      final handoff = await controller.sharePdfForInspection(
        saved.id,
        recipients: const <String>['service@example.com'],
      );
      expect(handoff.launched, isTrue);
      expect(emailAdapter.lastSharedPdf?.path, pdf.path);
      expect(emailAdapter.lastSubject, contains(saved.documentNumber));

      final emailed = await repository.getInspection(saved.id);
      expect(emailed?.status, InspectionStatus.emailed);
      expect(emailed?.emailedAt, isNotNull);
    },
  );

  test('form draft save creates a complete PDF-ready inspection', () async {
    final inspection = await controller.createInspection(
      createdAt: DateTime.utc(2026, 4, 20, 8),
    );

    final saved = await controller.saveFormDraft(
      InspectionFormDraft(
        inspectionId: inspection.id,
        customer: 'Moraine Underground',
        mineSite: 'North Decline',
        manufacturer: 'MacLean',
        model: 'SL3',
        serialNumber: 'RS-1001',
        machineHours: '12450',
        inspector: 'R. Ellis',
        selectedPurposes: const <String>{'Condition Assessment'},
        healthScores: <String, int>{
          for (final field in UndergroundTemplate.healthScoreFields)
            field.key: field.max,
        },
        machineType: 'Rock Scaler',
        assetStatus: 'Good',
        rating: 'Good',
        finalRecommendation: 'Continue Operating',
        critical: false,
        criticalAcknowledged: false,
        comment: 'Machine operating within service limits.',
        costComponent: 'Hydraulic pumps',
        costRepair: 'Reseal and bench test',
        costAmount: '18500',
        costDowntime: '2 shifts',
        signaturePngBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      ),
    );

    expect(saved.status, InspectionStatus.complete);
    expect(saved.customer, 'Moraine Underground');
    expect(saved.generatedPdfPath, isNull);

    final pdf = await controller.generatePdfForInspection(saved.id);
    expect(await pdf.exists(), isTrue);
    expect(await pdf.length(), greaterThan(0));
  });
}
