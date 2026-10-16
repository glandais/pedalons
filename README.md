# Pedalons - Cycling Team Management Platform

Multi-tenant web platform for cycling teams to organize rides, trips, manage GPX routes with interactive maps, and communicate.

| Module | Stack | Read |
|---|---|---|
| `backend/` | Java 25, Quarkus 3.39.x, PostgreSQL 17 + PostGIS | [backend/README.md](backend/README.md) |
| `frontend/` | TypeScript 7 (tsgo), React 19, Vite 8, Mantine UI 9, server-side rendered | [frontend/README.md](frontend/README.md) |
| `mobile/` | Flutter, Dart, Riverpod 3 | [mobile/README.md](mobile/README.md) |
| `karoo/` | Kotlin, Jetpack Compose, ktor-client-karoo | [karoo/README.md](karoo/README.md) |
| `garmin-app/` | Monkey C, Connect IQ SDK | [garmin-app/README.md](garmin-app/README.md) |

The API is OpenAPI 3.1, contract-first: the backend build writes `contracts/openapi.yaml` and
`openapi.json`, and the clients are generated from them.

## Quick Start

The usual workstation runs the backing services in Docker and the backend and frontend from source.

**Prerequisites**: Docker 24+ with Compose 2.20+, Java 25+ and Maven 3.9+, Node.js (version in
`frontend/.nvmrc`) and pnpm (pinned by `packageManager` in `frontend/package.json` — `corepack enable`
honours it), openssl,
[mkcert](https://github.com/FiloSottile/mkcert).

### 1. Clone and write the `.env`

```bash
git clone git@github.com:glandais/pedalons.git tribly
cd tribly
cp .env.example .env
```

Then, in `.env`:

- **uncomment the workstation block at the bottom** (`ENV_NAME=tribly-local`, `COMPOSE_FILE`, the
  mailpit `QUARKUS_MAILER_*`) — it is what makes this checkout a workstation, and it is not optional:
  see [below](#the-env-on-a-workstation-and-on-a-server);
- **replace every `########`**: `POSTGRES_PASSWORD`, `MINIO_ROOT_PASSWORD` and `MINIO_SECRET_KEY`
  (**equal** — the second is how the backend logs into the first), `ENCRYPTION_KEY`
  (`openssl rand -base64 32`; change it later and the stored GPS-service tokens stop decrypting),
  `PEDALONS_BOOTSTRAP_ADMIN_EMAIL` and `_DISPLAY_NAME` (any value: they only matter to the
  [full stack](#running-the-full-stack-locally)).

Everything else has a working default.

### 2. Start the backing services

```bash
docker compose up -d   # postgres, MinIO, imgproxy, varnish, valhalla, tileserver, mailpit
```

The first start of valhalla builds its routing tiles (France by default, `VALHALLA_TILE_URLS`) and
takes a long while; the rest is up in seconds. Mail, whatever its recipient, lands in mailpit:
http://127.0.0.1:8025.

### 3. Start the backend

```bash
cd backend
./generate-keys.sh             # once: the dev/test JWT key pair, in backend/keys/
source ../scripts/dev-env.sh   # the stack's postgres + MinIO credentials, nothing else
mvn quarkus:dev                # http://localhost:8080/api, Swagger UI on /q/swagger-ui
```

The ports it talks to, why `dev-env.sh` exports so little, and how to log in as the dev admin are in
[backend/README.md](backend/README.md#getting-started).

### 4. Start the frontend

```bash
cd frontend
mkcert -install && mkcert localhost 127.0.0.1 <your LAN IP>   # once, see below
echo 'VITE_API_TARGET=http://localhost:8080' >> .env          # else /api goes to staging
pnpm install
pnpm dev                                                      # https://localhost:5173
```

Without the certificates Vite falls back to plain HTTP: the site loads, but passkeys and emailed
links (both built on `https://localhost:5173`) don't work. Without `VITE_API_TARGET` the dev server
proxies to `https://staging.pedalons.fr`, which is all front-end work needs. Details:
[frontend/README.md](frontend/README.md#https-setup-required-for-webauthnpasskeys).

### The `.env`, on a workstation and on a server

There is **one** `.env`, never committed, and one template for both uses. Compose reads it on a
workstation, `scripts/deploy.sh` on a host, and `docker-compose.yml` hands the whole file to the
backend container through `env_file` — which is why anything that has no business inside the
application has no business in it either (the `BACKUP_*` settings live in
`/root/pedalons-backup.env`, see [Backup and restore](docs/OPERATIONS.md#backup-and-restore)).

A workstation and a deployment differ in five keys, and only those:

| Key | Deployment | Workstation |
|---|---|---|
| `ENV_NAME` | `pedalons-prod`, `pedalons-staging` | `tribly-local` |
| `COMPOSE_FILE` | *unset* — `docker-compose.yml` alone | `docker-compose.yml:docker-compose.local.yml` |
| `QUARKUS_MAILER_*` | the Scaleway TEM SMTP relay | `mailpit` / `1025`, TLS and login `DISABLED` |
| `PEDALONS_BOOTSTRAP_DOMAIN` / `_BASE_URL` | the public hostname, `https://…` | `localhost` / `http://localhost:8090` (full stack only) |
| `HTTP_PORT` | 8090 prod, 8089 staging, behind Caddy | anything free |

- **`ENV_NAME` names the stack** — containers, network, image tags, and the postgres and minio the
  backup scripts look up. A local stack called `…-prod` is indistinguishable from the real one in
  `docker ps` and to `scripts/restore.sh`.
- **A local stack must not be able to send mail.** The containers run the `%prod` Quarkus profile
  wherever they run, and its only way out for mail is the relay named by `QUARKUS_MAILER_*`. After a
  biketeam migration the local database holds thousands of real member addresses, and one OTP or
  team invitation is enough to reach them.
- **`COMPOSE_FILE` adds the workstation overlay**, `docker-compose.local.yml`: mailpit, the valhalla
  and tileserver a host gets from its shared stack, the loopback ports dev mode talks to, and an
  `app` profile on `backend`/`frontend`/`traefik` so that a plain `docker compose up -d` starts the
  backing services alone. A deployed `.env` has no `COMPOSE_FILE`, which is why the overlay is a
  separate file rather than a profile. Its header comment lists what it changes.

## Running the full stack locally

The same `docker-compose.yml`, run from the built images — for testing a build. It needs the
production JWT key pair, which `docker-compose.yml` mounts from `data/keys/`:

```bash
data/keys/generate-keys.sh   # once
./build.sh && docker compose --profile app up -d
```

The site is then on `http://localhost:${HTTP_PORT}`, and its bootstrap domain is the `.env`'s
`PEDALONS_BOOTSTRAP_*`, not the `%dev` one: set them to `localhost` / `http://localhost:8090` (see
the table above). `--profile app` is what pulls in `backend`, `frontend` and `traefik`; put
`COMPOSE_PROFILES=app` in the `.env` if this machine mostly runs the full stack.

A workstation stays on plain `docker compose`, not Swarm, and runs no separate shared stack: the
overlay turns traefik back to the Docker provider, binds it to the loopback, and declares the
`shared` network as an ordinary project network. Nothing to start beforehand.

## Default domain and platform admin

Every request finds its tenant from the `Host` header. On startup the backend creates a default
`Domain` and a `PLATFORM_ADMIN` `User` if they don't yet exist (idempotent — see
`BootstrapService`), from `pedalons.bootstrap.*`:

| Variable | `%dev` value | Elsewhere |
|----------|---------|---|
| `PEDALONS_BOOTSTRAP_ENABLED` | `true` | `true` |
| `PEDALONS_BOOTSTRAP_DOMAIN` | `localhost` | required in `.env` |
| `PEDALONS_BOOTSTRAP_DOMAIN_NAME` | `Pedalons Dev` | required in `.env` |
| `PEDALONS_BOOTSTRAP_BASE_URL` | `https://localhost:5173` | required in `.env` |
| `PEDALONS_BOOTSTRAP_ADMIN_EMAIL` / `_DISPLAY_NAME` | `%dev.pedalons.bootstrap.admin-*` in `application.properties` | required in `.env` |

The values are read once, when the row is created; later edits go through the admin UI. The admin
has no password — first login is by OTP (in mailpit, on a workstation) or passkey.

Browsing through a *second* hostname — a LAN IP, to test the site from a phone — needs its own
`domains` row. From a [`psql` prompt](#running-sql):

```sql
INSERT INTO domains (id, domain, name, base_url, single_team, active, deleted, created_at, updated_at, version)
VALUES (
    (EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT * 1000000 + (RANDOM() * 999999)::INT,
    '192.168.50.20',               -- domain: matched against Host / X-Forwarded-Host
    'Pedalons',                    -- name: shown in emails, the UI, WebAuthn prompts
    'https://192.168.50.20:5173',  -- base_url: prefix of email and calendar links
    false,                         -- single_team: if true, the domain has only one team
    true,                          -- active
    false,                         -- deleted
    NOW(), NOW(), 0
);
```

A known host answers `curl -s -H 'Host: 192.168.50.20' http://localhost:8080/api/config` with
`200`, an unknown one with `404 DOMAIN_NOT_FOUND`.

## Development

| Task | Command |
|---|---|
| Format every module (or one: `backend`, `frontend`, `mobile`, `karoo`, `garmin-app`) | `./format.sh [module]` |
| Full local gate, mirroring CI (backend tests only with `--backend-tests`) | `./check.sh` |
| Regenerate the API contract, then the clients | `mvn package -DskipTests` in `backend/`, `pnpm generate-api` in `frontend/` |
| Regenerate UI route paths, AASA, Android deeplinks from `contracts/routes.yaml` ([docs/APP_LINKS.md](docs/APP_LINKS.md)) | `pnpm generate-routes` in `frontend/` |
| Regenerate the business colour tables from `contracts/brand-colors.yaml` ([docs/BRANDING.md](docs/BRANDING.md)) | `pnpm generate-brand-colors` in `frontend/` |

`format.sh` fails loudly when a toolchain is missing rather than skipping the module. Run it before
committing, and include its output in the commit. Each module's tests, lint and build commands are
in its own README.

## Project Structure

```
tribly/
├── backend/  frontend/  mobile/  karoo/  garmin-app/   # see the table above
├── contracts/        # OpenAPI specification, UI routes (routes.yaml), brand colours
├── services/         # Docker service configs (Varnish, monitoring)
├── scripts/          # dev-env, deploy, backup/restore, e2e, code generation
├── docs/             # Ledgers (LEDGER_NEXT.md), plans, the operations runbook
├── privacy/          # Privacy policy, terms and support pages (served by the site, bundled in the app)
├── assets/           # Logo and icon sources (see docs/BRANDING.md)
├── data/             # Runtime data of the stack (keys, storage, cache, valhalla, tileserver)
├── docker-compose.yml         # One deployed environment (prod, staging, ...): a Swarm stack
├── docker-compose.local.yml   # Workstation overlay. Never deployed
├── docker-compose.e2e.yml     # End-to-end test stack (scripts/e2e.sh)
└── docker-compose.shared.yml  # Services shared by every environment on a host
```

## Running SQL

One PostgreSQL container per environment. Read its credentials from the container's own
environment, which keeps them out of your shell history. On a workstation it is
`${ENV_NAME}-postgres`; on a host it is a Swarm task, with no fixed name, so look it up by its
service:

```bash
PG="${ENV_NAME}-postgres"                                                                 # workstation
PG="$(docker ps -q --filter "label=com.docker.swarm.service.name=${ENV_NAME}_postgres")"  # host

docker exec -it "$PG" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
docker exec "$PG" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "SELECT domain, name, active FROM domains;"'
```

A workstation also publishes `127.0.0.1:${POSTGRES_HOST_PORT:-5432}`, so any SQL client of yours
can connect with the `.env` credentials; the stack ships none. A host publishes nothing (see
[Only Caddy may reach traefik](docs/OPERATIONS.md#only-caddy-may-reach-traefik)).

Use `-v ON_ERROR_STOP=1` for anything that writes: without it `psql` reports the error and carries
on, so a failed script looks like it succeeded. And on tables backing a JPA entity, maintain the two
columns Hibernate otherwise manages:

- `updated_at` — set it to `NOW()` on every UPDATE;
- `version` — optimistic locking: **increment it on every UPDATE**, or an entity already loaded in
  memory can silently overwrite your change the next time it is persisted.

IDs are TSIDs (`bigint`), not sequences: generate one inline with
`(EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT * 1000000 + (RANDOM() * 999999)::INT`.

## Deployment and operations

A host runs one shared stack (`docker-compose.shared.yml`: valhalla and tileserver, on the
`pedalons-shared` network) plus one `docker-compose.yml` stack per environment, behind Caddy.
Production is backed up nightly by `scripts/backup.sh`, and `scripts/restore.sh` brings an
environment back from a snapshot.

The runbook — deployment, access-log redaction, seeding the shared Valhalla data, network changes,
backup configuration and restore — is in **[docs/OPERATIONS.md](docs/OPERATIONS.md)**. Read its
[Deployment](docs/OPERATIONS.md#deployment) section before touching networks or the compose files.

### Bootstrapping a new deployment

A brand-new database needs no SQL: the backend creates the domain and the platform admin named by
the `.env`'s `PEDALONS_BOOTSTRAP_*` (see [Default domain and platform admin](#default-domain-and-platform-admin)).
Log in as that admin (OTP or passkey) and use the admin UI (`/admin`: dashboard, domains, teams,
users) for everything after.

With bootstrapping disabled (`PEDALONS_BOOTSTRAP_ENABLED=false`) you need a domain before you can
register a user, and a user before anyone can be an admin. Break the cycle with SQL, once:

1. **Create the domain** — the `INSERT` [above](#default-domain-and-platform-admin), with your
   hostname and `https://` base URL.
2. **Register a user** through the normal signup flow. This sends a verification email, so the
   mailer must work: Scaleway TEM refuses a `FROM` whose domain is not verified (SPF, DKIM, MX) and
   credentials that are not a project id + IAM secret key with `TransactionalEmailEmailFullAccess`.
   A refused message surfaces as a 500 on `/api/auth/register`, with the SMTP reply in the backend
   log.
3. **Grant the platform admin role**:

   ```sql
   UPDATE users
      SET platform_role = 'PLATFORM_ADMIN',
          updated_at    = NOW(),
          version       = COALESCE(version, 0) + 1
    WHERE email = 'your-email@example.com'
      AND deleted = false;
   ```

   No re-login is needed: the role is not in the JWT, `AdminInterceptor` reads it from the database
   on every request. It lives on `users`, which is scoped by `domain_id`: despite the name, you are
   an admin *of that domain* — a second domain needs a fresh account and a fresh `UPDATE`.

## Features

### GPS Device Integration

Users connect Hammerhead Karoo, Garmin (via Garmin Connect) and Wahoo ELEMNT (via the Wahoo Cloud
account) from Profile > Devices and services (`/profile/devices`), by OAuth on the service's own
site (with PKCE for Garmin); "Send to Device" on a route then uploads it. A service is offered only
once its OAuth client id and secret are entered in the platform admin's domain form, and the tokens
are encrypted with `ENCRYPTION_KEY`.

The device code flow (QR code or URL) is something else: it signs in the Karoo extension and the
Garmin Connect IQ app themselves — see [karoo/](karoo/) and [garmin-app/](garmin-app/).

### Team Governance

Platform admins control the following per-team attributes (configurable via the team admin page):

| Attribute | Description |
|-----------|-------------|
| `visibilityEditable` | If `true`, team admins can change visibility. If `false`, only platform admins can. |
| `joinable` | If `true` and the team is public, any domain user can self-join. |
| `addMemberAllowed` | If `true`, team admins can add members directly. If `false`, only platform admins can. |

A team created by a user starts with `visibility` `TEAM` (enforced by the backend) and the three
attributes above `false`. A non-platform-admin user can create at most one team per domain.
