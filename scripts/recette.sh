#!/usr/bin/env bash
# Manual (or agent-driven) recette on the e2e stack: stable accounts, a realistic team, and the
# wiring to test it in desktop Chrome, in Chrome on a real Android phone, and in the app on it.
#
#   scripts/recette.sh up                  start the e2e stack (scripts/e2e.sh up)
#   scripts/recette.sh build [all|frontend|backend]   rebuild images after a code change, then `up`
#   scripts/recette.sh down [--force]      stop the stack (and the tunnel, unless in use)
#   scripts/recette.sh reset               empty the stack (database, files, sessions), then up
#   scripts/recette.sh logs [service…]     the last 200 lines of the stack's logs
#   scripts/recette.sh tunnel [close [--force]]   RECETTE_HOST only: open the tunnel to a stack already
#                                          up; `close` refuses while a connection uses it (shared)
#   scripts/recette.sh seed                accounts + « Équipe Recette » and its content (idempotent)
#   scripts/recette.sh accounts            who to sign in as, with which password
#   scripts/recette.sh dev                 Vite on the working tree, plain http on :5174, API = the stack
#   scripts/recette.sh web-android [--dev] [path]   the app (or `dev`) in Chrome on the phone, CDP :9222
#   scripts/recette.sh look <desktop|iphone|pixel|cdp> <url|path> <shot.png> [options]   screenshot + boxes
#   scripts/recette.sh mobile [--ios] [args…]   flutter run on the Android phone (or the iPhone)
#                                          against the stack — refuses while the store's app is installed
#                                          (RECETTE_REPLACE_APP=1: replace it)
#   scripts/recette.sh relay [start|stop|status]   the stack on the local network for the iPhone (:8191)
#   scripts/recette.sh unplug              remove every adb port forward from the phone
#
# RECETTE_HOST=optiplex runs the stack on that machine instead (the pedalons-e2e-optiplex skill):
# `up` and `build` sync the working tree there, the stack runs and builds there, and an SSH tunnel
# brings its ports to this machine's loopback, same numbers — so seed, browsers and the phone
# (`adb reverse` lands on this loopback) see no difference. The Stadia Maps key goes from the
# local .env through ssh's stdin, never as an argument nor into a file over there. While the tunnel
# is open the host is remembered: later commands (`tunnel close` included) need no RECETTE_HOST.
#
# A fix not built into the images yet: `dev` serves the working tree (Vite, hot reload) against the
# stack's API, and `web-android --dev` / `look … --base dev` aim at it instead of the stack's app.
#
# The phone is the one physical Android device adb sees (emulators excluded), or the serial in
# RECETTE_DEVICE; the iPhone, the one physical iOS device devicectl sees connected, or the UDID in
# RECETTE_IOS_DEVICE. An iPhone has no `adb reverse`: `mobile --ios` relays the stack onto the
# local network (`relay`, port 8191, every interface, until `relay stop`) and points the app at
# this Mac's Bonjour name. Without Rosetta it builds --profile: flutter's iproxy is x86_64. Every account is on the reserved .test domain and every mail ends in mailpit:
# nothing here is a secret. `reset` wipes it all. See frontend/e2e/README.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACCOUNTS_FILE="$ROOT/.e2e/recette.json"
CDP_PORT="${RECETTE_CDP_PORT:-9222}"

env_value() { grep -E "^$1=" "$ROOT/.env.e2e" | cut -d= -f2-; }
HTTP_PORT="$(env_value HTTP_PORT)"
MAILPIT_PORT="$(env_value E2E_MAILPIT_PORT)"
APP_URL="http://localhost:$HTTP_PORT"

if [[ "$(uname)" == Darwin ]]; then
  ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
else
  ADB="${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb"
fi
command -v "$ADB" >/dev/null 2>&1 || ADB=adb

DEV_PORT="${RECETTE_DEV_PORT:-5174}"
LAN_PORT="${RECETTE_LAN_PORT:-8191}"
DEV_URL="http://localhost:$DEV_PORT"

REMOTE_DIR=tribly # relative to the remote home
TUNNEL_SOCKET="$ROOT/.e2e/recette-tunnel.sock"
TUNNEL_HOST_FILE="$ROOT/.e2e/recette-host"
HOST="${RECETTE_HOST:-}"
# No RECETTE_HOST: the host of a tunnel still open, if any.
if [[ -z "$HOST" && -s "$TUNNEL_HOST_FILE" ]]; then
  _open_host="$(cat "$TUNNEL_HOST_FILE")"
  if ssh -S "$TUNNEL_SOCKET" -O check "$_open_host" 2>/dev/null; then
    HOST="$_open_host"
  else
    rm -f "$TUNNEL_HOST_FILE"
  fi
fi

# --- Remote stack (RECETTE_HOST) -----------------------------------------------------------------

# The commit, then the exact working tree (tracked diff + untracked files), onto the remote clone,
# which stays on a detached HEAD. `git clean` without -x keeps its ignored .e2e/ (JWT keys, files).
sync_remote() {
  local sha
  sha="$(git -C "$ROOT" rev-parse HEAD)"
  echo "recette: syncing ${sha:0:12} + working tree to $HOST:~/$REMOTE_DIR"
  git -C "$ROOT" push -q --no-verify --force "$HOST:$REMOTE_DIR" HEAD:refs/heads/e2e
  ssh "$HOST" "cd ~/$REMOTE_DIR && git checkout -q -f --detach $sha && git clean -fdq"
  git -C "$ROOT" diff HEAD --binary | ssh "$HOST" "cd ~/$REMOTE_DIR && git apply --allow-empty"
  (cd "$ROOT" && git ls-files -z --others --exclude-standard | tar --null -T - -cf -) |
    ssh "$HOST" "cd ~/$REMOTE_DIR && tar xf -"
}

# scripts/e2e.sh over there, the Stadia Maps key on stdin (compose needs it for every command but
# build). sdkman for the image builds: a non-interactive ssh session does not read .bashrc.
remote_e2e() {
  local args key
  args="$(printf '%q ' "$@")"
  key="$(grep -m1 '^STADIAMAPS_API_KEY=' "$ROOT/.env" 2>/dev/null | sed -e 's/^STADIAMAPS_API_KEY=//' -e 's/^"//' -e 's/"$//' || true)"
  [[ -n "$key" ]] || echo "recette: no STADIAMAPS_API_KEY in .env — compose will refuse to start" >&2
  printf '%s\n' "$key" | ssh "$HOST" "read -r K; export STADIAMAPS_API_KEY=\"\$K\";
    [ -f ~/.sdkman/bin/sdkman-init.sh ] && . ~/.sdkman/bin/sdkman-init.sh;
    cd ~/$REMOTE_DIR && scripts/e2e.sh $args"
}

tunnel_up() {
  if ssh -S "$TUNNEL_SOCKET" -O check "$HOST" 2>/dev/null; then
    echo "recette: tunnel to $HOST already open — shared with other sessions: don't close it on their behalf"
    return
  fi
  if curl -fs -o /dev/null "$APP_URL/api/config"; then
    echo "recette: something already answers on $APP_URL — the local tribly-e2e stack?" \
      "Stop it (or ask whoever uses it) before tunnelling to $HOST" >&2
    exit 1
  fi
  mkdir -p "$ROOT/.e2e"
  ssh -M -S "$TUNNEL_SOCKET" -f -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
    -L "$HTTP_PORT:localhost:$HTTP_PORT" -L "$MAILPIT_PORT:localhost:$MAILPIT_PORT" "$HOST"
  echo "$HOST" >"$TUNNEL_HOST_FILE"
  echo "recette: tunnel to $HOST open ($HTTP_PORT, $MAILPIT_PORT) — remembered until \`tunnel close\`"
}

# Who is talking through the tunnel right now: established connections to its local ports from
# anything but the tunnel's own ssh (a browser, adb for the phone, a Playwright run, a relay…).
tunnel_users() {
  lsof -nP -iTCP:"$HTTP_PORT" -iTCP:"$MAILPIT_PORT" -sTCP:ESTABLISHED 2>/dev/null |
    awk -v a="127.0.0.1:$HTTP_PORT" -v b="127.0.0.1:$MAILPIT_PORT" \
      'NR > 1 && $1 != "ssh" && ($9 ~ "->" a "$" || $9 ~ "->" b "$") { print $1 "(" $2 ")" }' |
    sort -u | tr '\n' ' '
  # Connections come and go between requests: a phone still forwarded to the stack counts too.
  local serial
  for serial in $("$ADB" devices 2>/dev/null | awk 'NR > 1 && $2 == "device" { print $1 }'); do
    if "$ADB" -s "$serial" reverse --list 2>/dev/null | grep -q "tcp:$HTTP_PORT"; then
      printf 'phone-%s(adb reverse) ' "$serial"
    fi
  done
}

# The tunnel is shared by every session of this machine (one socket in .e2e/): closing it cuts the
# others. Refused while something uses it, unless --force.
tunnel_down() {
  local force="${1:-}" users
  if ! ssh -S "$TUNNEL_SOCKET" -O check "$HOST" 2>/dev/null; then
    rm -f "$TUNNEL_HOST_FILE"
    return 0
  fi
  users="$(tunnel_users)"
  if [[ -n "$users" && "$force" != --force ]]; then
    echo "recette: the tunnel to $HOST is in use (${users% }) — maybe by another session." >&2
    echo "  Left open. Ask before closing it; --force closes it anyway." >&2
    exit 1
  fi
  rm -f "$TUNNEL_HOST_FILE"
  ssh -S "$TUNNEL_SOCKET" -O exit "$HOST" 2>/dev/null && echo "recette: tunnel to $HOST closed" || true
}

stack() {
  local cmd="$1"
  shift
  if [[ -z "$HOST" ]]; then
    case "$cmd" in
      logs) exec "$ROOT/scripts/e2e.sh" compose logs --tail=200 "$@" ;;
      tunnel)
        echo "recette: no tunnel without RECETTE_HOST — the stack is local" >&2
        exit 1
        ;;
      *) exec "$ROOT/scripts/e2e.sh" "$cmd" "$@" ;;
    esac
  fi
  case "$cmd" in
    up)
      sync_remote
      remote_e2e up
      tunnel_up
      ;;
    build)
      sync_remote
      mkdir -p "$ROOT/.e2e"
      echo "recette: building on $HOST (several minutes for the frontend)"
      remote_e2e build "${1:-all}"
      echo "recette: built — scripts/recette.sh up to restart on the new images"
      ;;
    down)
      tunnel_down "${1:-}"
      remote_e2e down
      ;;
    reset)
      remote_e2e reset
      # The local seed.json would describe a database that no longer exists.
      rm -rf "$ROOT/frontend/e2e/.auth"
      tunnel_up
      echo "recette: stack emptied — scripts/recette.sh seed"
      ;;
    logs) remote_e2e compose logs --tail=200 "$@" ;;
    tunnel) if [[ "${1:-}" == close ]]; then tunnel_down "${2:-}"; else tunnel_up; fi ;;
  esac
}

require_stack() {
  if ! curl -fsS -o /dev/null "$APP_URL/api/config"; then
    if [[ -n "$HOST" ]]; then
      echo "recette: nothing answers on $APP_URL — tunnel to $HOST down? scripts/recette.sh up" >&2
    else
      echo "recette: nothing answers on $APP_URL — scripts/recette.sh up" >&2
    fi
    exit 1
  fi
}

# The phone: RECETTE_DEVICE, else the only physical device adb lists.
phone() {
  if [[ -n "${RECETTE_DEVICE:-}" ]]; then
    echo "$RECETTE_DEVICE"
    return
  fi
  local serials
  serials="$("$ADB" devices | awk 'NR > 1 && $2 == "device" && $1 !~ /^emulator-/ { print $1 }')"
  local count
  count="$(printf '%s' "$serials" | grep -c . || true)"
  if [[ "$count" != 1 ]]; then
    echo "recette: $count physical Android device(s) on adb — plug the phone in (USB debugging on)," \
      "or set RECETTE_DEVICE to its serial" >&2
    exit 1
  fi
  echo "$serials"
}

# The phone reaches the stack on its own localhost: same URLs as on this machine, and `localhost`
# is a secure origin to Chrome (service worker, PWA) without any certificate.
reverse_ports() {
  local serial="$1" port
  for port in "$HTTP_PORT" "$MAILPIT_PORT"; do
    "$ADB" -s "$serial" reverse "tcp:$port" "tcp:$port" >/dev/null
  done
}

seed() {
  require_stack
  (cd "$ROOT/frontend" && pnpm exec playwright test -c playwright.recette.config.ts)
  accounts
}

accounts() {
  if [[ ! -f "$ACCOUNTS_FILE" ]]; then
    echo "recette: no $ACCOUNTS_FILE yet — scripts/recette.sh seed" >&2
    exit 1
  fi
  python3 - "$ACCOUNTS_FILE" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
print(f"app      {data['app']}\nmailpit  {data['mailpit']}\néquipe   {data['team']['url']}\n")
for account in data["accounts"].values():
    print(f"{account['role']:<32} {account['email']:<28} {account['password']}")
PY
}

# The working tree, served by Vite against the stack's API: what a fix looks like before any image
# is rebuilt. Plain http (VITE_DEV_HTTP, vite.config.ts): the phone does not trust the mkcert CA,
# and `localhost` is a secure origin anyway. A fixed port, so `web-android --dev` finds it.
dev() {
  require_stack
  cd "$ROOT/frontend"
  echo "recette: Vite on $DEV_URL, API $APP_URL"
  VITE_API_TARGET="$APP_URL" VITE_DEV_HTTP=1 exec pnpm exec vite --port "$DEV_PORT" --strictPort
}

web_android() {
  require_stack
  local serial base="$APP_URL" extra_port=""
  if [[ "${1:-}" == --dev ]]; then
    shift
    base="$DEV_URL"
    extra_port="$DEV_PORT"
    if ! curl -fs -o /dev/null "$DEV_URL/"; then
      echo "recette: nothing answers on $DEV_URL — scripts/recette.sh dev, in another shell" >&2
      exit 1
    fi
  fi
  local path="${1:-/}"
  serial="$(phone)"
  reverse_ports "$serial"
  [[ -z "$extra_port" ]] || "$ADB" -s "$serial" reverse "tcp:$extra_port" "tcp:$extra_port" >/dev/null
  "$ADB" -s "$serial" shell am start -a android.intent.action.VIEW -d "$base$path" \
    com.android.chrome >/dev/null
  # Chrome's DevTools socket exists once Chrome runs.
  "$ADB" -s "$serial" forward "tcp:$CDP_PORT" localabstract:chrome_devtools_remote >/dev/null
  local deadline=$((SECONDS + 20))
  until curl -fsS -o /dev/null "http://localhost:$CDP_PORT/json/version"; do
    if [[ $SECONDS -ge $deadline ]]; then
      echo "recette: Chrome on $serial does not answer on CDP — is USB debugging allowed?" >&2
      exit 1
    fi
    sleep 1
  done
  echo "recette: Chrome on $serial opened $base$path"
  echo "  CDP: http://localhost:$CDP_PORT — scripts/recette.sh look cdp $base$path <shot.png>"
  echo "  The phone's own Chrome profile, all its tabs: find the page by URL, sign out between accounts."
}

# frontend/e2e/recette/look.mjs: a device (or the phone over CDP), a screenshot, element boxes.
# `--base dev` resolves a path against `dev` instead of the stack's app.
look() {
  local base="$APP_URL"
  if [[ "${1:-}" == --base ]]; then
    [[ "${2:-}" == dev ]] && base="$DEV_URL" || base="${2:-}"
    shift 2
  fi
  RECETTE_BASE_URL="$base" RECETTE_CDP_PORT="$CDP_PORT" \
    exec node "$ROOT/frontend/e2e/recette/look.mjs" "$@"
}

APP_ID=fr.pedalons.mobile

# A debug build is not signed like the Play Store's: `flutter run` hits
# INSTALL_FAILED_UPDATE_INCOMPATIBLE and then uninstalls the installed app on its own — the phone
# owner's production session and local data with it. Refuse while an app installed by a store (or
# anything but adb) is there, unless RECETTE_REPLACE_APP=1 or a yes on a terminal.
guard_store_app() {
  local serial="$1" line installer
  line="$("$ADB" -s "$serial" shell pm list packages -i "$APP_ID" | tr -d '\r' | grep -E "^package:$APP_ID[[:space:]]" || true)"
  [[ -n "$line" ]] || return 0
  installer="${line##*installer=}"
  case "$installer" in
    null | com.android.shell | "") return 0 ;; # a build installed over adb: flutter run replaces it
  esac
  echo "recette: $APP_ID on $serial was installed by $installer (the store's app)." >&2
  echo "  A debug build cannot update it: installing would UNINSTALL it, with its session and data." >&2
  confirm_replace
}

# The iPhone: RECETTE_IOS_DEVICE, else the only physical iOS device devicectl sees connected.
iphone() {
  if [[ -n "${RECETTE_IOS_DEVICE:-}" ]]; then
    echo "$RECETTE_IOS_DEVICE"
    return
  fi
  local json
  json="$(mktemp)"
  xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1 || true
  python3 - "$json" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []
found = [d["hardwareProperties"]["udid"] for d in devices
         if d["hardwareProperties"].get("reality") == "physical"
         and d["hardwareProperties"].get("platform", "iOS") == "iOS"
         and d["connectionProperties"].get("tunnelState") == "connected"]
if len(found) != 1:
    print(f"recette: {len(found)} connected iPhone(s) — plug it in and unlock it, or set RECETTE_IOS_DEVICE", file=sys.stderr)
    sys.exit(1)
print(found[0])
PY
  local status=$?
  rm -f "$json"
  return $status
}

# On iOS a build of the App Store (or TestFlight) is not `builtByDeveloper`: same refusal as on
# Android before a development build replaces it.
guard_store_app_ios() {
  local udid="$1" json state
  json="$(mktemp)"
  xcrun devicectl device info apps --device "$udid" --bundle-id "$APP_ID" --json-output "$json" \
    >/dev/null 2>&1 || true
  state="$(python3 -c '
import json, sys
try:
    apps = json.load(open(sys.argv[1]))["result"]["apps"]
except Exception:
    apps = []
print("none" if not apps else ("dev" if apps[0].get("builtByDeveloper") else "store"))' "$json")"
  rm -f "$json"
  [[ "$state" == store ]] || return 0
  echo "recette: $APP_ID on the iPhone comes from the App Store or TestFlight." >&2
  echo "  A development build would replace it, its session and data with it." >&2
  confirm_replace
}

confirm_replace() {
  if [[ "${RECETTE_REPLACE_APP:-}" == 1 ]]; then
    echo "  RECETTE_REPLACE_APP=1: going on." >&2
    return 0
  fi
  if [[ -t 0 ]]; then
    local answer
    read -r -p "  Replace it with the development build? [y/N] " answer
    [[ "$answer" == [yYoO]* ]] && return 0
  fi
  echo "  Stopped. Reinstall it from the store afterwards; RECETTE_REPLACE_APP=1 to go on." >&2
  exit 1
}

RELAY_PID_FILE="$ROOT/.e2e/recette-relay.pid"
RELAY_LOG="$ROOT/.e2e/recette-relay.log"
lan_host() { echo "$(scutil --get LocalHostName).local"; }

# The stack on the local network for the iPhone (scripts/recette-lan-relay.py), as a background
# process of its own: it outlives `flutter run`, since an app started in profile mode — or one whose
# attach failed — keeps calling the API. `relay stop` ends it. One relay serves every session: one
# already answering on LAN_PORT (started by hand, say) is reused, never replaced.
relay() {
  local action="${1:-start}" host
  host="$(lan_host)"
  case "$action" in
    start)
      require_stack
      if curl -fs -m 3 -o /dev/null "http://$host:$LAN_PORT/api/config"; then
        echo "recette: relay already up on http://$host:$LAN_PORT"
        return
      fi
      mkdir -p "$ROOT/.e2e"
      nohup /usr/bin/python3 "$ROOT/scripts/recette-lan-relay.py" "$LAN_PORT" "$HTTP_PORT" \
        >"$RELAY_LOG" 2>&1 </dev/null &
      echo $! >"$RELAY_PID_FILE"
      local deadline=$((SECONDS + 5))
      until curl -fs -m 2 -o /dev/null "http://$host:$LAN_PORT/api/config"; do
        if [[ $SECONDS -ge $deadline ]]; then
          echo "recette: the relay does not answer on http://$host:$LAN_PORT — see $RELAY_LOG" >&2
          exit 1
        fi
        sleep 0.5
      done
      echo "recette: relay up, http://$host:$LAN_PORT -> $APP_URL (scripts/recette.sh relay stop)"
      ;;
    stop)
      if [[ -s "$RELAY_PID_FILE" ]] && kill "$(cat "$RELAY_PID_FILE")" 2>/dev/null; then
        echo "recette: relay stopped"
      else
        echo "recette: no relay started by this script (one started by hand is left alone)" >&2
      fi
      rm -f "$RELAY_PID_FILE"
      ;;
    status)
      if curl -fs -m 3 -o /dev/null "http://$host:$LAN_PORT/api/config"; then
        echo "recette: relay up on http://$host:$LAN_PORT"
      else
        echo "recette: no relay on http://$host:$LAN_PORT"
        return 1
      fi
      ;;
    *)
      echo "recette: relay [start|stop|status]" >&2
      exit 1
      ;;
  esac
}

# Flutter attaches to a debug app on an iPhone through its bundled iproxy, an x86_64 binary: without
# Rosetta the attach fails, flutter run exits, and a debug app cannot run unattached. A profile
# build runs on its own (no hot reload). So without Rosetta, and no mode chosen, go profile.
rosetta() { arch -x86_64 /usr/bin/true 2>/dev/null; }

# flutter run on the iPhone, its API this Mac's Bonjour name on LAN_PORT, relayed to the stack.
# iOS asks once for the local network: allow it.
mobile_ios() {
  require_stack
  local udid host mode=()
  udid="$(iphone)"
  guard_store_app_ios "$udid"
  host="$(lan_host)"
  if ! rosetta && [[ " $* " != *" --profile "* && " $* " != *" --release "* && " $* " != *" --debug "* ]]; then
    echo "recette: no Rosetta — flutter's iproxy (x86_64) cannot attach to a debug app: building --profile." >&2
    echo "  No hot reload. For debug: sudo softwareupdate --install-rosetta (your call), then --debug." >&2
    mode=(--profile)
  fi
  relay start
  echo "recette: app on $udid, API http://$host:$LAN_PORT (relayed to $APP_URL)"
  cd "$ROOT/mobile"
  local status=0
  flutter run -d "$udid" ${mode[@]+"${mode[@]}"} --dart-define="API_BASE_URL=http://$host:$LAN_PORT" "$@" || status=$?
  echo "recette: flutter run exited ($status); the relay stays up for the installed app — scripts/recette.sh relay stop" >&2
  return $status
}

mobile() {
  if [[ "${1:-}" == --ios ]]; then
    shift
    mobile_ios "$@"
    return
  fi
  require_stack
  local serial
  serial="$(phone)"
  guard_store_app "$serial"
  # The Patrol setup's dart-defines and port forwards (API on localhost, mailpit), on this phone.
  export E2E_PLATFORM=android PATROL_DEVICE="$serial"
  # shellcheck source=../mobile/tool/e2e_env.sh
  source "$ROOT/mobile/tool/e2e_env.sh"
  e2e_prepare_device
  cd "$ROOT/mobile"
  # shellcheck disable=SC2086 # E2E_DART_DEFINES holds several flags, none with a space.
  exec flutter run -d "$serial" $E2E_DART_DEFINES "$@"
}

unplug() {
  local serial
  serial="$(phone)"
  "$ADB" -s "$serial" reverse --remove-all
  "$ADB" -s "$serial" forward --remove "tcp:$CDP_PORT" 2>/dev/null || true
  echo "recette: forwards removed from $serial"
}

cmd="${1:-}"
shift || true
case "$cmd" in
  up | build | down | reset | logs | tunnel) stack "$cmd" "$@" ;;
  seed) seed ;;
  accounts) accounts ;;
  dev) dev ;;
  web-android) web_android "$@" ;;
  look) look "$@" ;;
  mobile) mobile "$@" ;;
  relay) relay "$@" ;;
  unplug) unplug ;;
  *)
    sed -n '2,38p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
