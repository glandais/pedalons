# Sourced by e2e.sh and tool/patrol_mcp.sh: where the e2e stack answers and which device runs
# the tests. Sets E2E_API_URL, E2E_MAILPIT_URL, E2E_ADMIN_EMAIL, E2E_PLATFORM, E2E_DEVICE and
# E2E_DART_DEFINES, and defines e2e_prepare_device.
#
# Ports come from the committed ../.env.e2e, written down once for the web and the mobile suites.
# E2E_PLATFORM picks the platform, `ios` by default:
# - ios: the simulator named by PATROL_DEVICE (a UDID), or else the one called
#   "iPhone 17 Pro Max". Never `booted`: that hits whichever simulator happens to be up.
# - android: the device whose adb serial is PATROL_DEVICE, or else `emulator-5554`. Nothing on
#   this path touches a simulator, so it runs beside an iOS suite on the same stack.

_e2e_mobile_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_e2e_env_value() { grep -E "^$1=" "$_e2e_mobile_dir/../.env.e2e" | cut -d= -f2-; }

# Sourced from zsh, BASH_SOURCE is empty and ../.env.e2e is looked up in the wrong place: every
# port comes back empty and the app crashes at launch on « Invalid port ». Refuse that.
if [[ -z "$(_e2e_env_value HTTP_PORT 2>/dev/null)" ]]; then
  echo "e2e: no HTTP_PORT read from $_e2e_mobile_dir/../.env.e2e — source this file from bash" >&2
  return 1 2>/dev/null || exit 1
fi
E2E_API_URL="http://localhost:$(_e2e_env_value HTTP_PORT)"
E2E_MAILPIT_URL="http://localhost:$(_e2e_env_value E2E_MAILPIT_PORT)"
E2E_ADMIN_EMAIL="$(_e2e_env_value PEDALONS_BOOTSTRAP_ADMIN_EMAIL)"
E2E_DART_DEFINES="--dart-define=API_BASE_URL=$E2E_API_URL --dart-define=E2E_MAILPIT_URL=$E2E_MAILPIT_URL --dart-define=E2E_ADMIN_EMAIL=$E2E_ADMIN_EMAIL"

E2E_PLATFORM="${E2E_PLATFORM:-ios}"
E2E_DEVICE="${PATROL_DEVICE:-}"
# Android Studio's default SDK location: ~/Library/Android/sdk on macOS, ~/Android/Sdk on Linux.
if [[ "$(uname)" == Darwin ]]; then
  _e2e_android_sdk="$HOME/Library/Android/sdk"
else
  _e2e_android_sdk="$HOME/Android/Sdk"
fi
_e2e_adb="${ANDROID_HOME:-$_e2e_android_sdk}/platform-tools/adb"

if [[ "$E2E_PLATFORM" == android ]]; then
  E2E_DEVICE="${E2E_DEVICE:-emulator-5554}"
elif [[ "$E2E_PLATFORM" != ios ]]; then
  echo "e2e: E2E_PLATFORM is \"$E2E_PLATFORM\" — ios or android" >&2
  return 1
elif [[ -z "$E2E_DEVICE" ]]; then
  E2E_DEVICE=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = [d for runtime in json.load(sys.stdin)["devices"].values() for d in runtime]
print(next((d["udid"] for d in devices if d["name"] == "iPhone 17 Pro Max"), ""))')
fi
if [[ -z "$E2E_DEVICE" ]]; then
  echo "e2e: no \"iPhone 17 Pro Max\" simulator — set PATROL_DEVICE to a simulator UDID" >&2
  return 1
fi

# Waits for the device to be fully booted — a test launched mid-boot fails. On Android the app
# keeps its `localhost` API (E2eConfig refuses anything else): `adb reverse` forwards the stack's
# ports from the emulator to this machine.
e2e_prepare_device() {
  if [[ "$E2E_PLATFORM" == ios ]]; then
    xcrun simctl bootstatus "$E2E_DEVICE" -b >/dev/null
    return
  fi
  if ! "$_e2e_adb" devices | grep -q "^$E2E_DEVICE[[:space:]]"; then
    echo "e2e: no Android device $E2E_DEVICE — start the emulator, or set PATROL_DEVICE to its serial" >&2
    return 1
  fi
  "$_e2e_adb" -s "$E2E_DEVICE" wait-for-device
  until [[ "$("$_e2e_adb" -s "$E2E_DEVICE" shell getprop sys.boot_completed | tr -d '\r')" == 1 ]]; do
    sleep 2
  done
  local url port
  for url in "$E2E_API_URL" "$E2E_MAILPIT_URL"; do
    port="${url##*:}"
    "$_e2e_adb" -s "$E2E_DEVICE" reverse "tcp:$port" "tcp:$port" >/dev/null
  done
}

export PATH="$PATH:$HOME/.pub-cache/bin"
