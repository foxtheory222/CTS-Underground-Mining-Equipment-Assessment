---
name: flutter-check
description: Run the full CTS pre-review loop — pub get, format check, analyze, and tests — mirroring the Definition of Done. Invoke before committing or opening a review.
disable-model-invocation: true
---

# flutter-check

Run the CTS test loop from AGENTS.md end to end and report a clean/dirty
verdict. Run each step from the repository root and stop reporting individual
steps only after all have run — collect every failure, don't bail on the first.

## Steps
Run these in order:

1. `flutter pub get`
2. `dart format --output=none --set-exit-if-changed .`
   - If this fails, the tree is unformatted. Run `dart format .` to fix, then
     note which files changed.
3. `flutter analyze`
   - Must report **no issues**. Surface every error and warning.
4. `flutter test`
   - Run the full unit + widget + regression suite.
5. If the caller asked for coverage, also run `flutter test --coverage`.

## Reporting
Print a summary table: step, pass/fail, and the key output on failure. End with
an overall verdict:
- **READY** — all steps clean.
- **NOT READY** — list exactly what must be fixed.

Do not attempt to fix analyzer or test failures unless the user asks; this
skill's job is to run the gate and report.

## Notes
- The integration test (`flutter test integration_test/app_flow_test.dart`)
  needs a connected Android tablet emulator and is intentionally **not** part of
  this skill — call it out in the summary as a manual pre-release step.
