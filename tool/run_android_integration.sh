#!/usr/bin/env bash
set -euo pipefail

target="${1:?usage: run_android_integration.sh <integration-test-target>}"
driver="${2:-test_driver/integration_test.dart}"
log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

run_drive() {
  flutter drive \
    --no-dds \
    --no-pub \
    --dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false \
    --driver="$driver" \
    --target="$target" \
    -d emulator-5554
}

if run_drive 2>&1 | tee "$log_file"; then
  exit 0
fi

# A disposed VM-service connection without a Flutter test failure is another
# form of the same transient emulator/ADB disconnect. Never retry an actual
# assertion or framework failure; those must fail the job immediately.
if grep -Eq 'Some tests failed|Test failed|TestFailure|EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK' "$log_file"; then
  exit 1
fi

if ! grep -Eq 'adb: device offline|device offline|device not found|Service connection disposed' "$log_file"; then
  exit 1
fi

echo "Transient Android emulator disconnect detected; restarting ADB and retrying once."
adb kill-server || true
adb start-server
adb reconnect offline || true

device_ready=""
for _ in $(seq 1 120); do
  if [[ "$(adb -s emulator-5554 get-state 2>/dev/null || true)" == "device" ]]; then
    device_ready="1"
    break
  fi
  sleep 1
done

if [[ "$device_ready" != "1" ]]; then
  echo "Android emulator did not reconnect within the bounded retry window." >&2
  exit 1
fi

boot_completed=""
for _ in $(seq 1 60); do
  boot_completed="$(adb -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
  if [[ "$boot_completed" == "1" ]]; then
    break
  fi
  sleep 2
done

if [[ "$boot_completed" != "1" ]]; then
  echo "Android emulator did not recover within the bounded retry window." >&2
  exit 1
fi

run_drive
