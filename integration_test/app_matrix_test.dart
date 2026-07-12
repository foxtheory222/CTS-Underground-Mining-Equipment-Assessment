import 'package:cts_underground_mining_assessment/app.dart';
import 'package:cts_underground_mining_assessment/core/underground_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real app shell matrix exercises settings and all mining form options',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(child: CtsUndergroundMiningAssessmentApp()),
      );
      await tester.pumpAndSettle();

      expect(find.text(UndergroundTemplate.appName), findsWidgets);

      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      for (final key in <String>[
        'settings_lock_landscape',
        'settings_compress_images',
        'settings_save_recent_recipients',
        'settings_branded_theme',
      ]) {
        await _expectByKey(tester, key);
      }
      expect(find.text('About / Version'), findsOneWidget);

      final newInspectionTab = find.byIcon(Icons.note_add_outlined);
      expect(
        newInspectionTab,
        findsOneWidget,
        reason: 'The New Inspection navigation destination must be available.',
      );
      await tester.tap(newInspectionTab);

      final structuralSection = find.text('SECTION 2 - STRUCTURAL INSPECTION');
      await _waitForFinder(tester, structuralSection);
      expect(structuralSection, findsWidgets);

      for (final purpose in UndergroundTemplate.purposeOptions) {
        await _tapByKey(tester, 'purpose_${_keyPart(purpose)}');
      }
      for (final machineType in UndergroundTemplate.machineTypes) {
        await _tapByKey(tester, 'machine_${_keyPart(machineType)}');
      }
      for (final status in UndergroundTemplate.assetStatusOptions) {
        await _tapByKey(tester, 'asset_status_${_keyPart(status)}');
      }
      for (final field in UndergroundTemplate.healthScoreFields) {
        await _dragSliderByKey(tester, 'score_slider_${field.key}');
      }
      for (final rating in UndergroundTemplate.globalRatingOptions) {
        await _tapByKey(tester, 'rating_${_keyPart(rating)}');
      }

      await _tapByKey(tester, 'critical_switch');
      await _tapByKey(tester, 'critical_ack_checkbox');

      for (final recommendation
          in UndergroundTemplate.finalRecommendationOptions) {
        await _tapByKey(tester, 'recommendation_${_keyPart(recommendation)}');
      }
      await _dragByKey(tester, 'signature_input_area', const Offset(120, 40));
      expect(find.text('Captured'), findsOneWidget);

      if (find.text('Review Summary').evaluate().isNotEmpty) {
        expect(find.text('Ready for PDF review'), findsWidgets);
        expect(find.text('Generate PDF'), findsWidgets);
        expect(find.text('Share / Email Handoff'), findsWidgets);
      } else {
        expect(find.text('SIGNOFF'), findsWidgets);
      }
    },
  );
}

Future<void> _waitForFinder(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = tester.binding.clock.fromNowBy(timeout);
  do {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.any(finder)) {
      return;
    }
  } while (tester.binding.clock.now().isBefore(deadline));

  expect(
    finder,
    findsAtLeastNWidgets(1),
    reason: 'Timed out waiting for the inspection form to initialize.',
  );
}

Future<void> _expectByKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  expect(finder, findsOneWidget, reason: 'Missing matrix target: $key');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapByKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  expect(finder, findsOneWidget, reason: 'Missing matrix target: $key');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _dragSliderByKey(WidgetTester tester, String key) async {
  await _dragByKey(tester, key, const Offset(80, 0));
}

Future<void> _dragByKey(WidgetTester tester, String key, Offset offset) async {
  final finder = find.byKey(Key(key));
  expect(finder, findsOneWidget, reason: 'Missing matrix target: $key');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.drag(finder, offset);
  await tester.pumpAndSettle();
}

String _keyPart(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');
