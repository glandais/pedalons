#!/usr/bin/env bash
#
# Raw App Store captures: every screen of screenshots/plan.json, in every locale,
# on the iPhone and the iPad, with no tap — each capture is one launch of the
# app built in screenshot mode (lib/screenshots/screenshot_mode.dart), which
# signs the locale's demo account in and opens the screen by its path.
#
#   ./screenshots/capture.sh                   # both devices, every locale
#   ./screenshots/capture.sh --iphone fr-FR    # one device, one locale
#   ./screenshots/capture.sh --no-build        # reuse the last build
#
# Output: screenshots/flat/<device>/<locale>/<id>.png (not versioned).
#
# One simulator at a time: any other booted simulator is shut down first, the
# iPad is shut down on the way out, and the iPhone is booted again if it was up
# when the script started.
#
# Needs screenshots/accounts.local.json (git-ignored), one demo account per
# locale on staging — see screenshots/README.md.

set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE_ID="fr.pedalons.mobile"
API_BASE_URL="${PEDALONS_SCREENSHOT_API:-https://staging.pedalons.fr}"
IPHONE_NAME="iPhone 17 Pro Max"
IPAD_NAME="iPad Pro 13-inch (M4)"
APP="build/ios/iphonesimulator/Runner.app"
PLAN="screenshots/plan.json"
ACCOUNTS="screenshots/accounts.local.json"
OUT="screenshots/flat"
# A screen is taken once two captures this far apart are identical, or after
# SETTLE_MAX seconds whatever the screen does (a map may never be still).
SETTLE_STEP=2
SETTLE_MAX=60
READY_MIN_BYTES=200000

# ------------------------------------------------------------------ arguments

devices=()
locales=()
build=1
for arg in "$@"; do
  case "$arg" in
    --iphone) devices+=(iphone) ;;
    --ipad) devices+=(ipad) ;;
    --no-build) build=0 ;;
    -*) echo "✖ unknown option: $arg" >&2; exit 2 ;;
    *) locales+=("$arg") ;;
  esac
done
[ "${#devices[@]}" -gt 0 ] || devices=(iphone ipad)
if [ "${#locales[@]}" -eq 0 ]; then
  while IFS= read -r l; do locales+=("$l"); done < <(
    python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["locales"]))' "$PLAN"
  )
fi
[ -f "$ACCOUNTS" ] || { echo "✖ $ACCOUNTS is missing — see screenshots/README.md" >&2; exit 1; }

udid_named() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
for devices in json.load(sys.stdin)["devices"].values():
    for d in devices:
        if d["name"] == sys.argv[1]:
            print(d["udid"]); sys.exit(0)
sys.exit(1)' "$1" || { echo "✖ no available simulator named « $1 »" >&2; exit 1; }
}
# Only the devices asked for: a machine without an iPad simulator can still take the iPhone set.
IPHONE_UDID=$(udid_named "$IPHONE_NAME")
IPAD_UDID=""
[[ " ${devices[*]} " == *" ipad "* ]] && IPAD_UDID=$(udid_named "$IPAD_NAME")

# ------------------------------------------------------------------ simulators

IPHONE_WAS_BOOTED=0
xcrun simctl list devices booted | grep -q "$IPHONE_UDID" && IPHONE_WAS_BOOTED=1
CURRENT=""

# What the screenshot mode reads at launch (lib/screenshots/screenshot_mode.dart):
# Documents/screenshot.json in the app's container, removed on the way out.
launch_file() {
  echo "$(xcrun simctl get_app_container "$CURRENT" "$BUNDLE_ID" data)/Documents/screenshot.json"
}
write_launch() {
  local file
  file=$(launch_file)
  mkdir -p "$(dirname "$file")"
  python3 -c 'import json,sys; json.dump({k: v for k, v in zip(("screen", "email", "password", "push"), sys.argv[1:5]) if v}, open(sys.argv[5], "w"))' \
    "$1" "$2" "$3" "$4" "$file"
}
clear_launch() {
  rm -f "$(launch_file 2>/dev/null)" 2>/dev/null || true
}

restore() {
  if [ -n "$CURRENT" ]; then
    clear_launch
    xcrun simctl status_bar "$CURRENT" clear >/dev/null 2>&1 || true
    xcrun simctl terminate "$CURRENT" "$BUNDLE_ID" >/dev/null 2>&1 || true
    if [ -n "$IPAD_UDID" ] && [ "$CURRENT" = "$IPAD_UDID" ]; then
      echo "▸ shutting the iPad down"
      xcrun simctl shutdown "$CURRENT" >/dev/null 2>&1 || true
    fi
  fi
  if [ "$IPHONE_WAS_BOOTED" = 1 ] && [ "$CURRENT" != "$IPHONE_UDID" ]; then
    echo "▸ booting $IPHONE_NAME again, it was up before the capture"
    xcrun simctl boot "$IPHONE_UDID" >/dev/null 2>&1 || true
  fi
}
trap restore EXIT

use_simulator() {
  local target="$1" udid
  for udid in $(xcrun simctl list devices booted -j | python3 -c '
import json, sys
for devices in json.load(sys.stdin)["devices"].values():
    for d in devices: print(d["udid"])'); do
    if [ "$udid" != "$target" ]; then
      echo "▸ shutting $udid down (one simulator at a time)"
      xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    fi
  done
  CURRENT="$target"
  xcrun simctl bootstatus "$target" -b >/dev/null
  xcrun simctl ui "$target" appearance light
}

# The system language drives the status bar and the app's locale (the demo
# accounts have no language of their own, so the app follows the device). The
# app is reinstalled on every switch: EasyLocalization remembers the last
# locale, and would keep the previous one over the device's.
prepare_locale() {
  local locale="$1"
  xcrun simctl uninstall "$CURRENT" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$CURRENT" "$APP"
  xcrun simctl spawn "$CURRENT" defaults write -g AppleLanguages -array "${locale%%-*}" >/dev/null
  xcrun simctl spawn "$CURRENT" defaults write -g AppleLocale -string "${locale/-/_}" >/dev/null
  xcrun simctl spawn "$CURRENT" launchctl stop com.apple.SpringBoard >/dev/null 2>&1 || true
  sleep 6
  xcrun simctl status_bar "$CURRENT" override --time "9:41" \
    --batteryLevel 100 --batteryState discharging \
    --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3
}

# Waits $2 seconds (default 4), then until the screen stops changing, and keeps
# that frame as $1.
settle_and_capture() {
  local target="$1" min_wait="${2:-4}" tmp prev="" cur waited=0
  tmp=$(mktemp -d)
  sleep "$min_wait"
  while :; do
    xcrun simctl io "$CURRENT" screenshot --type=png "$tmp/frame.png" >/dev/null 2>&1
    cur=$(md5 -q "$tmp/frame.png")
    # A still frame under READY_MIN_BYTES is the splash screen or a loading
    # skeleton (110-150 KB; the lightest real screen weighs twice that): a cold
    # launch after a reinstall can outlast the screen's wait.
    if [ "$cur" = "$prev" ] && [ "$(stat -f%z "$tmp/frame.png")" -ge "$READY_MIN_BYTES" ]; then break; fi
    [ "$waited" -ge "$SETTLE_MAX" ] && { echo "  (not settled after ${SETTLE_MAX}s — still moving, or still loading — keeping the last frame)"; break; }
    prev="$cur"
    sleep "$SETTLE_STEP"
    waited=$((waited + SETTLE_STEP))
  done
  mv "$tmp/frame.png" "$target"
  rm -rf "$tmp"
}

# ------------------------------------------------------------------ build

if [ "$build" = 1 ]; then
  echo "▸ building the screenshot app against $API_BASE_URL"
  flutter build ios --simulator --debug \
    --dart-define=SCREENSHOTS=true \
    --dart-define=API_BASE_URL="$API_BASE_URL"
fi
[ -d "$APP" ] || { echo "✖ $APP not found — run without --no-build" >&2; exit 1; }

# ------------------------------------------------------------------ capture

for device in "${devices[@]}"; do
  case "$device" in
    iphone) use_simulator "$IPHONE_UDID" ;;
    ipad) use_simulator "$IPAD_UDID" ;;
  esac
  for locale in "${locales[@]}"; do
    prepare_locale "$locale"
    mkdir -p "$OUT/$device/$locale"
    email=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]]["email"])' "$ACCOUNTS" "$locale")
    password=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]]["password"])' "$ACCOUNTS" "$locale")
    # A warm-up launch, not captured: the first launch after a reinstall signs
    # in and starts with empty tile and font caches, and on a simulator just
    # booted it can sit on a blank map long enough to pass for a settled screen.
    echo "▸ $device $locale warm-up"
    write_launch "/" "$email" "$password" ""
    xcrun simctl launch "$CURRENT" "$BUNDLE_ID" >/dev/null
    sleep 30
    while IFS=$'\t' read -r id path wait push; do
      echo "▸ $device $locale $id  ($path)"
      xcrun simctl terminate "$CURRENT" "$BUNDLE_ID" >/dev/null 2>&1 || true
      write_launch "$path" "$email" "$password" "$push"
      xcrun simctl launch "$CURRENT" "$BUNDLE_ID" >/dev/null
      settle_and_capture "$OUT/$device/$locale/$id.png" "$wait"
    done < <(python3 -c '
import json, sys
plan = json.load(open(sys.argv[1]))
for s in plan["locales"][sys.argv[2]]["screens"]:
    if sys.argv[3] in s.get("devices", ["iphone", "ipad"]):
        print(s["id"] + "\t" + s["path"] + "\t" + str(s.get("wait", 4)) + "\t" + s.get("push", ""))' "$PLAN" "$locale" "$device")
  done
done

echo "✔ raw captures in $OUT/"
