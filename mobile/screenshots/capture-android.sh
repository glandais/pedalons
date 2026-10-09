#!/usr/bin/env bash
# Google Play captures — the Android twin of capture.sh, same plan, same demo accounts.
#
#   python3 screenshots/seed.py                     # first, on staging
#   ./screenshots/capture-android.sh                # every locale of plan.json
#   ./screenshots/capture-android.sh fr-FR --no-build
#
# Runs on the `pedalons_e2e` emulator (Pixel 7, 1080 x 2400), never on a phone: an emulator is the
# only target whose app data `run-as` can reach and whose status bar demo mode is predictable. The
# phone set of plan.json is captured (`devices` containing "iphone"), minus the iPad-only screens.
# Raw captures land in screenshots/flat/android/<locale>/; screenshots/koubou/play.yaml turns them
# into 1080 x 1920 cards (Play refuses a side more than twice the other, which 2400 x 1080 is).

set -euo pipefail
cd "$(dirname "$0")/.."

PACKAGE="fr.pedalons.mobile"
ACTIVITY="$PACKAGE/.MainActivity"
AVD="pedalons_e2e"
API_BASE_URL="${PEDALONS_SCREENSHOT_API:-https://staging.pedalons.fr}"
APK="build/app/outputs/flutter-apk/app-debug.apk"
PLAN="screenshots/plan.json"
ACCOUNTS="screenshots/accounts.local.json"
OUT="screenshots/flat/android"
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$SDK/platform-tools/adb"
EMULATOR="$SDK/emulator/emulator"
# A debug build on the emulator holds its splash screen for several seconds at first launch, and a
# still splash looks settled: no screen is taken before this many seconds, whatever the plan says.
MIN_WAIT=10
SETTLE_STEP=2
SETTLE_MAX=40

locales=()
build=1
for arg in "$@"; do
  case "$arg" in
    --no-build) build=0 ;;
    -*) echo "✖ unknown option: $arg" >&2; exit 2 ;;
    *) locales+=("$arg") ;;
  esac
done
if [ "${#locales[@]}" -eq 0 ]; then
  while IFS= read -r l; do locales+=("$l"); done < <(
    python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["locales"]))' "$PLAN"
  )
fi
[ -f "$ACCOUNTS" ] || { echo "✖ $ACCOUNTS is missing — see screenshots/README.md" >&2; exit 1; }

# ------------------------------------------------------------------ emulator

emulator_serial() {
  local s
  for s in $("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}' | grep '^emulator-' || true); do
    [ "$("$ADB" -s "$s" emu avd name 2>/dev/null | head -n1 | tr -d '\r')" = "$AVD" ] && { echo "$s"; return; }
  done
}

STARTED=0
SERIAL=$(emulator_serial)
if [ -z "$SERIAL" ]; then
  echo "▸ starting the $AVD emulator"
  "$EMULATOR" -avd "$AVD" -no-snapshot-save -no-boot-anim >/dev/null 2>&1 &
  STARTED=1
  for _ in $(seq 1 90); do SERIAL=$(emulator_serial); [ -n "$SERIAL" ] && break; sleep 2; done
  [ -n "$SERIAL" ] || { echo "✖ the $AVD emulator did not come up" >&2; exit 1; }
fi
adb() { "$ADB" -s "$SERIAL" "$@"; }
adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do sleep 2; done

demo() { adb shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }

restore() {
  adb shell run-as "$PACKAGE" rm -f app_flutter/screenshot.json >/dev/null 2>&1 || true
  demo exit || true
  if [ "$STARTED" = 1 ]; then
    echo "▸ shutting the emulator down"
    adb emu kill >/dev/null 2>&1 || true
  fi
}
trap restore EXIT

# 9:41, full battery and signal, no notification icons — the same frame as the iOS set. SystemUI
# drops demo mode now and then (and ignores it right after boot): set again before every screen.
adb shell settings put global sysui_demo_allowed 1
status_bar() {
  demo enter
  demo clock -e hhmm 0941
  demo battery -e level 100 -e plugged false
  demo network -e wifi show -e level 4 -e fully true
  demo network -e mobile hide
  demo notifications -e visible false
}

# ------------------------------------------------------------------ build

if [ "$build" = 1 ]; then
  echo "▸ building the screenshot app against $API_BASE_URL"
  flutter build apk --debug \
    --dart-define=SCREENSHOTS=true \
    --dart-define=API_BASE_URL="$API_BASE_URL"
fi
[ -f "$APK" ] || { echo "✖ $APK not found — run without --no-build" >&2; exit 1; }

# What the screenshot mode reads at launch (lib/screenshots/screenshot_mode.dart): screenshot.json
# in getApplicationDocumentsDirectory(), app_flutter/ on Android, written through run-as.
write_launch() {
  python3 -c 'import json,sys; print(json.dumps({k: v for k, v in zip(("screen", "email", "password", "push"), sys.argv[1:5]) if v}))' \
    "$1" "$2" "$3" "$4" |
    adb shell "run-as $PACKAGE sh -c 'mkdir -p app_flutter && cat > app_flutter/screenshot.json'"
}

# The app follows the device language (the demo accounts have none); a per-app locale sets it
# without a reboot. Reinstalled on every switch: EasyLocalization remembers the last locale.
prepare_locale() {
  adb uninstall "$PACKAGE" >/dev/null 2>&1 || true
  adb install -r "$APK" >/dev/null
  adb shell cmd locale set-app-locales "$PACKAGE" --locales "$1"
  adb shell pm grant "$PACKAGE" android.permission.POST_NOTIFICATIONS >/dev/null 2>&1 || true
}

settle_and_capture() {
  local target="$1" min_wait="${2:-4}" tmp prev="" cur waited=0
  tmp=$(mktemp -d)
  sleep "$min_wait"
  while :; do
    adb exec-out screencap -p >"$tmp/frame.png"
    cur=$(md5 -q "$tmp/frame.png")
    [ "$cur" = "$prev" ] && break
    [ "$waited" -ge "$SETTLE_MAX" ] && { echo "  (still moving after ${SETTLE_MAX}s, keeping the last frame)"; break; }
    prev="$cur"
    sleep "$SETTLE_STEP"
    waited=$((waited + SETTLE_STEP))
  done
  mv "$tmp/frame.png" "$target"
  rm -rf "$tmp"
}

# ------------------------------------------------------------------ capture

for locale in "${locales[@]}"; do
  prepare_locale "$locale"
  mkdir -p "$OUT/$locale"
  email=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]]["email"])' "$ACCOUNTS" "$locale")
  password=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]]["password"])' "$ACCOUNTS" "$locale")
  # The plan comes in on fd 3: `adb shell` reads stdin, and would swallow the rest of it.
  while IFS=$'\t' read -r -u 3 id path wait push; do
    echo "▸ android $locale $id  ($path)"
    adb shell am force-stop "$PACKAGE"
    write_launch "$path" "$email" "$password" "$push"
    adb shell am start -n "$ACTIVITY" >/dev/null
    status_bar
    settle_and_capture "$OUT/$locale/$id.png" "$(( wait > MIN_WAIT ? wait : MIN_WAIT ))"
  done 3< <(python3 -c '
import json, sys
plan = json.load(open(sys.argv[1]))
for s in plan["locales"][sys.argv[2]]["screens"]:
    if "iphone" in s.get("devices", ["iphone", "ipad"]):
        print(s["id"] + "\t" + s["path"] + "\t" + str(s.get("wait", 4)) + "\t" + s.get("push", ""))' "$PLAN" "$locale")
done

echo "✔ raw captures in $OUT/"
