#!/usr/bin/env bash
set -euo pipefail

TEST_UID="${1:?missing SYNC_TEST_UID}"
EMULATOR_HOST="${2:-10.0.2.2}"

dump_device_diagnostics() {
  echo "=== adb devices -l ==="
  adb devices -l || true
  echo "=== emulator boot properties ==="
  adb shell getprop sys.boot_completed 2>/dev/null || true
  adb shell getprop init.svc.bootanim 2>/dev/null || true
  adb shell getprop dev.bootcomplete 2>/dev/null || true
  echo "=== package manager check ==="
  adb shell pm path android 2>&1 || true
  echo "=== recent Android logcat ==="
  adb logcat -d -t 300 -v threadtime 2>&1 || true
}

echo "Waiting for device..."
if ! timeout 120s adb wait-for-device; then
  echo "ERROR: adb device did not become available within 120 seconds"
  dump_device_diagnostics
  exit 1
fi

echo "Waiting for boot_completed..."
BOOT_OK=false
for i in $(seq 1 90); do
  boot="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  if [ "$boot" = "1" ]; then
    echo BOOT_OK
    BOOT_OK=true
    break
  fi
  sleep 2
done
if [ "$BOOT_OK" != true ]; then
  echo "ERROR: Android boot did not complete within 180 seconds"
  dump_device_diagnostics
  exit 1
fi

echo "Waiting for package manager..."
PM_OK=false
for i in $(seq 1 60); do
  if adb shell pm path android >/dev/null 2>&1; then
    echo PM_OK
    PM_OK=true
    break
  fi
  sleep 2
done
if [ "$PM_OK" != true ]; then
  echo "ERROR: Android package manager was not ready within 120 seconds"
  dump_device_diagnostics
  exit 1
fi

adb reverse tcp:9099 tcp:9099
adb reverse tcp:8080 tcp:8080

adb shell settings put global window_animation_scale 0 || true
adb shell settings put global transition_animation_scale 0 || true
adb shell settings put global animator_duration_scale 0 || true
sleep 5

unset CI || true
DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
echo "DEVICE_ID=${DEVICE_ID}"
if [ -z "${DEVICE_ID}" ]; then
  echo "ERROR: no Android device is in the 'device' state"
  dump_device_diagnostics
  exit 1
fi

for attempt in 1 2; do
  echo "=== test attempt ${attempt} ==="
  adb uninstall com.alborai.water_tank_app || true
  sleep 3
  TEST_LOG="integration-test-attempt-${attempt}.log"
  set +e
  timeout 15m flutter test integration_test/sync_service_test.dart \
    -d "${DEVICE_ID}" \
    --reporter expanded \
    --verbose \
    --dart-define="SYNC_TEST_UID=${TEST_UID}" \
    --dart-define="FIREBASE_EMULATOR_HOST=${EMULATOR_HOST}" 2>&1 | tee "${TEST_LOG}"
  TEST_STATUS=${PIPESTATUS[0]}
  set -e

  if [ "${TEST_STATUS}" -eq 0 ]; then
    echo TESTS_PASSED
    exit 0
  fi

  LOGCAT_FILE="android-logcat-attempt-${attempt}.log"
  adb logcat -d -v threadtime > "${LOGCAT_FILE}" || true
  echo "Flutter test exit code: ${TEST_STATUS}"
  echo "=== Recent Flutter test output ==="
  tail -n 120 "${TEST_LOG}" || true
  echo "=== Android errors from logcat ==="
  grep -iE "FATAL EXCEPTION|AndroidRuntime|flutter.*(error|exception)|Firebase.*(error|exception)" "${LOGCAT_FILE}" | tail -n 100 || true
  echo "Attempt ${attempt} failed — recovering..."
  adb wait-for-device
  sleep 10
done

echo TESTS_FAILED_AFTER_RETRIES
exit 1
