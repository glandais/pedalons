#!/usr/bin/env bash
# Restore a deployed environment from a snapshot produced by scripts/backup.sh.
#
#   scripts/restore.sh --list                     list the snapshots available on the backup host
#   scripts/restore.sh --secrets-only             fetch .env + data/keys only (bootstrap a new host)
#   scripts/restore.sh [--snapshot latest|<STAMP>] [--force] [--keep-fetch]
#
# DESTRUCTIVE: the full restore takes the stack down and drops this environment's postgres and minio
# volumes before repopulating them. It asks for confirmation unless --force.
#
# It follows the stack wherever it runs: as the Swarm stack ${ENV_NAME} when this node is in a swarm
# (a deployed host, see scripts/deploy.sh), as a compose project otherwise (a workstation drill).
#
# Only rsync, age and docker are used, so this works both from the production host (root, restricted
# backup key) and from any machine that can read the backup store over plain SSH — which is how a
# restore drill is run without touching production. It reads the dated snapshots, never incoming/:
# a night's push is restorable once backup-promote.sh has promoted it on the backup host.
#
# The dump and the secrets are encrypted to an age public key (see backup.sh). Decrypting them needs
# the matching private key, which lives offline: put it in a file for the duration of the restore,
# point BACKUP_AGE_IDENTITY at it, and delete it afterwards. --list does not need it.
#
# Not in the backup, and therefore not restored: the docker images (rebuild with ./build.sh at the
# commit recorded in MANIFEST), data/cache (regenerable), and the shared tileserver data.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_backup_common.sh
. "$SCRIPT_DIR/_backup_common.sh"

SNAPSHOT="latest"
SECRETS_ONLY=false
LIST_ONLY=false
FORCE=false
KEEP_FETCH=false

while (($# > 0)); do
  case "$1" in
    --snapshot) SNAPSHOT="${2:?--snapshot needs a value}"; shift 2 ;;
    --secrets-only) SECRETS_ONLY=true; shift ;;
    --list) LIST_ONLY=true; shift ;;
    --force) FORCE=true; shift ;;
    --keep-fetch) KEEP_FETCH=true; shift ;;
    -h | --help) sed -n '2,20p' "$0"; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

cd "$REPO_ROOT"

# On a brand-new host there is no .env yet — that is exactly what --secrets-only is for, so it takes
# its coordinates from the environment instead.
if [[ -f "$REPO_ROOT/.env" ]]; then
  load_env
else
  load_backup_env
  $SECRETS_ONLY || $LIST_ONLY \
    || die "no .env — start with: BACKUP_REMOTE=... BACKUP_REMOTE_PATH=... $0 --secrets-only"
fi
require_vars BACKUP_REMOTE BACKUP_REMOTE_PATH

if $LIST_ONLY; then
  complete="$(list_complete_snapshots || true)"
  log "snapshots on $BACKUP_REMOTE:${BACKUP_REMOTE_PATH}"
  while read -r name; do
    [[ -n "$name" ]] || continue
    if printf '%s\n' "$complete" | grep -qx "$name"; then
      printf '    %s\n' "$name"
    else
      printf '    %s  (INCOMPLETE — failed run, not restorable)\n' "$name"
    fi
  done < <(list_snapshots)
  exit 0
fi

# Checked before anything is fetched: without the key, the snapshot is unreadable.
command -v age >/dev/null || die "age is not installed (apt install age)"
[[ -n "${BACKUP_AGE_IDENTITY:-}" ]] \
  || die "BACKUP_AGE_IDENTITY is not set — point it at the age private key (kept offline) for this restore"
[[ -r "$BACKUP_AGE_IDENTITY" ]] || die "BACKUP_AGE_IDENTITY not readable: $BACKUP_AGE_IDENTITY"
decrypt() { age -d -i "$BACKUP_AGE_IDENTITY" "$1"; }

if [[ "$SNAPSHOT" == "latest" ]]; then
  SNAPSHOT="$(latest_complete_snapshot || true)"
  [[ -n "$SNAPSHOT" ]] || die "no complete snapshot on $BACKUP_REMOTE:$BACKUP_REMOTE_PATH (try --list)"
fi

# Everything is pulled to a local directory first: the checksums are verified before a single volume
# is touched, so a corrupt or truncated snapshot is found *before* the current data is destroyed.
FETCH="${BACKUP_FETCH_DIR:-/var/tmp/pedalons-restore}/$SNAPSHOT"
mkdir -p "$FETCH"

log "fetching $(remote_url "$SNAPSHOT") into $FETCH"
rsync_remote -a --info=progress2 --exclude="/minio/**" \
  "$(remote_url "$SNAPSHOT")/" "$FETCH/"

[[ -f "$FETCH/MANIFEST" ]] || die "no MANIFEST in the snapshot — is $SNAPSHOT a backup directory?"
[[ -f "$FETCH/COMPLETE" ]] || die "$SNAPSHOT has no COMPLETE marker: it is a failed run, not a backup"

MANIFEST="$(cat "$FETCH/MANIFEST")"
printf '%s\n' "$MANIFEST" | sed 's/^/    /'
manifest_get() { printf '%s\n' "$MANIFEST" | sed -n "s/^$1=//p"; }

# Only the age format is restorable: snapshots from before it (clear or gpg) are not supported.
[[ "$(manifest_get encryption)" == "age" ]] \
  || die "$SNAPSHOT is not an age-encrypted snapshot — this script only restores those"
DUMP_FILE="$(manifest_get postgres_dump_file)"
SECRETS_FILE="$(manifest_get secrets_file)"
[[ -n "$DUMP_FILE" && -n "$SECRETS_FILE" ]] || die "MANIFEST does not name the dump and secrets files"

log "verifying checksums"
(cd "$FETCH" && sha256sum -c SHA256SUMS) || die "checksum mismatch — this snapshot is corrupt, try an older one"

# Decrypting the secrets (a few kilobytes) proves the key is the right one before anything else.
decrypt "$FETCH/$SECRETS_FILE" | tar -tzf - >/dev/null \
  || die "cannot decrypt $SECRETS_FILE with $BACKUP_AGE_IDENTITY — wrong key?"

# --- secrets ----------------------------------------------------------------

restore_secrets() {
  log "restoring $SECRETS_FILE (.env, data/keys, data/storage)"
  decrypt "$FETCH/$SECRETS_FILE" | tar -xzf - -C "$REPO_ROOT"
  chmod 600 "$REPO_ROOT/.env" "$REPO_ROOT"/data/keys/privateKey.pem \
    "$REPO_ROOT"/data/keys/fcm-service-account.json 2>/dev/null || true
  log "secrets restored — next: ./build.sh, then $0 --snapshot $SNAPSHOT"
}

if $SECRETS_ONLY; then
  if [[ -f "$REPO_ROOT/.env" ]] && ! $FORCE; then
    die ".env already exists — pass --force to overwrite it"
  fi
  restore_secrets
  exit 0
fi

require_vars ENV_NAME POSTGRES_DB

# A snapshot from another environment is usually a mistake (wrong checkout, wrong .env). It is also
# exactly what a restore drill does on purpose, so --force turns the refusal into a warning.
SNAP_ENV="$(manifest_get env_name)"
if [[ "$SNAP_ENV" != "$ENV_NAME" ]]; then
  $FORCE || die "snapshot is from '$SNAP_ENV', this checkout is '$ENV_NAME' — pass --force for a cross-environment drill"
  log "WARNING: restoring a '$SNAP_ENV' snapshot into '$ENV_NAME'"
fi

# age authenticates every chunk: a full pass to /dev/null proves the whole dump decrypts before the
# volumes are dropped, rather than half-way through pg_restore.
log "verifying that $DUMP_FILE decrypts"
decrypt "$FETCH/$DUMP_FILE" >/dev/null || die "cannot decrypt $DUMP_FILE — this snapshot is not restorable"

# --- full restore -----------------------------------------------------------

if ! $FORCE; then
  cat <<EOF

  This DESTROYS the current state of '$ENV_NAME':
    - postgres volume  (every account, ride, route, post)
    - minio volume     (every photo, GPX and preview)
  and replaces it with snapshot $SNAPSHOT.

EOF
  read -r -p "  Type the environment name to confirm: " answer
  [[ "$answer" == "$ENV_NAME" ]] || die "aborted"
fi

log "fetching minio objects"
mkdir -p "$FETCH/minio"
rsync_remote -a --delete --info=progress2 "$(remote_url "$SNAPSHOT")/minio/" "$FETCH/minio/"

# On a host the stack declares `pedalons-shared` as external and refuses to start until it exists.
# A workstation runs tileserver itself (docker-compose.local.yml) and needs no such thing.
if is_swarm; then
  docker network inspect pedalons-shared >/dev/null 2>&1 \
    || die "network pedalons-shared missing — deploy the shared stack first (scripts/deploy.sh --shared)"
fi

# Checked now, before anything is dropped: on a host deploy.sh runs the build of the checked-out
# commit (scripts/_image_tag.sh), a workstation the latest build under the alias.
tag="$ENV_NAME"
if is_swarm; then
  . "$SCRIPT_DIR/_image_tag.sh"
  ! worktree_dirty || die "uncommitted changes in $REPO_ROOT: deploy.sh would refuse to redeploy"
  tag="$ENV_NAME$(image_suffix)"
fi
for image in "pedalons-backend:$tag" "pedalons-frontend:$tag"; do
  docker image inspect "$image" >/dev/null 2>&1 \
    || die "image $image missing — run ./build.sh (MANIFEST commit: $(manifest_get git_commit))"
done

if is_swarm; then
  # `stack rm` returns once removal is requested, not once it is done: the volumes stay in use, and
  # the network half-exists, until every task has exited. Redeploying before that fails.
  log "removing stack $ENV_NAME and dropping its volumes"
  docker stack rm "$ENV_NAME" >/dev/null 2>&1 || true
  for _ in $(seq 1 90); do
    [[ -z "$(docker ps -aq --filter "label=com.docker.stack.namespace=$ENV_NAME")" ]] \
      && ! docker network inspect "${ENV_NAME}-net" >/dev/null 2>&1 \
      && break
    sleep 2
  done
  docker volume rm "${ENV_NAME}_postgres_data" "${ENV_NAME}_minio_data" >/dev/null 2>&1 || true
  for volume in "${ENV_NAME}_postgres_data" "${ENV_NAME}_minio_data"; do
    ! docker volume inspect "$volume" >/dev/null 2>&1 || die "volume $volume is still there — is a container still using it?"
  done

  # Swarm cannot start part of a stack, so the whole stack comes back — with backend and frontend at
  # zero replicas, or the backend would boot on the empty database, run Flyway and bootstrap a fresh
  # Domain before the dump lands.
  log "redeploying the stack on empty volumes, backend and frontend held at 0 replicas"
  "$SCRIPT_DIR/deploy.sh" --hold-app
else
  log "stopping the stack and dropping its volumes"
  docker compose down --remove-orphans -v

  log "starting postgres and minio on empty volumes"
  docker compose up -d postgres minio
fi

log "waiting for postgres to become healthy"
POSTGRES_CID=""
for _ in $(seq 1 60); do
  POSTGRES_CID="$(container_of postgres)"
  [[ -n "$POSTGRES_CID" && "$(docker inspect -f '{{.State.Health.Status}}' "$POSTGRES_CID" 2>/dev/null)" == "healthy" ]] && break
  sleep 2
done
[[ -n "$POSTGRES_CID" && "$(docker inspect -f '{{.State.Health.Status}}' "$POSTGRES_CID")" == "healthy" ]] \
  || die "postgres never became healthy — check its logs"

# --- postgres ---------------------------------------------------------------
#
# --clean --if-exists so the script also works against a database that was not wiped; --no-owner
# --no-acl because the dump's role names need not exist here.
# pg_restore is not run with --exit-on-error: a fresh database emits harmless "does not exist"
# notices for the DROPs, so the summary below is what matters.
# Decrypted in flight: the clear dump never lands on this disk.
log "restoring postgres into $POSTGRES_DB"
set +e
decrypt "$FETCH/$DUMP_FILE" | docker exec -i "$POSTGRES_CID" \
  sh -c 'pg_restore --clean --if-exists --no-owner --no-acl -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
PG_RC=$?
set -e
((PG_RC == 0)) || log "WARNING: pg_restore exited $PG_RC — read the errors above before continuing"

# GoatCounter's database is not backed up (docs/OPERATIONS.md, « Web analytics »): its role and an
# empty database are recreated, and GoatCounter, held at 0 by deploy.sh --hold-app, comes back on
# them. Nothing happens in an environment without it. Not on the site's path: a failure only warns.
"$SCRIPT_DIR/goatcounter-init.sh" db \
  || log "WARNING: goatcounter-init.sh db failed — rerun it once the restore is done"

# --- minio ------------------------------------------------------------------
#
# Restoring under a live MinIO would corrupt its on-disk index, so it goes down first.
# Never a write into /var/lib/docker/volumes: that needs root, and stamps the files with the restoring
# account's uid where MinIO, which runs as root, expects root:root.
if is_swarm; then
  # Swarm has no stop, only a scale to 0 that leaves no container to `docker cp` into. A throwaway
  # container mounts the volume instead; `cp -R` without -a, so the objects come out root:root.
  log "scaling minio to 0 to restore its data"
  docker service scale "${ENV_NAME}_minio=0" >/dev/null
  MINIO_VOLUME="${ENV_NAME}_minio_data"
  log "copying objects into the $MINIO_VOLUME volume"
  docker run --rm -v "$MINIO_VOLUME:/data" -v "$FETCH/minio:/restore:ro" alpine \
    sh -c 'cp -R /restore/. /data/'
  docker service scale "${ENV_NAME}_minio=1" >/dev/null

  log "scaling backend and frontend back up"
  docker service scale "${ENV_NAME}_backend=1" "${ENV_NAME}_frontend=1" >/dev/null
else
  # `docker cp` into the stopped container hands the files over as root:root.
  log "stopping minio to restore its data"
  docker compose stop minio
  log "copying objects into ${ENV_NAME}-minio:/data"
  docker cp "$FETCH/minio/." "${ENV_NAME}-minio:/data"
  docker compose start minio

  log "starting the full stack"
  docker compose up -d
fi

# --- verification -----------------------------------------------------------

log "waiting for the backend to answer"
HTTP_PORT="${HTTP_PORT:-8090}"
HOST_HEADER="${PEDALONS_BOOTSTRAP_DOMAIN:-localhost}"
STATUS=000
for _ in $(seq 1 60); do
  STATUS="$(curl -s -o /dev/null -w '%{http_code}' -H "Host: $HOST_HEADER" \
    "http://127.0.0.1:${HTTP_PORT}/api/config" || true)"
  [[ "$STATUS" == "200" ]] && break
  sleep 5
done

echo
log "restore summary"
docker exec "$POSTGRES_CID" sh -c \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT (SELECT count(*) FROM domains), (SELECT count(*) FROM users), (SELECT count(*) FROM teams), (SELECT count(*) FROM assets)"' \
  | awk -F'|' '{printf "    domains=%s users=%s teams=%s assets=%s\n", $1, $2, $3, $4}'
# Counted on the fetched copy, not inside the container: the minio image ships no `find`, and the
# failure is silent — `wc -l` of an empty error stream reports a confident 0 objects.
printf '    minio objects=%s\n' "$(find "$FETCH/minio" -type f -not -path '*/.minio.sys/*' | wc -l)"
printf '    GET /api/config (Host: %s) -> %s\n' "$HOST_HEADER" "$STATUS"
echo

$KEEP_FETCH || rm -rf "$FETCH"

[[ "$STATUS" == "200" ]] \
  || die "the backend does not answer 200 on /api/config — check the backend logs"

log "restore complete. Open the site and check that an existing photo still renders: that path goes"
log "through minio -> imgproxy -> varnish, so it is what proves the objects came back, not just the rows."
if [[ -n "${GOATCOUNTER_VHOST:-}" ]]; then
  log "GoatCounter's site and account went with its database: recreate them, from a terminal, with"
  log "scripts/goatcounter-init.sh site — until then /count refuses every hit, which is harmless."
fi
