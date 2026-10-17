#!/usr/bin/env bash
# End-to-end test stack: a full application (traefik + SSR frontend + backend + postgres + MinIO +
# imgproxy + mailpit) on an empty database, next to — never instead of — the workstation stack.
#
#   scripts/e2e.sh build [all|frontend|backend]   build the tribly-e2e images (build.sh + .env.e2e)
#   scripts/e2e.sh up                             start the stack and wait until it answers
#   scripts/e2e.sh test [playwright args…]        run the Playwright suite against it
#   scripts/e2e.sh run [playwright args…]         up, then test
#   scripts/e2e.sh reset                          wipe database, files and saved sessions, then up
#   scripts/e2e.sh down                           stop the stack (the database survives)
#   scripts/e2e.sh logs [service…]                follow the logs
#   scripts/e2e.sh compose <args…>                any other docker compose command, on this stack
#
# Configuration lives in .env.e2e (committed: throwaway values only). See frontend/e2e/README.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env.e2e"
STATE_DIR="$ROOT/.e2e"

set -a
. "$ENV_FILE"
set +a

compose() {
  docker compose -p "$ENV_NAME" --project-directory "$ROOT" --env-file "$ENV_FILE" \
    -f "$ROOT/docker-compose.yml" -f "$ROOT/docker-compose.e2e.yml" "$@"
}

prepare_state() {
  mkdir -p "$STATE_DIR/keys" "$STATE_DIR/storage" "$STATE_DIR/cache"
  if [ ! -f "$STATE_DIR/keys/privateKey.pem" ]; then
    echo "e2e: generating a JWT key pair in $STATE_DIR/keys"
    openssl genrsa -out "$STATE_DIR/keys/privateKey.pem" 2048 2>/dev/null
    openssl rsa -in "$STATE_DIR/keys/privateKey.pem" -pubout -out "$STATE_DIR/keys/publicKey.pem" 2>/dev/null
    chmod 600 "$STATE_DIR/keys/privateKey.pem"
  fi
}

# tileserver comes from the workstation stack. Without it, start on an empty network of our own:
# everything works except map tiles.
ensure_shared_network() {
  if docker network inspect "$E2E_SHARED_NETWORK" >/dev/null 2>&1; then
    return
  fi
  echo "e2e: network $E2E_SHARED_NETWORK not found (workstation stack down?) —" \
    "starting without tileserver" >&2
  export E2E_SHARED_NETWORK="$ENV_NAME-shared"
  docker network inspect "$E2E_SHARED_NETWORK" >/dev/null 2>&1 ||
    docker network create "$E2E_SHARED_NETWORK" >/dev/null
}

# Routing goes to the Stadia Maps API, with a key that .env.e2e (committed) must not hold.
# docker-compose.e2e.yml interpolates STADIAMAPS_API_KEY from this shell: take it from the
# environment (the CI's secret), else from the workstation's .env — without ever printing it.
# Without a key the planner's one real-router test simulates the router too (E2E_NO_ROUTING,
# frontend/e2e/gpx-planner.e2e.ts).
ensure_routing_key() {
  [ -z "${_ROUTING_KEY_CHECKED:-}" ] || return 0
  _ROUTING_KEY_CHECKED=1
  if [ -z "${STADIAMAPS_API_KEY:-}" ] && [ -f "$ROOT/.env" ]; then
    local line
    line="$(grep -m1 '^STADIAMAPS_API_KEY=' "$ROOT/.env" || true)"
    if [ -n "$line" ]; then
      STADIAMAPS_API_KEY="${line#STADIAMAPS_API_KEY=}"
      STADIAMAPS_API_KEY="${STADIAMAPS_API_KEY%\"}"
      STADIAMAPS_API_KEY="${STADIAMAPS_API_KEY#\"}"
      export STADIAMAPS_API_KEY
    fi
  fi
  if [ -z "${STADIAMAPS_API_KEY:-}" ]; then
    echo "e2e: STADIAMAPS_API_KEY not set (environment or .env) — the planner simulates the router" >&2
    export E2E_NO_ROUTING=1
  fi
}

ensure_images() {
  local backend=0 frontend=0 missing=""
  docker image inspect "pedalons-backend:$ENV_NAME" >/dev/null 2>&1 || backend=1
  docker image inspect "pedalons-frontend:$ENV_NAME" >/dev/null 2>&1 || frontend=1
  if [ $backend = 1 ] && [ $frontend = 1 ]; then
    missing=all
  elif [ $backend = 1 ]; then
    missing=backend
  elif [ $frontend = 1 ]; then
    missing=frontend
  fi
  if [ -n "$missing" ]; then
    echo "e2e: no pedalons-*:$ENV_NAME image yet, building ($missing)"
    build "$missing"
  fi
}

build() {
  (cd "$ROOT" && ENV_FILE="$ENV_FILE" ./build.sh "${1:-all}")
}

wait_for() {
  local url="$1" deadline=$((SECONDS + ${2:-240}))
  printf 'e2e: waiting for %s ' "$url"
  until [ "$(curl -s -o /dev/null -w '%{http_code}' "$url")" = "200" ]; do
    if [ $SECONDS -ge $deadline ]; then
      echo
      echo "e2e: $url did not answer 200 in time — scripts/e2e.sh logs backend" >&2
      exit 1
    fi
    printf '.'
    sleep 2
  done
  echo ' ok'
}

up() {
  prepare_state
  ensure_shared_network
  ensure_routing_key
  ensure_images
  compose --profile app up -d --remove-orphans
  wait_for "http://localhost:$HTTP_PORT/api/config"
  wait_for "http://localhost:$HTTP_PORT/" 60
  echo "e2e: stack up — app http://localhost:$HTTP_PORT, mailpit http://localhost:$E2E_MAILPIT_PORT"
}

run_tests() {
  # `test` alone, after an `up` in another shell: decide E2E_NO_ROUTING the same way.
  ensure_routing_key
  (cd "$ROOT/frontend" && pnpm exec playwright test "$@")
}

reset() {
  compose --profile app down -v --remove-orphans
  rm -rf "$STATE_DIR/storage" "$STATE_DIR/cache" "$ROOT/frontend/e2e/.auth"
  up
}

cmd="${1:-}"
shift || true
case "$cmd" in
  build) build "${1:-all}" ;;
  up) up ;;
  test) run_tests "$@" ;;
  run)
    up
    run_tests "$@"
    ;;
  reset) reset ;;
  down) compose --profile app down --remove-orphans ;;
  logs) compose logs -f "$@" ;;
  compose)
    ensure_routing_key
    compose "$@"
    ;;
  *)
    sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
