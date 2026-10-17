#!/usr/bin/env bash
# Deploy — or update — this checkout's environment as the Swarm stack ${ENV_NAME}.
#
#   ./build.sh && scripts/deploy.sh   the build of the checked-out commit
#   scripts/deploy.sh --rev <commit>  an earlier build, without rebuilding (e.g. --rev HEAD~1)
#   scripts/deploy.sh --hold-app      backend, frontend and goatcounter at 0 replicas (restore.sh)
#   scripts/deploy.sh --shared        the shared stack instead, from the ~/shared checkout
#   scripts/deploy.sh --monitoring    the monitoring stack, from the ~/shared checkout too
#
# Never run `docker stack deploy` by hand on this file, for two reasons this script exists for:
#
#   - `docker stack deploy` reads no .env. Every ${VAR} of docker-compose.yml would expand to an
#     empty string, and only the few spelled `${VAR:?}` would stop it — STADIAMAPS_API_KEY among
#     them: the backend would start without a routing key, or not start at all.
#   - backend and frontend run the image tagged with a commit (scripts/_image_tag.sh), which this
#     script picks. A new tag is a new service spec, which Swarm rolls out start-first: the old task
#     serves until the new one is healthy, and a new task that never gets there is rolled back. The
#     script waits for that outcome (DEPLOY_TIMEOUT, 600s by default) and exits non-zero on a rollback.
#
# The stack is named after ENV_NAME, not after the checkout: scripts/backup.sh and restore.sh find
# its containers and volumes (${ENV_NAME}_postgres_data...) by that name.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log() { printf '%s  %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
die() {
  printf '%s  ERROR: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
  exit 1
}

# Builds kept per image, besides the one running: how far back --rev can go without rebuilding.
KEEP_BUILDS=5

HOLD_APP=false
SHARED=false
MONITORING=false
REV=""
case "${1:-}" in
  "") ;;
  --hold-app) HOLD_APP=true ;;
  --shared) SHARED=true ;;
  --monitoring) MONITORING=true ;;
  --rev) REV="${2:?--rev needs a commit}" ;;
  -h | --help) sed -n '2,22p' "$0"; exit 0 ;;
  *) die "unknown argument: $1 (try --help)" ;;
esac

cd "$REPO_ROOT"
. "$SCRIPT_DIR/_image_tag.sh"
[[ "$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)" == "active" ]] \
  || die "this node is not in a swarm — run 'docker swarm init' once (see docs/OPERATIONS.md, Deployment)"

if $MONITORING; then
  # The .env of the ~/shared checkout: it carries the ALERT_* and GRAFANA_* keys of
  # services/monitoring/env.example, and nothing the shared stack itself reads.
  [[ -f .env ]] || die "no .env in $REPO_ROOT — add the keys of services/monitoring/env.example"
  set -a
  . ./.env
  set +a
  for var in GRAFANA_ADMIN_PASSWORD ALERT_SMTP_SMARTHOST ALERT_SMTP_USERNAME ALERT_SMTP_PASSWORD \
    ALERT_SMTP_FROM ALERT_EMAIL_TO ALERT_WATCHDOG_PING_URL; do
    [[ -n "${!var:-}" ]] || die "$var is not set in .env (see services/monitoring/env.example)"
  done
  # Alertmanager refuses a smarthost without its port, and Swarm would then restart it in a loop.
  [[ "$ALERT_SMTP_SMARTHOST" =~ :[0-9]+$ ]] \
    || die "ALERT_SMTP_SMARTHOST must be host:port (587, STARTTLS), got '$ALERT_SMTP_SMARTHOST'"
  docker network inspect pedalons-shared >/dev/null 2>&1 \
    || die "network pedalons-shared missing — deploy the shared stack first (scripts/deploy.sh --shared)"
  # A missing bind-mount source makes Swarm reject the task (Caddy's logs: docs/OPERATIONS.md,
  # « Access logs »).
  [[ -d /var/log/caddy ]] || die "no /var/log/caddy — set up Caddy's access logs first"
  command -v envsubst >/dev/null || die "envsubst is not installed (apt install gettext-base)"

  # Alertmanager reads no environment: its configuration is rendered here, the secrets written
  # beside it as files so that no value can break the YAML. World-readable, because Alertmanager
  # runs as nobody; the checkout's own permissions keep other users out.
  out=data/monitoring/alertmanager
  mkdir -p "$out" data/monitoring/prometheus-targets
  # Only these, spelled out: anything else in the template that looks like a variable stays as is.
  # shellcheck disable=SC2016
  envsubst '${ALERT_SMTP_SMARTHOST} ${ALERT_SMTP_USERNAME} ${ALERT_SMTP_FROM} ${ALERT_EMAIL_TO}' \
    < services/monitoring/alertmanager/alertmanager.yml > "$out/alertmanager.yml"
  printf '%s' "$ALERT_SMTP_PASSWORD" > "$out/smtp_password"
  printf '%s' "$ALERT_WATCHDOG_PING_URL" > "$out/watchdog_url"
  chmod 644 "$out/alertmanager.yml" "$out/smtp_password" "$out/watchdog_url"

  # Caddy listens on the host: Prometheus reaches it through the gateway of docker_gwbridge, the
  # bridge every Swarm task leaves the overlay by.
  if [[ -z "${CADDY_METRICS_TARGET:-}" ]]; then
    gateway="$(docker network inspect docker_gwbridge -f '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null)" \
      || die "no docker_gwbridge network — set CADDY_METRICS_TARGET in .env"
    CADDY_METRICS_TARGET="$gateway:2020"
  fi
  printf '[{"targets": ["%s"], "labels": {"instance": "caddy"}}]\n' "$CADDY_METRICS_TARGET" \
    > data/monitoring/prometheus-targets/caddy.json

  # Configuration files are bind-mounted: a task already running keeps its old configuration
  # unless told to reload. Those present before the deploy get SIGHUP after it; a task the deploy
  # creates reads the new files anyway (and a SIGHUP too early in its start would kill it).
  declare -A running
  for service in prometheus alertmanager alloy; do
    running[$service]="$(docker ps -q --filter "label=com.docker.swarm.service.name=pedalons-monitoring_$service")"
  done

  log "deploying stack pedalons-monitoring"
  docker stack deploy --prune -c docker-compose.monitoring.yml pedalons-monitoring
  for service in "${!running[@]}"; do
    for id in ${running[$service]}; do
      docker kill -s HUP "$id" >/dev/null 2>&1 && log "reloaded $service"
    done
  done
  log "loki and grafana read their files at start: docker service update --force pedalons-monitoring_<service> after changing them"
  exit 0
fi

if $SHARED; then
  # Its .env is optional: the shared stack reads no variable of its own any more, the file only
  # carries the keys of the monitoring stack (--monitoring).
  if [[ -f .env ]]; then
    set -a
    . ./.env
    set +a
  fi
  log "deploying stack pedalons-shared"
  docker stack deploy -c docker-compose.shared.yml pedalons-shared
  exit 0
fi

[[ -f .env ]] || die "no .env in $REPO_ROOT — copy .env.example and fill it in"
# Same parsing as build.sh, which the values have to survive anyway.
set -a
. ./.env
set +a
[[ -n "${ENV_NAME:-}" ]] || die "ENV_NAME is not set in .env"
[[ -z "${COMPOSE_FILE:-}" ]] \
  || die "COMPOSE_FILE is set in .env: that is a workstation, which runs compose, not a stack"

# Web analytics (docs/OPERATIONS.md, « Web analytics »): production sets both keys, staging neither,
# and GoatCounter then runs at 0 replicas. One without the other would deploy a counter rewriting
# every /count to an empty Host, or one that can never log in to its database — counting nothing,
# silently.
if [[ -n "${GOATCOUNTER_VHOST:-}" && -n "${GOATCOUNTER_DB_PASSWORD:-}" ]]; then
  GOATCOUNTER=true
elif [[ -z "${GOATCOUNTER_VHOST:-}" && -z "${GOATCOUNTER_DB_PASSWORD:-}" ]]; then
  GOATCOUNTER=false
else
  die "GOATCOUNTER_VHOST and GOATCOUNTER_DB_PASSWORD go together: set both (production) or neither"
fi
# The site would count towards a /count that nothing serves.
$GOATCOUNTER || [[ -z "${PEDALONS_ANALYTICS_COUNT_PATH:-}" ]] \
  || die "PEDALONS_ANALYTICS_COUNT_PATH is set but GoatCounter is not (GOATCOUNTER_VHOST, GOATCOUNTER_DB_PASSWORD)"

docker network inspect pedalons-shared >/dev/null 2>&1 \
  || die "network pedalons-shared missing — deploy the shared stack first (scripts/deploy.sh --shared)"
if [[ -z "$REV" ]] && worktree_dirty; then
  die "uncommitted changes in $REPO_ROOT: deploy a commit — commit or stash them, or pass --rev"
fi
suffix="$(image_suffix "${REV:-HEAD}")" || die "unknown commit: $REV"
for image in "pedalons-backend:$ENV_NAME$suffix" "pedalons-frontend:$ENV_NAME$suffix"; do
  docker image inspect "$image" >/dev/null 2>&1 || die "image $image missing — run ./build.sh"
done
# Read by docker-compose.yml, one per service so that each could move alone.
export BACKEND_IMAGE_SUFFIX="$suffix" FRONTEND_IMAGE_SUFFIX="$suffix"
[[ -f data/keys/privateKey.pem && -f data/keys/publicKey.pem ]] \
  || die "no JWT keys in data/keys — run data/keys/generate-keys.sh"
# Compose creates a missing bind-mount source; Swarm refuses to start the task instead.
mkdir -p data/storage data/cache

files=(-c docker-compose.yml)
# Services held at 0 replicas by an overlay. --hold-app: the backend would boot on the empty database
# restore.sh is about to fill, and GoatCounter loop on a role that does not exist yet
# (goatcounter-init.sh db brings it back). Without the GOATCOUNTER_* keys: GoatCounter, always —
# the file cannot leave it out, `docker stack deploy` refuses profiles.
held=()
$HOLD_APP && held+=(backend frontend goatcounter)
$GOATCOUNTER || $HOLD_APP || held+=(goatcounter)
if ((${#held[@]} > 0)); then
  hold="$(mktemp)"
  trap 'rm -f "$hold"' EXIT
  {
    printf 'services:\n'
    printf '  %s:\n    deploy:\n      replicas: 0\n' "${held[@]}"
  } > "$hold"
  files+=(-c "$hold")
fi

# The update each service ran last, "<state> <started at>", or nothing for a service never updated.
update_status() {
  docker service inspect -f '{{with .UpdateStatus}}{{.State}} {{.StartedAt}}{{end}}' \
    "${ENV_NAME}_$1" 2>/dev/null || true
}
declare -A before
for service in backend frontend; do
  before[$service]="$(update_status "$service")"
done

log "deploying stack $ENV_NAME with the build of ${suffix#-}"
# Swarm warns that it cannot resolve these images on a registry: there is none, the images are on
# this node, which is all a single-node swarm needs.
docker stack deploy --prune "${files[@]}" "$ENV_NAME"

$HOLD_APP && exit 0

# GoatCounter is not waited for: it is off the site's critical path, and on its first deploy it
# restarts in a loop until scripts/goatcounter-init.sh db creates its role.

# `docker stack deploy` returns once the specs are written, not once they run. A new build that
# never turns healthy is rolled back by Swarm on its own, and without this wait the deploy would
# look like it went through. Waits for backend and frontend to converge on this build, and fails on
# a rollback or a timeout. The bound covers the healthcheck's start_period (180s), its retries, the
# 30s monitor window and a rollback.
DEPLOY_TIMEOUT="${DEPLOY_TIMEOUT:-600}"

# Ok when service $1 runs this build alone, healthy, and has no update in flight; "failed: <why>"
# when it never will; nothing yet.
rollout_state() {
  local service="$1" name="${ENV_NAME}_$1" expected="pedalons-$1:$ENV_NAME$suffix"
  local spec_image status state
  local -a running
  spec_image="$(docker service inspect -f '{{.Spec.TaskTemplate.ContainerSpec.Image}}' "$name" \
    2>/dev/null)" || return 0
  # A rollback puts the previous spec back: the image is the first thing to tell.
  [[ "${spec_image%%@*}" == "$expected" ]] || {
    echo "failed: rolled back to ${spec_image%%@*}"
    return
  }
  status="$(update_status "$service")"
  state="${status%% *}"
  # A status unchanged since before the deploy is a previous update's: this deploy either started
  # none (same spec, or a service just created) or has not started it yet — the tasks decide.
  if [[ "$status" != "${before[$service]}" ]]; then
    case "$state" in
      completed) ;;
      rollback_* | paused) echo "failed: update $state" && return ;;
      *) return ;;
    esac
  fi
  # By the reference the task was started from, not by `ancestor`: build.sh's carry_over gives an
  # unchanged image a new tag, and the old task would then pass for the new one.
  mapfile -t running < <(docker ps --filter "label=com.docker.swarm.service.name=$name" \
    --format '{{.Image}} {{.Status}}')
  ((${#running[@]} == 1)) && [[ "${running[0]%% *}" == "$expected"* ]] \
    && [[ "${running[0]}" == *"(healthy)"* ]] && echo ok
  return 0
}

log "waiting for backend and frontend to run the build of ${suffix#-} (up to ${DEPLOY_TIMEOUT}s)"
deadline=$((SECONDS + DEPLOY_TIMEOUT))
pending=(backend frontend)
while ((${#pending[@]} > 0)); do
  still=()
  for service in "${pending[@]}"; do
    state="$(rollout_state "$service")"
    case "$state" in
      ok) log "$service runs the build of ${suffix#-}" ;;
      failed:*)
        die "$service ${state#failed: } — see: docker service ps --no-trunc ${ENV_NAME}_$service"
        ;;
      *) still+=("$service") ;;
    esac
  done
  pending=("${still[@]}")
  ((${#pending[@]} == 0)) && break
  ((SECONDS < deadline)) \
    || die "${pending[*]} not converged after ${DEPLOY_TIMEOUT}s — see: docker service ps --no-trunc ${ENV_NAME}_${pending[0]}"
  sleep 5
done

# Drop old builds, newest KEEP_BUILDS kept. The image in each service's spec is never dropped, nor
# the one of its previous spec — what `docker service rollback` goes back to.
for service in backend frontend; do
  keep=()
  for field in Spec PreviousSpec; do
    keep+=("$(docker service inspect -f "{{with .$field}}{{.TaskTemplate.ContainerSpec.Image}}{{end}}" \
      "${ENV_NAME}_$service" 2>/dev/null || true)")
  done
  docker images "pedalons-$service" --format '{{.Repository}}:{{.Tag}}' \
    | grep -E "^pedalons-$service:$ENV_NAME-[0-9a-f]{12}\$" \
    | tail -n +$((KEEP_BUILDS + 1)) \
    | while read -r image; do
      [[ " ${keep[*]} " == *" $image"[@\ ]* ]] && continue
      docker rmi "$image" >/dev/null && log "dropped old build $image"
    done
done

log "deployed the build of ${suffix#-}"
log "back to the previous build: docker service rollback ${ENV_NAME}_backend (or --rev <commit>)"
