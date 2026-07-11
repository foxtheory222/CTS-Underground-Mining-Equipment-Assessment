import 'dart:io';

import 'package:cts_underground_mining_assessment/core/underground_template.dart';
import 'package:cts_underground_mining_assessment/core/validators.dart';
import 'package:cts_underground_mining_assessment/core/workspace_controller.dart';
import 'package:cts_underground_mining_assessment/core/workspace_models.dart';
import 'package:cts_underground_mining_assessment/core/workspace_providers.dart';
import 'package:cts_underground_mining_assessment/data/models/inspection_enums.dart';
import 'package:cts_underground_mining_assessment/data/models/inspection_models.dart';
import 'package:cts_underground_mining_assessment/features/inspection_form/inspection_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/persistence_test_helpers.dart';

void main() {
  testWidgets('fresh inspection form starts without demo identity values', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InspectionFormScreen())),
    );
    await tester.pump();

    expect(_editableTextWithValue('MacLean'), findsNothing);
    expect(_editableTextWithValue('SL3 Scaler'), findsNothing);
    expect(_editableTextWithValue('Moraine Mine'), findsNothing);
    expect(_editableTextWithValue('RS-1001'), findsNothing);
    expect(_editableTextWithValue('R. Ellis'), findsNothing);
  });

  testWidgets('section checklist items open editable prompts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InspectionFormScreen())),
    );
    await tester.pump();

    final sectionTile = find.widgetWithText(
      ExpansionTile,
      'SECTION 2 - STRUCTURAL INSPECTION',
    );
    await tester.ensureVisible(sectionTile);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(sectionTile);
    await tester.pumpAndSettle();
    final mainFrameLabel = find.text('Main Frame').last;
    await tester.ensureVisible(mainFrameLabel);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(mainFrameLabel);
    await tester.pumpAndSettle();

    expect(find.text('Main Frame prompt'), findsOneWidget);
    expect(find.text('Condition rating'), findsOneWidget);
  });

  testWidgets('checklist prompt includes Critical / Out of Service', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InspectionFormScreen())),
    );
    await tester.pump();

    final sectionTile = find.widgetWithText(
      ExpansionTile,
      'SECTION 2 - STRUCTURAL INSPECTION',
    );
    await tester.ensureVisible(sectionTile);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(sectionTile);
    await tester.pumpAndSettle();
    final mainFrameLabel = find.text('Main Frame').last;
    await tester.ensureVisible(mainFrameLabel);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(mainFrameLabel);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(
        DropdownMenuItem<String>,
        'Critical / Out of Service',
      ),
      findsOneWidget,
    );
  });

  testWidgets('non-checklist template sections do not render rating chips', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InspectionFormScreen())),
    );
    await tester.pump();

    expect(
      find.widgetWithText(ExpansionTile, 'SECTION 1 - MACHINE IDENTIFICATION'),
      findsNothing,
    );
    expect(find.widgetWithText(ActionChip, 'OEM'), findsNothing);
    expect(
      find.widgetWithText(ExpansionTile, 'SECTION 2 - STRUCTURAL INSPECTION'),
      findsOneWidget,
    );
  });

  testWidgets(
    'signoff exposes unique inspector and customer signature targets',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: InspectionFormScreen())),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('SIGNOFF'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('signature_input_area')), findsOneWidget);
      expect(
        find.byKey(const Key('customer_signature_input_area')),
        findsOneWidget,
      );
    },
  );

  testWidgets('long checklist sections expose every item as editable chips', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InspectionFormScreen())),
    );
    await tester.pump();

    final section = UndergroundTemplate.sectionByKey(
      'operator_station_ergonomics',
    );
    final sectionTile = find.widgetWithText(ExpansionTile, section.title);
    await tester.ensureVisible(sectionTile);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(sectionTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    for (final item in section.items) {
      expect(find.widgetWithText(ActionChip, item), findsOneWidget);
    }
    expect(find.textContaining('more'), findsNothing);

    await tester.tap(find.widgetWithText(ActionChip, 'Pedal Placement'));
    await tester.pumpAndSettle();

    expect(find.text('Pedal Placement prompt'), findsOneWidget);
  });

  testWidgets('bulk defaults require explicit confirmation and fill progress', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InspectionFormScreen())),
    );
    await tester.pump();

    final checklistButton = find.byKey(
      const Key('mark_unreviewed_good_button'),
    );
    await tester.ensureVisible(checklistButton);
    await tester.tap(checklistButton);
    await tester.pumpAndSettle();
    expect(find.text('Mark unreviewed items Good?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_mark_unreviewed_good')));
    await tester.pumpAndSettle();

    final checklistTotal = UndergroundTemplate.conditionChecklistSections.fold(
      0,
      (total, section) => total + section.items.length,
    );
    expect(
      find.text('Checklist $checklistTotal / $checklistTotal'),
      findsOneWidget,
    );

    final narrativeButton = find.byKey(
      const Key('mark_unrecorded_narrative_na_button'),
    );
    await tester.tap(narrativeButton);
    await tester.pumpAndSettle();
    expect(find.text('Mark unrecorded narrative fields N/A?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('confirm_mark_unrecorded_narrative_na')),
    );
    await tester.pumpAndSettle();

    final narrativeTotal = UndergroundTemplate.narrativeSections.fold(
      0,
      (total, section) => total + section.items.length,
    );
    expect(
      find.text('Narrative $narrativeTotal / $narrativeTotal'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved checklist rating is visible on the item chip', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final record = buildInspection(
      id: 'visible-rating-record',
      documentNumber: '20260420-7002',
      status: InspectionStatus.inProgress,
    );
    fillRequiredResponses(record);
    const sectionKey = 'structural_inspection';
    final itemKey = InspectionValidator.templateItemKey(
      sectionKey,
      'Main Frame',
    );
    record.responseByKey(sectionKey, itemKey)
      ?..value = 'Poor'
      ..conditionRating = ConditionRating.unsatisfactory
      ..isFlagged = true
      ..comment = 'Visible saved rating.';
    final controller = _FakeHydrationController(record);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [workspaceProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(
          home: Scaffold(
            body: InspectionFormScreen(inspectionId: 'visible-rating-record'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sectionTile = find.widgetWithText(
      ExpansionTile,
      'SECTION 2 - STRUCTURAL INSPECTION',
    );
    await tester.ensureVisible(sectionTile);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(sectionTile);
    await tester.pump(const Duration(milliseconds: 300));

    final savedMainFrameChip = find.widgetWithText(ActionChip, 'Main Frame');
    expect(
      find.descendant(of: savedMainFrameChip, matching: find.text('Poor')),
      findsOneWidget,
    );
  });

  testWidgets('edit form hydrates and preserves checklist item ratings', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final record = buildInspection(
      id: 'saved-edit-record',
      documentNumber: '20260420-7001',
      status: InspectionStatus.inProgress,
    );
    fillRequiredResponses(record);
    final section = UndergroundTemplate.sectionByKey(
      'operator_station_ergonomics',
    );
    final itemKey = InspectionValidator.templateItemKey(
      section.key,
      'Pedal Placement',
    );
    final response = record.responseByKey(section.key, itemKey);
    response
      ?..value = 'Fair'
      ..conditionRating = ConditionRating.monitorAtRisk
      ..isFlagged = true
      ..comment = 'Pedal travel is inconsistent.';
    final controller = _FakeHydrationController(record);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [workspaceProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          home: const Scaffold(
            body: InspectionFormScreen(inspectionId: 'saved-edit-record'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sectionTile = find.widgetWithText(ExpansionTile, section.title);
    await tester.ensureVisible(sectionTile);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(sectionTile);
    await tester.pumpAndSettle();

    final pedalChip = find.widgetWithText(ActionChip, 'Pedal Placement');
    expect(
      find.descendant(of: pedalChip, matching: find.text('Fair')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Generate PDF'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Generate PDF'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.savedDraft?.itemRatings[itemKey], 'Fair');
    expect(
      controller.savedDraft?.itemComments[itemKey],
      'Pedal travel is inconsistent.',
    );
  });
}

Finder _editableTextWithValue(String value) {
  return find.byWidgetPredicate(
    (widget) => widget is EditableText && widget.controller.text == value,
    description: 'EditableText with value "$value"',
  );
}

class _FakeHydrationController extends AppWorkspaceController {
  _FakeHydrationController(this.record)
    : super(autoLoad: false, seedInspections: const <InspectionSummary>[]);

  final InspectionRecord record;
  InspectionFormDraft? savedDraft;

  @override
  Future<InspectionRecord?> inspectionRecordById(String id) async {
    return id == record.id ? record : null;
  }

  @override
  Future<InspectionSummary> saveFormDraft(
    InspectionFormDraft draft, {
    bool complete = false,
  }) async {
    savedDraft = draft;
    return InspectionSummary(
      id: record.id,
      documentNumber: record.documentNumber,
      customer: draft.customer,
      workOrderNumber: record.workOrderNumber,
      customerReference: record.customerReference,
      assetName: draft.serialNumber,
      siteLocation: draft.mineSite,
      technicianName: draft.inspector,
      servicingShop: record.servicingShop,
      inspectionDateTime: record.inspectionDateTime,
      createdAt: record.createdAt,
      status: record.status,
      sections: const <InspectionSectionView>[],
      actionItems: const <InspectionActionItemView>[],
      photos: const <InspectionPhotoView>[],
      flaggedCount: 0,
      atRiskCount: 0,
      unsatisfactoryCount: 0,
      criticalCount: 0,
      photoCount: 0,
      lastUpdatedAt: record.updatedAt,
    );
  }

  @override
  Future<File> generatePdfForInspection(String inspectionId) async {
    return File('/tmp/fake-underground-report.pdf');
  }
}
