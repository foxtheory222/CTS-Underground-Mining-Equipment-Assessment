import 'dart:io';

import 'package:cts_underground_mining_assessment/core/constants.dart';
import 'package:cts_underground_mining_assessment/core/validators.dart';
import 'package:cts_underground_mining_assessment/data/models/inspection_enums.dart';
import 'package:cts_underground_mining_assessment/data/models/inspection_models.dart';
import 'package:cts_underground_mining_assessment/data/repositories/inspection_repository.dart';
import 'package:cts_underground_mining_assessment/services/document_number_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../support/persistence_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late TestAppDatabase database;
  late InspectionRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('inspection_repo_test_');
    database = TestAppDatabase(tempDir);
    repository = InspectionRepository(
      database: database,
      documentNumberService: DocumentNumberService(),
      uuid: const Uuid(),
    );
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'duplicateInspection copies only header fields and assigns new document number',
    () async {
      final source = buildInspection(
        id: 'source',
        documentNumber: '20260420-0001',
        status: InspectionStatus.complete,
        completedAt: DateTime.utc(2026, 4, 20, 12, 30),
        signatureFilePath: '/tmp/signature.png',
      );
      fillRequiredResponses(source);
      source.photos.add(
        InspectionPhoto(
          id: 'photo-1',
          inspectionId: source.id,
          sectionKey: InspectionSectionKeys.fluidTankService,
          itemKey: InspectionItemKeys.tankIntegrity,
          filePath: '/tmp/photo.jpg',
          caption: 'Damage',
          sortOrder: 0,
          capturedAt: DateTime.utc(2026, 4, 20, 12, 0),
          createdAt: DateTime.utc(2026, 4, 20, 12, 0),
        ),
      );

      final duplicate = await repository.duplicateInspection(
        source,
        createdAt: DateTime.utc(2026, 4, 21, 8, 0),
      );

      expect(duplicate.documentNumber, isNot(source.documentNumber));
      expect(duplicate.customer, source.customer);
      expect(duplicate.workOrderNumber, source.workOrderNumber);
      expect(duplicate.responses, isEmpty);
      expect(duplicate.photos, isEmpty);
      expect(duplicate.actionItems, isEmpty);
      expect(duplicate.signatureFilePath, isNull);
      expect(duplicate.completedAt, isNull);
      expect(duplicate.emailedAt, isNull);
      expect(duplicate.status, InspectionStatus.inProgress);
    },
  );

  test('saving an emailed inspection clears emailed state on edit', () async {
    final pdfFile = File(
      '${tempDir.path}${Platform.pathSeparator}generated.pdf',
    );
    await pdfFile.writeAsBytes(<int>[1, 2, 3, 4], flush: true);
    final inspection = buildInspection(
      id: 'save-edit',
      documentNumber: '20260420-0002',
      status: InspectionStatus.inProgress,
    );
    fillRequiredResponses(inspection);
    inspection.signatureFilePath = '/tmp/signature.png';
    inspection.completedAt = DateTime.utc(2026, 4, 20, 12, 30);

    final completed = await repository.saveInspection(inspection);
    expect(completed.status, InspectionStatus.complete);
    completed.generatedPdfPath = pdfFile.path;

    final emailed = await repository.markEmailed(completed);
    expect(emailed.status, InspectionStatus.emailed);
    expect(emailed.emailedAt, isNotNull);

    emailed.customer = 'Updated Customer';
    final edited = await repository.saveInspection(emailed);

    expect(edited.emailedAt, isNull);
    expect(edited.generatedPdfPath, isNull);
    expect(edited.status, InspectionStatus.complete);
    expect(edited.customer, 'Updated Customer');
  });

  test('markEmailed rejects incomplete inspections', () async {
    final inspection = buildInspection(
      id: 'email-incomplete',
      documentNumber: '20260420-0005',
      status: InspectionStatus.inProgress,
      customer: '',
      signatureFilePath: null,
    );
    final pdfFile = File(
      '${tempDir.path}${Platform.pathSeparator}generated.pdf',
    );
    await pdfFile.writeAsBytes(<int>[1, 2, 3, 4], flush: true);
    inspection.generatedPdfPath = pdfFile.path;

    await expectLater(
      () => repository.markEmailed(inspection),
      throwsA(
        isA<InspectionRepositoryException>().having(
          (InspectionRepositoryException error) => error.code,
          'code',
          InspectionRepositoryErrorCode.invalidCompletion,
        ),
      ),
    );
  });

  test(
    'markEmailed rejects complete inspections without a generated PDF',
    () async {
      final inspection = buildInspection(
        id: 'email-no-pdf',
        documentNumber: '20260420-0006',
        status: InspectionStatus.inProgress,
      );
      fillRequiredResponses(inspection);
      inspection.signatureFilePath = '/tmp/signature.png';
      inspection.completedAt = DateTime.utc(2026, 4, 20, 12, 30);

      final completed = await repository.saveInspection(inspection);
      expect(completed.status, InspectionStatus.complete);

      await expectLater(
        () => repository.markEmailed(completed),
        throwsA(
          isA<InspectionRepositoryException>().having(
            (InspectionRepositoryException error) => error.code,
            'code',
            InspectionRepositoryErrorCode.missingGeneratedPdf,
          ),
        ),
      );
    },
  );

  test(
    'search finds inspections by work order, customer, asset, document, and technician',
    () async {
      final inspection = buildInspection(
        id: 'searchable',
        documentNumber: '20260420-0003',
        status: InspectionStatus.inProgress,
        customer: 'Moraine Underground',
        workOrderNumber: 'WO-4242',
        customerReference: 'PO-4242',
        assetName: 'Boom Lift',
        technicianName: 'Taylor Smith',
      );
      fillRequiredResponses(inspection);
      inspection.signatureFilePath = '/tmp/signature.png';
      inspection.completedAt = DateTime.utc(2026, 4, 20, 12, 30);
      await repository.saveInspection(inspection);

      expect(
        await repository.search(const InspectionSearchQuery(term: 'WO-4242')),
        hasLength(1),
      );
      expect(
        await repository.search(
          const InspectionSearchQuery(term: 'Moraine Underground'),
        ),
        hasLength(1),
      );
      expect(
        await repository.search(const InspectionSearchQuery(term: 'Boom Lift')),
        hasLength(1),
      );
      expect(
        await repository.search(
          const InspectionSearchQuery(term: '20260420-0003'),
        ),
        hasLength(1),
      );
      expect(
        await repository.search(
          const InspectionSearchQuery(term: 'Taylor Smith'),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'importInspectionJson persists imported records and restored media',
    () async {
      final restoredPhoto = File(
        '${tempDir.path}${Platform.pathSeparator}restored-photo.jpg',
      );
      await restoredPhoto.writeAsBytes(<int>[
        0xff,
        0xd8,
        0xff,
        0xd9,
      ], flush: true);
      final restoredPdf = File(
        '${tempDir.path}${Platform.pathSeparator}restored-report.pdf',
      );
      await restoredPdf.writeAsBytes(<int>[1, 2, 3, 4], flush: true);
      final source = buildInspection(
        id: 'source-import',
        documentNumber: '20260420-0900',
        status: InspectionStatus.inProgress,
        generatedPdfPath: '/old/generated.pdf',
        photos: <InspectionPhoto>[
          InspectionPhoto(
            id: 'source-photo',
            inspectionId: 'source-import',
            sectionKey: InspectionSectionKeys.fluidTankService,
            itemKey: InspectionItemKeys.tankIntegrity,
            filePath: '/old/photo.jpg',
            caption: 'Before import',
            sortOrder: 0,
            capturedAt: DateTime.utc(2026, 4, 20, 12),
            createdAt: DateTime.utc(2026, 4, 20, 12),
          ),
        ],
      );

      final imported = await repository.importInspectionJson(
        source.toJson(),
        restoredPhotoFiles: <File>[restoredPhoto],
        restoredPdfFile: restoredPdf,
      );

      expect(imported.id, isNot('source-import'));
      expect(imported.documentNumber, '20260420-0900');
      expect(imported.photos.single.inspectionId, imported.id);
      expect(imported.photos.single.filePath, restoredPhoto.path);
      expect(imported.generatedPdfPath, restoredPdf.path);
      expect(
        await repository.getInspectionByDocumentNumber('20260420-0900'),
        isNotNull,
      );
    },
  );

  test('validation helper detects a complete inspection', () {
    final inspection = buildInspection(
      id: 'validate',
      documentNumber: '20260420-0004',
      status: InspectionStatus.inProgress,
    );
    fillRequiredResponses(inspection);
    inspection.signatureFilePath = '/tmp/signature.png';
    inspection.completedAt = DateTime.utc(2026, 4, 20, 12, 30);

    final validation = InspectionValidator.validateForCompletion(inspection);
    expect(validation.isValid, isTrue);
  });
}
