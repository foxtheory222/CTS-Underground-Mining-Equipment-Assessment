import 'dart:io';
import 'dart:typed_data';

import 'package:cts_underground_mining_assessment/core/underground_template.dart';
import 'package:cts_underground_mining_assessment/core/validators.dart';
import 'package:cts_underground_mining_assessment/core/workspace_controller.dart';
import 'package:cts_underground_mining_assessment/core/workspace_models.dart';
import 'package:cts_underground_mining_assessment/data/models/inspection_enums.dart';
import 'package:cts_underground_mining_assessment/data/models/inspection_models.dart';
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
        itemRatings: _allGoodChecklistRatings(),
        itemValues: _allNarrativeValues(),
        signaturePngBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        customerSignaturePngBytes: Uint8List.fromList(const <int>[5, 6, 7, 8]),
      ),
    );

    expect(saved.status, InspectionStatus.complete);
    expect(saved.customer, 'Moraine Underground');
    final savedRecord = await repository.getInspection(saved.id);
    expect(savedRecord?.customerSignatureFilePath, isNotNull);
    expect(
      await File(savedRecord!.customerSignatureFilePath!).exists(),
      isTrue,
    );
    expect(saved.generatedPdfPath, isNull);

    final pdf = await controller.generatePdfForInspection(saved.id);
    expect(await pdf.exists(), isTrue);
    expect(await pdf.length(), greaterThan(0));
  });

  test('form draft never fabricates ratings or narrative results', () async {
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
        comment: 'Header-level observation.',
        costComponent: 'Hydraulic pumps',
        costRepair: 'Reseal and bench test',
        costAmount: '18500',
        costDowntime: '2 shifts',
        signaturePngBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      ),
    );

    expect(saved.status, InspectionStatus.inProgress);
    final record = await repository.getInspection(saved.id);
    final mainFrameKey = InspectionValidator.templateItemKey(
      'structural_inspection',
      'Main Frame',
    );
    final mainFrame = record?.responseByKey(
      'structural_inspection',
      mainFrameKey,
    );
    expect(mainFrame?.value, isEmpty);
    expect(mainFrame?.conditionRating, isNull);
    expect(
      InspectionValidator.validateForCompletion(record!).issues,
      contains(
        isA<ValidationIssue>().having(
          (issue) => issue.itemKey,
          'itemKey',
          mainFrameKey,
        ),
      ),
    );
  });

  test(
    'clearing hydrated signatures removes their persisted references',
    () async {
      final inspection = buildInspection(
        id: 'clear-signatures',
        documentNumber: '20260420-2100',
        status: InspectionStatus.complete,
        signatureFilePath: p.join(tempDir.path, 'technician.png'),
      );
      inspection.customerSignatureFilePath = p.join(
        tempDir.path,
        'customer.png',
      );
      fillRequiredResponses(inspection);
      await repository.saveInspection(inspection);

      final saved = await controller.saveFormDraft(
        _completeFormDraft(
          inspection.id,
          clearTechnicianSignature: true,
          clearCustomerSignature: true,
        ),
      );

      final record = await repository.getInspection(saved.id);
      expect(record?.signatureFilePath, isNull);
      expect(record?.customerSignatureFilePath, isNull);
      expect(saved.status, InspectionStatus.inProgress);
    },
  );

  test(
    'form draft save persists captured per-item checklist responses',
    () async {
      final inspection = await controller.createInspection(
        createdAt: DateTime.utc(2026, 4, 20, 8),
      );
      final section = UndergroundTemplate.sections.firstWhere(
        (section) => section.key == 'structural_inspection',
      );
      final itemKey = InspectionValidator.templateItemKey(
        section.key,
        'Main Frame',
      );

      await controller.saveFormDraft(
        InspectionFormDraft(
          inspectionId: inspection.id,
          customer: 'Moraine Underground',
          mineSite: 'North Decline',
          manufacturer: 'Sandvik',
          model: 'DD422i',
          serialNumber: 'DD-1001',
          machineHours: '9000',
          inspector: 'R. Ellis',
          selectedPurposes: const <String>{'Condition Assessment'},
          healthScores: <String, int>{
            for (final field in UndergroundTemplate.healthScoreFields)
              field.key: field.max,
          },
          machineType: 'Jumbo',
          assetStatus: 'Fair',
          rating: 'Good',
          finalRecommendation: 'Monitor Monthly',
          critical: false,
          criticalAcknowledged: false,
          comment: 'Global comment.',
          costComponent: '',
          costRepair: '',
          costAmount: '',
          costDowntime: '',
          itemRatings: <String, String>{itemKey: 'Poor'},
          itemComments: <String, String>{
            itemKey: 'Crack found near articulation weld.',
          },
          signaturePngBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
          createActionItem: true,
          actionSectionKey: section.key,
          actionItemKey: itemKey,
          actionItemLabel: 'Main Frame',
        ),
      );

      final saved = await repository.getInspection(inspection.id);
      final response = saved?.responseByKey(section.key, itemKey);
      expect(response?.value, 'Poor');
      expect(response?.conditionRating, ConditionRating.unsatisfactory);
      expect(response?.isFlagged, isTrue);
      expect(response?.comment, 'Crack found near articulation weld.');
      expect(
        saved?.actionItems,
        contains(
          isA<ActionItem>()
              .having(
                (action) => action.sourceSectionKey,
                'sourceSectionKey',
                section.key,
              )
              .having(
                (action) => action.sourceItemKey,
                'sourceItemKey',
                itemKey,
              )
              .having(
                (action) => action.title,
                'title',
                'Main Frame follow-up',
              ),
        ),
      );
    },
  );

  test(
    'form draft save persists item ratings beyond the first twelve section items',
    () async {
      final inspection = await controller.createInspection(
        createdAt: DateTime.utc(2026, 4, 20, 8),
      );
      final section = UndergroundTemplate.sections.firstWhere(
        (section) => section.key == 'structural_inspection',
      );
      final itemLabel = section.items[12];
      final itemKey = InspectionValidator.templateItemKey(
        section.key,
        itemLabel,
      );

      await controller.saveFormDraft(
        InspectionFormDraft(
          inspectionId: inspection.id,
          customer: 'Moraine Underground',
          mineSite: 'North Decline',
          manufacturer: 'Sandvik',
          model: 'DD422i',
          serialNumber: 'DD-1001',
          machineHours: '9000',
          inspector: 'R. Ellis',
          selectedPurposes: const <String>{'Condition Assessment'},
          healthScores: <String, int>{
            for (final field in UndergroundTemplate.healthScoreFields)
              field.key: field.max,
          },
          machineType: 'Jumbo',
          assetStatus: 'Fair',
          rating: 'Good',
          finalRecommendation: 'Monitor Monthly',
          critical: false,
          criticalAcknowledged: false,
          comment: 'Global comment.',
          costComponent: '',
          costRepair: '',
          costAmount: '',
          costDowntime: '',
          itemRatings: <String, String>{itemKey: 'Fair'},
          itemComments: <String, String>{
            itemKey: 'Wear found on late-section structure item.',
          },
          signaturePngBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        ),
      );

      final saved = await repository.getInspection(inspection.id);
      final response = saved?.responseByKey(section.key, itemKey);
      expect(itemLabel, 'Pins & Bushings');
      expect(response?.value, 'Fair');
      expect(response?.conditionRating, ConditionRating.monitorAtRisk);
      expect(response?.isFlagged, isTrue);
      expect(response?.comment, 'Wear found on late-section structure item.');
    },
  );

  test(
    'form draft preserves not inspected and not applicable without false flags',
    () async {
      final inspection = await controller.createInspection(
        createdAt: DateTime.utc(2026, 4, 20, 8),
      );
      final section = UndergroundTemplate.sections.firstWhere(
        (section) => section.key == 'structural_inspection',
      );
      final notInspectedKey = InspectionValidator.templateItemKey(
        section.key,
        'Main Frame',
      );
      final notApplicableKey = InspectionValidator.templateItemKey(
        section.key,
        'Articulation Area',
      );

      final summary = await controller.saveFormDraft(
        InspectionFormDraft(
          inspectionId: inspection.id,
          customer: 'Moraine Underground',
          mineSite: 'North Decline',
          manufacturer: 'Sandvik',
          model: 'DD422i',
          serialNumber: 'DD-1001',
          machineHours: '9000',
          inspector: 'R. Ellis',
          selectedPurposes: const <String>{'Condition Assessment'},
          healthScores: <String, int>{
            for (final field in UndergroundTemplate.healthScoreFields)
              field.key: field.max,
          },
          machineType: 'Jumbo',
          assetStatus: 'Fair',
          rating: 'Good',
          finalRecommendation: 'Monitor Monthly',
          critical: false,
          criticalAcknowledged: false,
          comment: 'Global comment.',
          costComponent: '',
          costRepair: '',
          costAmount: '',
          costDowntime: '',
          itemRatings: <String, String>{
            notInspectedKey: 'Not Inspected',
            notApplicableKey: 'N/A',
          },
          itemComments: <String, String>{
            notInspectedKey: 'Guarding blocked access during inspection.',
            notApplicableKey:
                'Machine configuration does not include this area.',
          },
          signaturePngBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        ),
      );

      final saved = await repository.getInspection(inspection.id);
      final notInspected = saved?.responseByKey(section.key, notInspectedKey);
      final notApplicable = saved?.responseByKey(section.key, notApplicableKey);
      expect(notInspected?.value, 'Not Inspected');
      expect(notInspected?.isFlagged, isFalse);
      expect(notApplicable?.value, 'N/A');
      expect(notApplicable?.isFlagged, isFalse);
      expect(summary.flaggedCount, 0);
    },
  );

  test(
    'form draft ignores rating maps for non-checklist report inputs',
    () async {
      final inspection = await controller.createInspection(
        createdAt: DateTime.utc(2026, 4, 20, 8),
      );
      const sectionKey = 'machine_identification';
      final oemKey = InspectionValidator.templateItemKey(sectionKey, 'OEM');

      await controller.saveFormDraft(
        InspectionFormDraft(
          inspectionId: inspection.id,
          customer: 'Moraine Underground',
          mineSite: 'North Decline',
          manufacturer: 'Sandvik',
          model: 'DD422i',
          serialNumber: 'DD-1001',
          machineHours: '9000',
          inspector: 'R. Ellis',
          selectedPurposes: const <String>{'Condition Assessment'},
          healthScores: <String, int>{
            for (final field in UndergroundTemplate.healthScoreFields)
              field.key: field.max,
          },
          machineType: 'Jumbo',
          assetStatus: 'Fair',
          rating: 'Good',
          finalRecommendation: 'Monitor Monthly',
          critical: false,
          criticalAcknowledged: false,
          comment: 'Global comment.',
          costComponent: '',
          costRepair: '',
          costAmount: '',
          costDowntime: '',
          itemRatings: <String, String>{oemKey: 'Poor'},
          itemComments: <String, String>{oemKey: 'Should not flag OEM.'},
        ),
      );

      final saved = await repository.getInspection(inspection.id);
      final response = saved?.responseByKey(sectionKey, oemKey);
      expect(response?.value, 'Sandvik');
      expect(response?.conditionRating, isNull);
      expect(response?.isFlagged, isFalse);
      expect(response?.comment, isNull);
    },
  );
}

Map<String, String> _allGoodChecklistRatings() {
  return <String, String>{
    for (final section in UndergroundTemplate.conditionChecklistSections)
      for (final item in section.items)
        InspectionValidator.templateItemKey(section.key, item): 'Good',
  };
}

Map<String, String> _allNarrativeValues() {
  return <String, String>{
    for (final section in UndergroundTemplate.narrativeSections)
      for (final item in section.items)
        InspectionValidator.templateItemKey(section.key, item): 'N/A',
  };
}

InspectionFormDraft _completeFormDraft(
  String inspectionId, {
  bool clearTechnicianSignature = false,
  bool clearCustomerSignature = false,
}) {
  return InspectionFormDraft(
    inspectionId: inspectionId,
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
    itemRatings: _allGoodChecklistRatings(),
    itemValues: _allNarrativeValues(),
    clearTechnicianSignature: clearTechnicianSignature,
    clearCustomerSignature: clearCustomerSignature,
  );
}
