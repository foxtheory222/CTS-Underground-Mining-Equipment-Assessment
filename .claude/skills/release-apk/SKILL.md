---
name: release-apk
description: Drive the CTS release checklist and build the Android APK. Runs the gate, builds debug/release APKs, and confirms local PDF/export flows. Invoke when cutting a build.
disable-model-invocation: true
---

# release-apk

Package a release build of the CTS Underground Mining Equipment Assessment app
by following docs/RELEASE_CHECKLIST.md. This is a device/artifact-producing
action — never skip the gate and never claim success you did not observe.

## Procedure

1. **Read the checklist.** Open docs/RELEASE_CHECKLIST.md and treat every item
   as a required gate, not a hint.

2. **Run the quality gate.** Execute the `flutter-check` steps first:
   `flutter pub get`, `dart format --output=none --set-exit-if-changed .`,
   `flutter analyze`, `flutter test`. Stop and report if any fail — do not build
   on a dirty tree.

3. **Build.**
   - Debug: `flutter build apk --debug`
   - Release: `flutter build apk --release`
   Report the output APK paths under build/app/outputs/.

4. **Confirm Definition of Done items** from AGENTS.md that can be checked
   without a device, and clearly list the ones that require a tablet emulator
   (landscape launch, end-to-end inspection flow, local PDF readable, email
   handoff, export/import round-trip). Do not mark those as done — mark them as
   **manual verification required**.

## Reporting
End with: APK paths, gate results, and an explicit checklist of remaining manual
emulator verifications from the release checklist. Be honest about anything
skipped or unverified.
