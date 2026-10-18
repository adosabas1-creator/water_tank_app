#!/usr/bin/env bash
set -euo pipefail

TEST_UID="${1:?missing SYNC_TEST_UID}"
EMULATOR_HOST="${2:-10.0.2.2}"

echo "Waiting for device..."
adb wait-for-device

echo "Waiting for boot_completed (maximum 180 seconds)..."
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
  echo "ERROR: Android did not report sys.boot_completed=1 within 180 seconds."
  adb devices -l || true
  adb shell getprop sys.boot_completed || true
  adb shell getprop init.svc.bootanim || true
  exit 70
fi

echo "Waiting for package manager (maximum 120 seconds)..."
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
  echo "ERROR: Android package manager did not become ready within 120 seconds."
  adb devices -l || true
  adb shell getprop sys.boot_completed || true
  adb shell dumpsys activity 2>&1 | head -n 80 || true
  exit 71
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
test -n "${DEVICE_ID}"

# Keep one diagnostic attempt. The previous retry repeated a 15-minute hang
# without changing the environment or providing new information.
TEST_LOG="integration-test-attempt-1.log"
LOGCAT_FILE="android-logcat-attempt-1.log"
adb logcat -c || true

echo "=== single integration test attempt (12-minute hard limit) ==="
set +e
timeout --signal=INT --kill-after=15s 12m flutter test integration_test/sync_service_test.dart \
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

adb logcat -d -v threadtime > "${LOGCAT_FILE}" || true
echo "Flutter test exit code: ${TEST_STATUS}"
if [ "${TEST_STATUS}" -eq 124 ] || [ "${TEST_STATUS}" -eq 137 ]; then
  echo "DIAGNOSTIC_TIMEOUT: Flutter integration test exceeded the 12-minute limit."
fi
echo "=== Firebase/Flutter native log lines ==="
grep -iE "Firebase|FlutterJNI|flutter.*(error|exception)|MissingPlugin|PlatformException|FATAL EXCEPTION|AndroidRuntime" "${LOGCAT_FILE}" | tail -n 160 || true
echo "=== Final Flutter test output ==="
tail -n 160 "${TEST_LOG}" || true
exit "${TEST_STATUS}"
