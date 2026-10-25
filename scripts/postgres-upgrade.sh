#!/usr/bin/env bash
# Move this environment's PostgreSQL to the major version docker-compose.yml now declares, on a new
# volume, keeping the old one untouched (docs/OPERATIONS.md, « PostgreSQL major upgrade »).
#
#   scripts/postgres-upgrade.sh [--force]
#
# Run it from a checkout already at the commit that changed the image, while the stack still runs
# the previous one. It stops what writes to the database (backend, frontend, goatcounter), copies
# every database and role with pg_dumpall into a throwaway container of the new image, checks that
# each table holds as many rows on both sides, and only then switches the stack over: deploy.sh on a
# host, `docker compose up -d postgres` on a workstation. Expect a few minutes of downtime: two
# majors cannot share the data, so this cannot roll.
#
# pg_dumpall rather than backup.sh + restore.sh: the backup holds $POSTGRES_DB alone, so GoatCounter's
# database and role would come back empty. The old volume is never written to — rolling back is
# checking out the previous commit and redeploying it, which loses what was written since.
#
# Asks for confirmation unless --force. Run scripts/backup.sh (as root) first anyway.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_backup_common.sh
. "$SCRIPT_DIR/_backup_common.sh"

FORCE=false
case "${1:-}" in
  "") ;;
  --force) FORCE=true ;;
  -h | --help) sed -n '2,18p' "$0"; exit 0 ;;
  *) die "unknown argument: $1 (try --help)" ;;
esac

cd "$REPO_ROOT"
load_env
require_vars ENV_NAME POSTGRES_USER POSTGRES_PASSWORD

# The volume docker-compose.yml mounts on /var/lib/postgresql. Since 18 the image keeps each major
# under <major>/docker there, so a later upgrade can use `pg_upgrade --link` inside it.
VOLUME_KEY=pg_clusters
WRITERS=(backend frontend goatcounter)

# The image the postgres service declares, read the way the backend tests do (ContainerImages).
IMAGE="$(awk '/^  [A-Za-z0-9_-]+:[[:space:]]*$/ { in_pg = ($1 == "postgres:") }
  in_pg && $1 == "image:" { print $2; exit }' docker-compose.yml)"
[[ -n "$IMAGE" ]] || die "no image for the postgres service in docker-compose.yml"

SOURCE="$(require_container postgres)"
# The source's credentials are read from its own environment, as backup.sh does.
pg_source() { docker exec -i "$SOURCE" sh -c 'psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" "$@"' psql "$@"; }

SOURCE_VERSION="$(pg_source -d postgres -tAc 'show server_version_num')"
TARGET_MAJOR="$(docker run --rm "$IMAGE" postgres -V | sed -E 's/.* ([0-9]+)\..*/\1/')"
((TARGET_MAJOR > SOURCE_VERSION / 10000)) \
  || die "postgres already runs $((SOURCE_VERSION / 10000)), $IMAGE is $TARGET_MAJOR: nothing to upgrade"

SOURCE_VOLUME="$(docker inspect -f \
  '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{end}}{{end}}' "$SOURCE")"
if is_swarm; then
  TARGET_VOLUME="${ENV_NAME}_$VOLUME_KEY"
  VOLUME_LABELS=(--label "com.docker.stack.namespace=$ENV_NAME")
else
  PROJECT="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$SOURCE")"
  [[ -n "$PROJECT" ]] || die "the postgres container belongs to no compose project"
  TARGET_VOLUME="${PROJECT}_$VOLUME_KEY"
  # The labels compose would have set: without them it warns that it did not create the volume.
  VOLUME_LABELS=(--label "com.docker.compose.project=$PROJECT" --label "com.docker.compose.volume=$VOLUME_KEY")
fi
[[ "$SOURCE_VOLUME" != "$TARGET_VOLUME" ]] || die "postgres already runs on $TARGET_VOLUME"
! docker volume inspect "$TARGET_VOLUME" >/dev/null 2>&1 \
  || die "volume $TARGET_VOLUME already exists — left by an earlier attempt? Inspect it, then docker volume rm it"

# Checked before anything stops, as restore.sh does: deploy.sh would refuse halfway through.
if is_swarm; then
  . "$SCRIPT_DIR/_image_tag.sh"
  ! worktree_dirty || die "uncommitted changes in $REPO_ROOT: deploy.sh would refuse to redeploy"
  docker network inspect pedalons-shared >/dev/null 2>&1 \
    || die "network pedalons-shared missing — deploy the shared stack first (scripts/deploy.sh --shared)"
  for image in "pedalons-backend:$ENV_NAME$(image_suffix)" "pedalons-frontend:$ENV_NAME$(image_suffix)"; do
    docker image inspect "$image" >/dev/null 2>&1 || die "image $image missing — run ./build.sh"
  done
fi

if ! $FORCE; then
  cat <<EOF

  This moves '$ENV_NAME' from PostgreSQL $((SOURCE_VERSION / 10000)) to $TARGET_MAJOR ($IMAGE):
    - backend, frontend and goatcounter stop for the duration of the copy
    - every database is copied from $SOURCE_VOLUME into a new volume, $TARGET_VOLUME
    - $SOURCE_VOLUME is left as it is, for a rollback

  Run scripts/backup.sh first.

EOF
  read -r -p "  Type the environment name to confirm: " answer
  [[ "$answer" == "$ENV_NAME" ]] || die "aborted"
fi

# --- 1. stop the writers -----------------------------------------------------

TEMP="${ENV_NAME}-postgres-upgrade"
errors="$(mktemp)"
declare -A replicas
stopped=()
restart_writers() {
  local service
  if is_swarm; then
    for service in "${!replicas[@]}"; do
      docker service scale -d "${ENV_NAME}_$service=${replicas[$service]}" >/dev/null || true
    done
  elif ((${#stopped[@]} > 0)); then
    docker start "${stopped[@]}" >/dev/null || true
  fi
}

# Until the switch, a failure leaves the stack as it found it: the copy is thrown away.
switched=false
on_exit() {
  local rc=$?
  rm -f "$errors"
  ((rc == 0)) && return 0
  if $switched; then
    log "FAILED after the switch to $TARGET_VOLUME — see docs/OPERATIONS.md, « PostgreSQL major upgrade », to roll back"
    return
  fi
  log "FAILED before the switch: dropping the copy, restarting the writers on $SOURCE_VOLUME"
  docker rm -f "$TEMP" >/dev/null 2>&1 || true
  docker volume rm "$TARGET_VOLUME" >/dev/null 2>&1 || true
  restart_writers
}
trap on_exit EXIT

log "stopping ${WRITERS[*]}"
for service in "${WRITERS[@]}"; do
  if is_swarm; then
    count="$(docker service inspect -f '{{.Spec.Mode.Replicated.Replicas}}' "${ENV_NAME}_$service" 2>/dev/null)" \
      || continue
    replicas[$service]="$count"
    docker service scale "${ENV_NAME}_$service=0" >/dev/null
  else
    id="$(container_of "$service")"
    [[ -n "$id" ]] || continue
    docker stop "$id" >/dev/null
    stopped+=("$id")
  fi
done

# --- 2. copy into a throwaway container of the new image ---------------------
#
# Initialised empty: no POSTGRES_DB, and no init scripts (the image's would create PostGIS and
# template_postgis, which the dump brings along). The only object it then shares with the dump is
# the superuser, whose CREATE ROLE is the one error expected below.
log "starting $IMAGE on a new volume $TARGET_VOLUME"
docker volume create "${VOLUME_LABELS[@]}" "$TARGET_VOLUME" >/dev/null
docker run -d --name "$TEMP" --network none \
  -e POSTGRES_USER -e POSTGRES_PASSWORD -e POSTGRES_DB=postgres \
  --tmpfs /docker-entrypoint-initdb.d \
  --mount "type=volume,src=$TARGET_VOLUME,dst=/var/lib/postgresql" \
  "$IMAGE" >/dev/null
# Over TCP: initdb's temporary server listens on the socket alone, and is ready before it is done.
for _ in $(seq 1 60); do
  docker exec "$TEMP" pg_isready -q -h 127.0.0.1 -U "$POSTGRES_USER" && break
  sleep 2
done
docker exec "$TEMP" pg_isready -q -h 127.0.0.1 -U "$POSTGRES_USER" \
  || die "$IMAGE never became ready — docker logs $TEMP"
pg_target() { docker exec -i "$TEMP" psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" "$@"; }

log "copying every database and role (pg_dumpall)"
docker exec "$SOURCE" sh -c 'pg_dumpall -U "$POSTGRES_USER"' \
  | docker exec -i "$TEMP" psql -X -q -U "$POSTGRES_USER" -d postgres >/dev/null 2>"$errors"
if grep 'ERROR:' "$errors" | grep -vq "role \"$POSTGRES_USER\" already exists"; then
  cat "$errors" >&2
  die "the copy reported errors"
fi

# --- 3. check the copy -------------------------------------------------------
#
# Every database, its extensions, and the row count of each table. The writers are stopped, so
# both sides must agree exactly.
COUNTS="SELECT format('%s.%s %s', n.nspname, c.relname,
    (xpath('/row/n/text()', query_to_xml(format('SELECT count(*) AS n FROM %I.%I', n.nspname, c.relname), false, true, '')))[1]::text)
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE c.relkind IN ('r', 'p') AND n.nspname NOT IN ('pg_catalog', 'information_schema') AND n.nspname NOT LIKE 'pg_toast%'
  UNION ALL SELECT 'extension ' || extname FROM pg_extension
  ORDER BY 1"
inventory() {
  local run="$1" db
  for db in $($run -d postgres -tAc "SELECT datname FROM pg_database WHERE datallowconn ORDER BY 1"); do
    echo "database $db"
    $run -d "$db" -tAc "$COUNTS"
  done
}

log "comparing databases, extensions and row counts"
before="$(inventory pg_source)"
after="$(inventory pg_target)"
if [[ "$before" != "$after" ]]; then
  diff <(echo "$before") <(echo "$after") >&2 || true
  die "the copy differs from the source"
fi
log "$(grep -c '^database ' <<<"$before") databases, $(grep -vc -e '^database ' -e '^extension ' <<<"$before") tables: identical"

docker stop -t 60 "$TEMP" >/dev/null
docker rm "$TEMP" >/dev/null

# --- 4. switch ---------------------------------------------------------------

switched=true
if is_swarm; then
  # Puts every service back at the replicas the file gives it, the writers included.
  log "redeploying $ENV_NAME on $TARGET_VOLUME"
  POSTGRES_UPGRADE=1 "$SCRIPT_DIR/deploy.sh"
else
  log "recreating postgres on $TARGET_VOLUME"
  docker compose -p "$PROJECT" up -d postgres
  for _ in $(seq 1 60); do
    [[ "$(docker inspect -f '{{.State.Health.Status}}' "$(container_of postgres)" 2>/dev/null)" == "healthy" ]] && break
    sleep 2
  done
  restart_writers
fi

log "done: PostgreSQL $TARGET_MAJOR on $TARGET_VOLUME. $SOURCE_VOLUME is kept for a rollback — drop it once the new one has been through a backup"
