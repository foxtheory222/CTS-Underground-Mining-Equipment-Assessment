# Underground Mining Assessment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the branded seed into a standalone local-only CTS Underground Mining Equipment Assessment Android tablet app.

**Architecture:** Keep the existing offline Flutter, SQLite, local file storage, PDF, ZIP export/import, Riverpod, and go_router foundation. Add a mining template catalog and adapt constants, models, validation, UI labels, docs, tests, and assets around that catalog.

**Tech Stack:** Flutter stable 3.41.7, Dart 3.11.5, Android SDK 36, Riverpod, go_router, sqflite, pdf, archive, share_plus, image/image_picker, signature.

---

### Task 1: Template Catalog And Constants

**Files:**
- Create: `lib/core/underground_template.dart`
- Modify: `lib/core/constants.dart`
- Test: `test/unit/underground_template_test.dart`

- [ ] **Step 1: Write failing template completeness tests**

```dart
test('underground template exposes the required identity and sections', () {
  expect(UndergroundTemplate.key, 'underground_mining_rebuild_life_extension');
  expect(UndergroundTemplate.version, '1.0.0');
  expect(UndergroundTemplate.sections.map((s) => s.title), containsAll(<String>[
    'SECTION 1 - MACHINE IDENTIFICATION',
    'SECTION 2 - STRUCTURAL INSPECTION',
    'SECTION 5 - HYDRAULIC SYSTEM ASSESSMENT',
    'SECTION 9B - MACHINE SPECIFIC SYSTEMS',
    'SECTION 14 - PHOTOGRAPHIC EVIDENCE',
  ]));
  expect(UndergroundTemplate.sections, hasLength(16));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/underground_template_test.dart`
Expected: FAIL because `underground_template.dart` does not exist.

- [ ] **Step 3: Implement the catalog**

Create immutable catalog classes for sections, items, option groups, manual score fields, machine types, final recommendations, priority options, recommendation groups, cost fields, and file naming helpers. Include every required section and required option from the product prompt.

- [ ] **Step 4: Run template tests to verify green**

Run: `flutter test test/unit/underground_template_test.dart`
Expected: PASS.

### Task 2: Validation And Status Rules

**Files:**
- Modify: `lib/core/validators.dart`
- Modify: `lib/data/models/inspection_models.dart`
- Modify: `test/support/persistence_test_helpers.dart`
- Test: `test/unit/inspection_validator_test.dart`
- Test: `test/unit/spec_service_test.dart`

- [ ] **Step 1: Write failing validation tests**

Add tests that assert Fair requires a comment, Not Inspected requires a comment, Poor requires comment/photo/action item, Critical requires comment/photo/action item/acknowledgement, completion requires final recommendation and inspector signature, and editing an emailed report clears emailed/generated state.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/unit/inspection_validator_test.dart test/unit/spec_service_test.dart`
Expected: FAIL on missing mining-specific validation fields/rules.

- [ ] **Step 3: Implement validation**

Extend inspection payload metadata for template key/version, machine header fields, manual scores, final recommendation, imported original document number, restored export path, and generated PDF invalidation. Apply the global rating and status-transition rules without adding cloud or account behavior.

- [ ] **Step 4: Run targeted tests to verify green**

Run: `flutter test test/unit/inspection_validator_test.dart test/unit/spec_service_test.dart`
Expected: PASS.

### Task 3: UI And Branding

**Files:**
- Modify: `assets/logo/cts_logo.png`
- Modify: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- Modify: `lib/features/inspection_form/inspection_form_screen.dart`
- Modify: `lib/features/dashboard/dashboard_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/widgets/app_shell.dart`
- Test: `test/widget_test.dart`
- Test: `test/widget/tablet_harness_test.dart`

- [ ] **Step 1: Write failing widget tests**

Assert the dashboard, editor, settings/about, and navigation surfaces show the underground report title, machine health score controls, mining section labels, machine type options, purpose options, final recommendation options, and template version.

- [ ] **Step 2: Run widget tests to verify failure**

Run: `flutter test test/widget_test.dart test/widget/tablet_harness_test.dart`
Expected: FAIL where seed-era form labels are still present or required mining controls are missing.

- [ ] **Step 3: Implement UI and icon assets**

Replace seed-facing labels, rebuild the form around the mining template catalog, preserve landscape tablet density, show wide-layout navigation and validation summary, and generate CTS launcher icons from the supplied brand mark.

- [ ] **Step 4: Run widget tests to verify green**

Run: `flutter test test/widget_test.dart test/widget/tablet_harness_test.dart`
Expected: PASS.

### Task 4: PDF, Export/Import, And Docs

**Files:**
- Modify: `lib/services/pdf_service.dart`
- Modify: `lib/services/backup_service.dart`
- Modify: `lib/services/email_service.dart`
- Modify: `docs/PRODUCT_SPEC.md`
- Modify: `docs/UI_SPEC.md`
- Modify: `docs/DATA_MODEL.md`
- Modify: `docs/TEST_PLAN.md`
- Modify: `docs/RELEASE_CHECKLIST.md`
- Test: `test/unit/pdf_service_test.dart`
- Test: `test/unit/backup_service_test.dart`
- Test: `test/regression/inspection_regression_test.dart`

- [ ] **Step 1: Write failing service tests**

Assert PDF filenames follow `CTS_UMEA_[Customer]_[MachineOrSerial]_[InspectionDate]_[DocumentNumber].pdf`, export bundles follow `CTS_InspectionBundle_[DocumentNumber]_UMEA.zip`, exported JSON includes template metadata, import conflicts assign a new local document number while preserving the original, and PDFs include the CTS report title, USD cost forecast, health score/status, final recommendation, and signature blocks.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/unit/pdf_service_test.dart test/unit/backup_service_test.dart test/regression/inspection_regression_test.dart`
Expected: FAIL where seed filenames/report text/metadata remain.

- [ ] **Step 3: Implement services and documentation**

Update deterministic PDF generation, share/email subject, archive names, import metadata, and docs to match the underground mining V1 requirements and local-only constraints.

- [ ] **Step 4: Run targeted tests to verify green**

Run: `flutter test test/unit/pdf_service_test.dart test/unit/backup_service_test.dart test/regression/inspection_regression_test.dart`
Expected: PASS.

### Task 5: Full Verification And Publishing

**Files:**
- Modify: no production files unless verification exposes bugs.

- [ ] **Step 1: Run full automated verification**

Run:
```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter test integration_test/app_flow_test.dart
flutter build apk --release
```

- [ ] **Step 2: Matrix test on Android**

Use a connected Android tablet/emulator in landscape. Exercise dashboard search/filter, new inspection, all purpose options, all machine type options, all health score fields, rating options, Critical acknowledgement, signatures, PDF generation, share/email handoff, export/import, duplicate, settings/about, and offline behavior.

- [ ] **Step 3: Commit, push, and open PR**

Commit the feature branch, push `feature/local-v1-underground-mining-assessment`, and open a draft PR to `main` with the test matrix and known release-polish items.
