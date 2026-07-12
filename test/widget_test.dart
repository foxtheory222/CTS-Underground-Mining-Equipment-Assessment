import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:cts_underground_mining_assessment/app.dart';
import 'package:cts_underground_mining_assessment/core/underground_template.dart';
import 'package:cts_underground_mining_assessment/core/workspace_controller.dart';
import 'package:cts_underground_mining_assessment/core/workspace_providers.dart';

void main() {
  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        workspaceProvider.overrideWith((ref) => AppWorkspaceController()),
      ],
      child: const CtsUndergroundMiningAssessmentApp(),
    );
  }

  testWidgets('dashboard shell renders the tablet layout', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(
      find.text('CTS Underground Mining Equipment Assessment'),
      findsWidgets,
    );
    expect(find.text('Inspection Suite'), findsOneWidget);
    expect(find.text('Critical Reports'), findsOneWidget);
  });

  testWidgets('navigation rail opens the inspection list', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inspections').last);
    await tester.pumpAndSettle();

    expect(find.text('Inspection Search'), findsOneWidget);
    expect(find.text('Inspection Records'), findsOneWidget);
  });

  testWidgets(
    'new inspection editor exposes mining assessment sections and options',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Inspection').first);
      await tester.pumpAndSettle();

      expect(find.text('SECTION 1 - MACHINE IDENTIFICATION'), findsWidgets);
      expect(
        find.text('SECTION 5 - HYDRAULIC SYSTEM ASSESSMENT'),
        findsWidgets,
      );
      expect(find.text('SECTION 9B - MACHINE SPECIFIC SYSTEMS'), findsWidgets);
      expect(find.text('Machine Health Score'), findsOneWidget);
      expect(find.text('Purpose of Inspection'), findsOneWidget);
      expect(find.text('Rock Scaler'), findsWidgets);
      expect(find.text('Jumbo'), findsWidgets);
      expect(find.text('Utility Vehicle'), findsWidgets);
      expect(find.text('Other'), findsWidgets);
      expect(find.text('Critical / Out of Service'), findsWidgets);
      expect(find.text('Final CTS Recommendation'), findsOneWidget);
      expect(
        find.text('Replacement More Economical Than Rebuild'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'settings about panel shows template and local-only version details',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();

      expect(find.text('About / Version'), findsOneWidget);
      expect(
        find.text('Template version ${UndergroundTemplate.templateVersion}'),
        findsOneWidget,
      );
      expect(find.text(UndergroundTemplate.templateKey), findsOneWidget);
      expect(find.text('Android tablet local-only V1'), findsOneWidget);
      expect(find.text('App version 1.1.0+2'), findsOneWidget);
      expect(find.text('Build profile development'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text('Automatic'), findsOneWidget);
      expect(find.text('Always on'), findsNWidgets(3));
    },
  );

  testWidgets('compact portrait layout uses accessible bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Critical Reports'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(find.text('Adaptive orientation'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('New').last);
    await tester.pumpAndSettle();

    expect(find.text('SECTION 1 - MACHINE IDENTIFICATION'), findsWidgets);
    expect(
      find.byKey(const Key('mark_unreviewed_good_button')),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
