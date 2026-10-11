#!/usr/bin/env bash
set -euo pipefail

TEST_UID="${1:?missing SYNC_TEST_UID}"
EMULATOR_HOST="${2:-10.0.2.2}"

echo "Waiting for device..."
adb wait-for-device

echo "Waiting for boot_completed..."
for i in $(seq 1 90); do
  boot="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  if [ "$boot" = "1" ]; then
    echo BOOT_OK
    break
  fi
  sleep 2
done

echo "Waiting for package manager..."
for i in $(seq 1 60); do
  if adb shell pm path android >/dev/null 2>&1; then
    echo PM_OK
    break
  fi
  sleep 2
done

adb reverse tcp:9099 tcp:9099
adb reverse tcp:8080 tcp:8080

adb shell settings put global window_animation_scale 0 || true
adb shell settings put global transition_animation_scale 0 || true
adb shell settings put global animator_duration_scale 0 || true
sleep 5

unset CI || true
DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
echo "DEVICE_ID=${DEVICE_ID}"
test -n "${DEVICE_ID}"

for attempt in 1 2; do
  echo "=== test attempt ${attempt} ==="
  adb uninstall com.alborai.water_tank_app || true
  sleep 3
  if timeout 15m flutter test integration_test/sync_service_test.dart \
    -d "${DEVICE_ID}" \
    --dart-define="SYNC_TEST_UID=${TEST_UID}" \
    --dart-define="FIREBASE_EMULATOR_HOST=${EMULATOR_HOST}"; then
    echo TESTS_PASSED
    exit 0
  fi
  echo "Attempt ${attempt} failed — recovering..."
  adb wait-for-device
  sleep 10
done

echo TESTS_FAILED_AFTER_RETRIES
exit 1
