import 'dart:io';

import 'package:cts_underground_mining_assessment/data/repositories/inspection_repository.dart';
import 'package:cts_underground_mining_assessment/services/document_number_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cts_underground_mining_assessment/core/workspace_controller.dart';

import '../support/persistence_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  test('demo document numbers increment and search filters records', () async {
    final controller = AppWorkspaceController();

    final created = await controller.createInspection();
    expect(created.documentNumber, matches(RegExp(r'^\d{8}-\d{4}$')));

    final duplicate = await controller.duplicateInspection(
      controller.inspections.first,
    );
    expect(duplicate.documentNumber, isNot(equals(created.documentNumber)));
    expect(duplicate.sections.length, 8);

    controller.setSearchQuery('North Basin');
    expect(controller.filteredInspections.length, 1);
    expect(
      controller.filteredInspections.first.customer,
      'North Basin Processing',
    );
  });

  test(
    'repository-backed workspace creates and reloads persisted records',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'workspace_controller_repo_',
      );
      final database = TestAppDatabase(tempDir);
      addTearDown(() async {
        await database.close();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final repository = InspectionRepository(
        database: database,
        documentNumberService: DocumentNumberService(),
      );
      final controller = AppWorkspaceController(
        repository: repository,
        autoLoad: false,
      );

      final created = await controller.createInspection(
        createdAt: DateTime.utc(2026, 4, 20, 8),
      );
      expect(created.documentNumber, '20260420-0001');
      expect(await repository.getInspection(created.id), isNotNull);

      final duplicate = await controller.duplicateInspection(
        created,
        createdAt: DateTime.utc(2026, 4, 20, 9),
      );
      expect(duplicate.documentNumber, '20260420-0002');

      final reloaded = AppWorkspaceController(
        repository: repository,
        autoLoad: false,
      );
      await reloaded.refresh();

      expect(reloaded.inspections.map((item) => item.documentNumber), <String>[
        '20260420-0002',
        '20260420-0001',
      ]);
    },
  );
}
