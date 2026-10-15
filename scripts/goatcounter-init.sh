#!/usr/bin/env bash
# GoatCounter's database, site and account, for this checkout's environment (docs/OPERATIONS.md,
# « Web analytics »; docs/plans/2026-10-15-web-analytics.md §3.2).
#
#   scripts/goatcounter-init.sh db         the `goatcounter` role and database, then GoatCounter
#                                          (re)started on them and migrated. No prompt: restore.sh
#                                          runs it after pg_restore
#   scripts/goatcounter-init.sh site       the site and its dashboard account (password prompted),
#                                          then the collection and retention settings, by SQL — all
#                                          with GoatCounter stopped, so no hit is counted meanwhile
#   scripts/goatcounter-init.sh password   a new password for that account (prompted)
#
# Every subcommand is idempotent, and does nothing in an environment without GoatCounter (an empty
# GOATCOUNTER_VHOST: staging, the e2e stack, a workstation by default) — which lets restore.sh call
# `db` unconditionally. Swarm stack on a host, compose project on a workstation: the containers are
# found the same way as by the backup scripts.
#
# No secret ever goes on a command line, where `ps` shows it: the SQL goes through psql's standard
# input, the account's password through the prompt or the environment of `docker exec`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_backup_common.sh
. "$SCRIPT_DIR/_backup_common.sh"

# The settings `site` enforces (§3.5 of the plan). collect is a bit mask: Referrer 2, User-Agent 4,
# Size 8, Country 16. Off: Sessions 128 — on, GoatCounter writes "<user agent>-<IP>-<site>" in clear
# into its `store` table on every shutdown —, Region 32, Language 64, Individual pageviews 256 (a row
# per pageview). A new site starts at 190, sessions on. data_retention is in days: 24 months.
COLLECT=30
DATA_RETENTION=730
READY_TIMEOUT="${READY_TIMEOUT:-180}"

cmd="${1:-}"
case "$cmd" in
  db | site | password) ;;
  -h | --help | "") sed -n '2,18p' "$0"; [[ -n "$cmd" ]]; exit ;;
  *) die "unknown subcommand: $cmd (try --help)" ;;
esac

cd "$REPO_ROOT"
[[ -f .env ]] || die "no .env in $REPO_ROOT"
# Not load_env: the backup configuration has no business here.
set -a
. ./.env
set +a
require_vars ENV_NAME

if [[ -z "${GOATCOUNTER_VHOST:-}" ]]; then
  log "GOATCOUNTER_VHOST is empty: ${ENV_NAME} runs no GoatCounter, nothing to do"
  exit 0
fi
# Both end up inside SQL: no quoting to get wrong if they cannot hold a quote.
[[ "$GOATCOUNTER_VHOST" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]] \
  || die "GOATCOUNTER_VHOST must be a lowercase hostname, got '$GOATCOUNTER_VHOST'"
[[ "${GOATCOUNTER_DB_PASSWORD:-}" =~ ^[0-9a-f]{32,}$ ]] \
  || die "GOATCOUNTER_DB_PASSWORD must be hex, at least 32 digits (openssl rand -hex 24)"

SERVICE="${ENV_NAME}_goatcounter"

# SQL from standard input, as the superuser, into database $1. Unaligned rows on stdout. $PG is
# the postgres container, looked up before the first call.
psql_in() {
  docker exec -i "$PG" \
    sh -c 'psql -X -q -tA -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$1"' psql "$1"
}

# Start GoatCounter — or restart it, with --force — and wait for it to be serving on a migrated
# database: the "GoatCounter ready" line comes after the migrations. /status would not do, it answers
# 200 without a database. Prints the container's id.
start_goatcounter() {
  local since cid deadline
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if is_swarm; then
    docker service inspect "$SERVICE" >/dev/null 2>&1 \
      || die "no service $SERVICE — deploy the stack first (scripts/deploy.sh)"
    if [[ "${1:-}" == "--force" ]]; then
      docker service update --detach --force --replicas 1 "$SERVICE" >/dev/null
    else
      docker service scale --detach "$SERVICE=1" >/dev/null
    fi
  elif [[ "${1:-}" == "--force" ]]; then
    docker compose up -d --force-recreate goatcounter >&2
  else
    docker compose up -d goatcounter >&2
  fi
  log "waiting for GoatCounter to be ready (up to ${READY_TIMEOUT}s)" >&2
  deadline=$((SECONDS + READY_TIMEOUT))
  while ((SECONDS < deadline)); do
    cid="$(container_of goatcounter)"
    if [[ -n "$cid" ]] && docker logs --since "$since" "$cid" 2>&1 | grep -q 'GoatCounter ready'; then
      printf '%s' "$cid"
      return 0
    fi
    sleep 3
  done
  die "GoatCounter not ready after ${READY_TIMEOUT}s — see: docker logs \$(docker ps -qf name=goatcounter)"
}

# Stop GoatCounter and wait until its container is gone: it writes its in-memory state to the
# database on the way out, and the SQL that follows must come after that.
stop_goatcounter() {
  if is_swarm; then
    docker service scale --detach "$SERVICE=0" >/dev/null
    local deadline=$((SECONDS + 60))
    while [[ -n "$(container_of goatcounter)" ]]; do
      ((SECONDS < deadline)) || die "GoatCounter still running 60s after being scaled to 0"
      sleep 2
    done
  else
    docker compose stop goatcounter
  fi
}

case "$cmd" in
  db)
    PG="$(require_container postgres)"
    # CREATE DATABASE cannot run in a DO block or a transaction, hence \gexec. The role's password is
    # set again on every run, so a password changed in .env follows on the next `db`.
    log "creating the goatcounter role and database if missing"
    # A failed statement is logged by postgres with its text, password included, and its log goes
    # to Loki: not for this session.
    psql_in postgres <<SQL
set log_min_error_statement = panic;
do \$\$
begin
  if not exists (select from pg_roles where rolname = 'goatcounter') then
    create role goatcounter login password '${GOATCOUNTER_DB_PASSWORD}';
  else
    alter role goatcounter login password '${GOATCOUNTER_DB_PASSWORD}';
  end if;
end
\$\$;
select 'create database goatcounter owner goatcounter'
where not exists (select from pg_database where datname = 'goatcounter')
\gexec
SQL
    # Restarted rather than only scaled: one already up keeps failing on a role it tried before, and
    # one started earlier by hand would not migrate the database just created.
    start_goatcounter --force >/dev/null
    log "GoatCounter is ready on its database"
    if [[ "$(printf "select count(*) from sites where lower(cname) = '%s'" "$GOATCOUNTER_VHOST" | psql_in goatcounter)" == "0" ]]; then
      log "no site yet — next, interactively: scripts/goatcounter-init.sh site"
    fi
    ;;

  site)
    require_vars GOATCOUNTER_ADMIN_EMAIL
    PG="$(require_container postgres)"
    cid="$(require_container goatcounter)"
    docker exec "$cid" goatcounter db test >/dev/null 2>&1 \
      || die "GoatCounter has no database yet — run scripts/goatcounter-init.sh db first"
    exists="$(printf "select count(*) from sites where lower(cname) = '%s'" "$GOATCOUNTER_VHOST" | psql_in goatcounter)"
    [[ "$exists" != "0" || -t 0 ]] \
      || die "the account's password is asked at the prompt: run this from a terminal"
    image="$(docker inspect -f '{{.Config.Image}}' "$cid")"

    # GoatCounter caches its settings and reads them at start: stopped, written, started. Stopped
    # before the site exists, too: a new site is born with sessions and region on (collect=190), and
    # a GoatCounter serving /count meanwhile — live hits after a restore, PEDALONS_ANALYTICS_COUNT_PATH
    # still set — would count them that way, region rows kept for 24 months.
    log "stopping GoatCounter before touching the site's settings"
    stop_goatcounter
    if [[ "$exists" == "0" ]]; then
      log "creating site $GOATCOUNTER_VHOST and the account $GOATCOUNTER_ADMIN_EMAIL"
      # A one-off container of the same image, in the postgres container's network namespace —
      # the stack's overlay network is not attachable — so postgres is 127.0.0.1. Same DSN as the
      # service otherwise, the password by PGPASSWORD. No -user.password: GoatCounter asks for it,
      # hence -it.
      if ! PGPASSWORD="$GOATCOUNTER_DB_PASSWORD" docker run --rm -it --network "container:$PG" \
        -e GOATCOUNTER_DB="postgresql+host=127.0.0.1 dbname=goatcounter user=goatcounter sslmode=disable" \
        -e PGPASSWORD "$image" db create site \
        -vhost "$GOATCOUNTER_VHOST" -user.email "$GOATCOUNTER_ADMIN_EMAIL"; then
        # No site was created: GoatCounter goes back as it was, refusing hits, and `site` can rerun.
        start_goatcounter >/dev/null
        die "the site was not created — run scripts/goatcounter-init.sh site again"
      fi
    else
      log "site $GOATCOUNTER_VHOST exists, settings only"
    fi

    # The site's settings, and the sessions a shutdown with sessions on wrote.
    log "setting collect=$COLLECT, data_retention=$DATA_RETENTION"
    psql_in goatcounter <<SQL
update sites
set settings = jsonb_set(jsonb_set(settings, '{collect}', '${COLLECT}'), '{data_retention}', '${DATA_RETENTION}')
where lower(cname) = '${GOATCOUNTER_VHOST}';
delete from store where key = 'session';
SQL
    start_goatcounter >/dev/null

    got="$(psql_in goatcounter <<SQL
select settings->>'collect', settings->>'data_retention' from sites where lower(cname) = '${GOATCOUNTER_VHOST}';
SQL
)"
    [[ "$got" == "$COLLECT|$DATA_RETENTION" ]] \
      || die "the site's settings read back as collect|data_retention = '$got', not '$COLLECT|$DATA_RETENTION'"
    log "site $GOATCOUNTER_VHOST: collect=$COLLECT, data_retention=$DATA_RETENTION"
    log "check Settings in the dashboard: Sessions, Region, Language and Individual pageviews unchecked"
    ;;

  password)
    require_vars GOATCOUNTER_ADMIN_EMAIL
    [[ -t 0 ]] || die "the password is asked at the prompt: run this from a terminal"
    cid="$(require_container goatcounter)"
    read -r -s -p "New password for $GOATCOUNTER_ADMIN_EMAIL (8 to 50 bytes): " pw1 && echo
    read -r -s -p "Again: " pw2 && echo
    [[ "$pw1" == "$pw2" ]] || die "the two passwords differ"
    # `db update user -password <value>` takes it as given, without a prompt — on the command line.
    # GoatCounter reads every flag from GOATCOUNTER_<FLAG> too: -e NAME, without a value, hands it
    # over from this process's environment.
    GOATCOUNTER_PASSWORD="$pw1" docker exec -e GOATCOUNTER_PASSWORD "$cid" \
      goatcounter db update user -find "$GOATCOUNTER_ADMIN_EMAIL"
    log "password of $GOATCOUNTER_ADMIN_EMAIL changed"
    ;;
esac
