# Pedalons - Cycling Team Management Platform

Multi-tenant web platform for cycling teams to organize rides, trips, manage GPX routes with interactive maps, and communicate.

## Tech Stack

- **Backend**: Java 25, Quarkus 3.39.x, PostgreSQL 17 with PostGIS
- **Frontend**: TypeScript 7 (tsgo), React 19, Vite 8, Mantine UI 9
- **Mobile**: Flutter, Dart, Riverpod 3
- **Karoo**: Kotlin, Jetpack Compose, ktor-client-karoo
- **Garmin**: Monkey C, Connect IQ SDK
- **API**: OpenAPI 3.1 contract-driven development
- **Testing**: JUnit 5, REST Assured, Vitest, Playwright (web e2e), Patrol (mobile e2e)

## Quick Start

### Prerequisites

- Java 25+
- Maven 3.9+
- Node.js 22+ (Vite 8 requires ^20.19 or >=22.12)
- pnpm — the version is pinned by `packageManager` in `frontend/package.json`; `corepack enable` honours it
- Docker 24+
- Docker Compose 2.20+

### 1. Clone and Setup

```bash
git clone git@github.com:glandais/pedalons.git
cd tribly
cp .env.example .env
```

### The `.env`, on a workstation and on a server

There is **one** `.env`, never committed, and one template for both uses. Compose reads it on a
workstation, `scripts/deploy.sh` on a host, and `docker-compose.yml` hands the whole file to the
backend container through `env_file` — which is why
anything that has no business inside the application has no business in it either (the `BACKUP_*`
settings live in `/root/pedalons-backup.env` instead, see [Backup and restore](docs/OPERATIONS.md#backup-and-restore)).

A workstation and a deployment differ in five keys, and only those:

| Key | Deployment | Workstation |
|---|---|---|
| `ENV_NAME` | `pedalons-prod`, `pedalons-staging` | `tribly-local` |
| `COMPOSE_FILE` | *unset* — `docker-compose.yml` alone | `docker-compose.yml:docker-compose.local.yml` |
| `QUARKUS_MAILER_*` | the Scaleway TEM SMTP relay | `mailpit` / `1025`, TLS and login `DISABLED` |
| `PEDALONS_BOOTSTRAP_DOMAIN` / `_BASE_URL` | the public hostname, `https://…` | `localhost` / `http://localhost:8090` |
| `HTTP_PORT` | 8090 prod, 8089 staging, behind Caddy | anything free |

Two of those are not a matter of taste. **`ENV_NAME` names the stack** — containers, network, image
tags, and the postgres and minio the backup scripts look up; a local stack called `…-prod` is
indistinguishable from the real one in `docker ps` and to `scripts/restore.sh`. And **a local stack
must not be able to send mail**, for reasons worth reading before the first `up`:
[Running the full stack locally](#running-the-full-stack-locally).

`COMPOSE_FILE` is what turns the checkout into a workstation. The overlay it adds carries mailpit,
the valhalla and tileserver a server instead gets from the shared stack, the loopback ports
`mvn quarkus:dev` and `pnpm dev` talk to, and an `app` profile on `backend`/`frontend`/`traefik` so a
plain `docker compose up -d` starts the backing services alone. `goatcounter` (the web analytics,
production only) sits behind an `analytics` profile that nothing enables. `source scripts/dev-env.sh` then
feeds this same file's `POSTGRES_*` / `MINIO_*` to the dev backend — no second set of credentials to
keep in sync.

**Fill in before the first `up`:**

| Key | |
|---|---|
| `POSTGRES_PASSWORD` | any value; the database is created with it on first start |
| `MINIO_ROOT_PASSWORD` and `MINIO_SECRET_KEY` | must be **equal** — the second is how the backend authenticates against the first. Same for `MINIO_ROOT_USER` / `MINIO_ACCESS_KEY` |
| `ENCRYPTION_KEY` | `openssl rand -base64 32`. Encrypts the stored GPS-service tokens: change it later and they stop decrypting |
| `PEDALONS_BOOTSTRAP_ADMIN_EMAIL` | your address. The account is created without a password; first login is by OTP or passkey |

**Everything else in `.env.example` has a working default**, so a workstation `.env` can be shorter
than the template: `PUID`/`PGID` (1000:1000), `POSTGRES_HOST_PORT` (5432), `FRONTEND_SOURCEMAP`
(false), `QUARKUS_MAILER_USERNAME`/`_PASSWORD` (unread when the login is
`DISABLED`), and `VALHALLA_TILE_URLS` — whose default builds France, and whose every change costs a
rebuild of several hours.

### 2. Install and configure mkcert

Vite serves HTTPS only when it finds `frontend/localhost+2.pem` and `frontend/localhost+2-key.pem`,
and falls back to plain HTTP otherwise. The `%dev` bootstrap domain's base URL is
`https://localhost:5173`, which is both the WebAuthn origin of dev passkeys and the prefix of the
links sent by email: skip the certificates and the site still loads, but passkeys and emailed links
don't work against it.

```bash
# Windows (chocolatey)
choco install mkcert

# Windows (scoop)
scoop install mkcert

# macOS
brew install mkcert
```

Install local CA (one time):

```bash
mkcert -install
```

Generate certificates in the frontend folder:

```bash
cd frontend
mkcert localhost 127.0.0.1 <your LAN IP>
# Creates localhost+2.pem and localhost+2-key.pem — Vite looks for exactly these names,
# so pass three hosts (the LAN IP is what a phone or the Garmin simulator browses with)
```


### 3. Start Infrastructure

```bash
# PostgreSQL, MinIO, imgproxy, varnish, valhalla, tileserver, mailpit
docker compose up -d

# Wait for PostgreSQL to be ready
docker compose exec postgres pg_isready -U "$POSTGRES_USER"
```

One stack serves both workflows. `docker-compose.yml` is the deployment file; the workstation
overlay `docker-compose.local.yml` adds mailpit, folds in the valhalla and tileserver of
`docker-compose.shared.yml`, and publishes on loopback the ports `mvn quarkus:dev` and `pnpm dev`
talk to — imgproxy on 38080, valhalla on 8002, tileserver on 18080, MinIO on 9000, SMTP on 1025.

The command above starts the backing services **only**: the overlay puts `backend`, `frontend` and
`traefik` behind an `app` profile, since in dev those three are what you are replacing. Add
`--profile app` (or `COMPOSE_PROFILES=app` in `.env`) to run the whole application from the built
images — see [Running the full stack locally](#running-the-full-stack-locally). A deployment reads
`docker-compose.yml` alone, where the three carry no profile and always start.

### 4. Start Backend

```bash
cd backend
source ../scripts/dev-env.sh   # postgres + MinIO credentials, from the same .env the stack reads
mvn quarkus:dev
```

`dev-env.sh` exports those five values and nothing else — on purpose. Quarkus reads environment
variables at a higher ordinal than `application.properties`, so sourcing the whole `.env` would
override the `%dev` bootstrap domain (`localhost`, which is the WebAuthn origin of dev passkeys)
with the stack's own. If the `.env` still holds the `.env.example` credentials, the `%dev` defaults
already match and the `source` is a no-op.

Backend available at:
- API: http://localhost:8080/api
- Swagger UI: http://localhost:8080/q/swagger-ui
- Health: http://localhost:8080/q/health

### Default domain and platform admin

#### Bootstrapping


On startup the backend creates a default `Domain` and a `PLATFORM_ADMIN` `User` if they don't yet
exist (idempotent — see `BootstrapService`). Defaults match the localhost dev setup; override via
environment variables for other environments:

| Variable | Default |
|----------|---------|
| `PEDALONS_BOOTSTRAP_ENABLED` | `true` |
| `PEDALONS_BOOTSTRAP_DOMAIN` | `localhost` |
| `PEDALONS_BOOTSTRAP_DOMAIN_NAME` | `Pedalons Dev` |
| `PEDALONS_BOOTSTRAP_BASE_URL` | `https://localhost:5173` |
| `PEDALONS_BOOTSTRAP_ADMIN_EMAIL` | `gabriel.landais@gmail.com` |
| `PEDALONS_BOOTSTRAP_ADMIN_DISPLAY_NAME` | `Gaby Landais` |

The admin is created with `password_hash = NULL` — first login is via OTP or passkey.

#### SQL

Bootstrapping covers the domain you configured; nothing else resolves. Every request finds its
tenant from the `Host` header, so browsing through a *second* hostname — a LAN IP, say — needs its
own `domains` row. Open a `psql` prompt on the dev database:

```bash
docker exec -it "${ENV_NAME}-postgres" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

Then insert a domain matching the host you browse the frontend with:

```sql
INSERT INTO domains (id, domain, name, base_url, single_team, active, deleted, created_at, updated_at, version)
VALUES (
    (EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT * 1000000 + (RANDOM() * 999999)::INT,
    '192.168.50.20',
    'Pedalons',
    'https://192.168.50.20:5173',
    false,
    true,
    false,
    NOW(),
    NOW(),
    0
);
```

See [Running SQL](#running-sql) for the deployed stack, and [Bootstrapping a new deployment](#bootstrapping-a-new-deployment) for what to do next.

### 5. Start Frontend

```bash
cd frontend
pnpm install
pnpm dev
```

Frontend available at https://localhost:5173

The dev server proxies `/api` to **staging** (`https://staging.pedalons.fr`) unless
`VITE_API_TARGET` says otherwise, so front-end work needs no local backend at all. Point it at the
one you just started to work against local data:

```bash
echo 'VITE_API_TARGET=http://localhost:8080' >> frontend/.env
```

## Project Structure

```
tribly/
├── backend/          # Quarkus backend (Java 25)
├── frontend/         # React 19 + Mantine UI, server-side rendered (see frontend/docs/SSR.md)
├── mobile/           # Flutter mobile app (iOS/Android)
├── karoo/            # Hammerhead Karoo extension (Kotlin/Compose)
├── garmin-app/       # Garmin Connect IQ app (Monkey C)
├── contracts/        # OpenAPI specification and UI routes (routes.yaml)
├── services/         # Docker service configs (Varnish)
├── scripts/          # Utility scripts (backup/restore, e2e, route generation, SSR audit)
├── docs/             # Plans, roadmap (LEDGER_NEXT.md) and the operations runbook
├── privacy/          # Privacy policy, terms and support pages (served by the site, bundled in the app)
├── assets/           # Logo and icon sources (see docs/BRANDING.md)
├── data/             # Runtime data (keys, storage, cache, valhalla, tileserver)
├── docker-compose.yml         # One deployed environment (prod, staging, ...): a Swarm stack
├── docker-compose.local.yml   # Workstation overlay: mailpit, the shared services, the
│                              #   loopback ports dev mode needs. Never deployed
├── docker-compose.e2e.yml     # End-to-end test stack (scripts/e2e.sh, .env.e2e)
└── docker-compose.shared.yml  # Services shared by every environment on the host
```

## Running the full stack locally

The same `docker-compose.yml`, on a workstation — for testing a build. A workstation stays on plain
`docker compose`, not Swarm: the overlay turns back what only Swarm wants — traefik's Docker provider
instead of the Swarm one, its port on the loopback, a bridge network instead of an overlay. Two
things must differ from a deployment, and both live in the local `.env`:

```bash
ENV_NAME=tribly-local
COMPOSE_FILE=docker-compose.yml:docker-compose.local.yml
QUARKUS_MAILER_HOST=mailpit       # + the rest of the block in .env.example
```

**`ENV_NAME` names the stack**: keep it `tribly-local` — why is in
[the `.env` section](#the-env-on-a-workstation-and-on-a-server).

**A local stack must not be able to send mail.** The containers run the `%prod` Quarkus profile
wherever they run, and its only way out for mail is the SMTP relay named by `QUARKUS_MAILER_*` —
Scaleway Transactional Email on a server. A workstation points it at the mailpit of
`docker-compose.local.yml` (UI on http://127.0.0.1:8025). This is not hygiene: after a biketeam
migration the local database holds thousands of real member addresses, and one OTP or team
invitation is enough to reach them.

`COMPOSE_FILE` makes a plain `docker compose` command pick up the overlay here and nowhere else. A
deployed `.env` has no `COMPOSE_FILE` and reads `docker-compose.yml` alone, which is why the overlay
is a separate file rather than a profile. What it adds: mailpit (http://127.0.0.1:8025); valhalla
and tileserver, `extends`-ed from `docker-compose.shared.yml`; and the loopback ports
[dev mode](#3-start-infrastructure) talks to.

**No shared stack on a workstation.** A host runs one for several environments; a laptop has one, so
the overlay pulls those two services into it and redeclares the `shared` network as an ordinary
project network (`${ENV_NAME}-shared`) instead of the `external` `pedalons-shared`. Nothing to start
beforehand:

```bash
cd ~/code/tribly && ./build.sh && docker compose --profile app up -d
```

`--profile app` is what pulls in `backend`, `frontend` and `traefik`; without it the overlay starts
the backing services alone, which is what [dev mode](#3-start-infrastructure) wants. Put
`COMPOSE_PROFILES=app` in the `.env` if this machine mostly runs the full stack.

## Deployment and operations

A host runs one shared stack (`docker-compose.shared.yml`: valhalla and tileserver, on the
`pedalons-shared` network) plus one `docker-compose.yml` stack per environment, behind Caddy.
Production is backed up nightly by `scripts/backup.sh` over a restricted `rrsync` channel, and
`scripts/restore.sh` brings an environment back from a snapshot.

The runbook — deployment, access-log redaction, seeding the shared Valhalla data, network changes,
backup configuration and restore — is in **[docs/OPERATIONS.md](docs/OPERATIONS.md)**. Read its
[Deployment](docs/OPERATIONS.md#deployment) section before touching networks or the compose files.

## Features

### GPS Device Integration

Users can connect GPS devices from their profile to upload routes directly to their devices.

**Supported devices:**
- Hammerhead Karoo
- Garmin Edge devices (via Garmin Connect)
- Wahoo ELEMNT (via the Wahoo Cloud account — no companion app, the head unit syncs from the cloud)

**Setup:**

- Set `ENCRYPTION_KEY` for secure token storage (required in production)
- Enter each service's OAuth client id and secret for the domain, in the platform admin's domain form
  — a service with no credentials is not offered

**Usage:**
1. Navigate to Profile > Devices and services (`/profile/devices`)
2. Click "Connect" next to your device
3. Authorize the application on the service's own site (OAuth redirect, with PKCE for Garmin)
4. On any route detail page, use "Send to Device" to upload routes

The device code flow (QR code or URL) is something else: it signs in the Karoo extension and the
Garmin Connect IQ app themselves — see [karoo/](karoo/) and [garmin-app/](garmin-app/).

## Development

### Generate API Client

```bash
cd frontend
pnpm generate-api
```

### Generate UI Route Paths

UI routes (per-locale URL templates, deeplinks, path builders) are declared in `contracts/routes.yaml`. Regenerate `paths.generated.ts` / `paths.generated.dart`, AASA and the AndroidManifest deeplink section with:

```bash
cd frontend
pnpm generate-routes
```

See [docs/APP_LINKS.md](docs/APP_LINKS.md) for the full workflow.

### Run Tests

```bash
# Backend
cd backend && mvn test

# Frontend
cd frontend && pnpm test
```

### Code Quality

```bash
# Format every module (Spotless, Prettier, dart format, ktfmt, prettier-plugin-monkeyc)
./format.sh
./format.sh mobile          # or one module: backend|frontend|mobile|karoo|garmin-app

# Backend linting
cd backend && mvn checkstyle:check

# Frontend linting
cd frontend && pnpm lint
```

`format.sh` fails loudly when a toolchain is missing rather than skipping the module. Run it before
committing, and include its output in the commit.

## Running SQL

One PostgreSQL container per environment. Its credentials come from `.env`, which is not versioned:
read them from the container's own environment, which keeps secrets out of your shell history. On a
workstation it is `${ENV_NAME}-postgres` (`tribly-local-postgres`); on a host it is a Swarm task,
with no fixed name and a new one after every restart, so look it up by its service:

```bash
PG="$(docker ps -q --filter "label=com.docker.swarm.service.name=${ENV_NAME}_postgres")"  # host
PG="${ENV_NAME}-postgres"                                                                 # workstation

# Interactive session
docker exec -it "$PG" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'

# One-off statement
docker exec "$PG" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "SELECT domain, name, active FROM domains;"'
```

On a workstation it also publishes `127.0.0.1:${POSTGRES_HOST_PORT:-5432}` — that is how
`mvn quarkus:dev` reaches it from the host, and how any client of yours can. A host publishes nothing
(see [Only Caddy may reach traefik](docs/OPERATIONS.md#only-caddy-may-reach-traefik)). **The stack ships no
SQL browser**: pick your own — psql, pgAdmin, DBeaver, the database panel of your IDE — and point it
at `localhost:5432` with the `.env` credentials. Nothing to declare in compose for that.

Use `-v ON_ERROR_STOP=1` for anything that writes: without it `psql` reports the error and carries on to the next statement, so a failed migration script looks like it succeeded.

### Writing to entity tables by hand

Tables backing a JPA entity carry two columns Hibernate manages for you, and hand-written SQL has to maintain them:

- `updated_at` — set it to `NOW()` on every UPDATE.
- `version` — optimistic locking. **Increment it on every UPDATE.** If you don't, an entity already loaded in memory can silently overwrite your change the next time it is persisted.

```sql
UPDATE users
   SET platform_role = 'PLATFORM_ADMIN',
       updated_at    = NOW(),
       version       = COALESCE(version, 0) + 1
 WHERE email = 'your-email@example.com'
   AND deleted = false;
```

IDs are TSIDs (`bigint`), not sequences. Generate one inline when inserting:

```sql
(EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT * 1000000 + (RANDOM() * 999999)::INT
```

## Multi-Tenancy

Pedalons is multi-tenant: each domain (hostname) has isolated teams and users. The domain is resolved from the `Host` or `X-Forwarded-Host` HTTP header.

### Bootstrapping a new deployment

Domains and platform admins are managed from the admin UI (`/admin`). A brand-new database reaches it without SQL: on startup the backend creates the domain and the platform admin named by `PEDALONS_BOOTSTRAP_*` (see [Bootstrapping](#bootstrapping)), which `docker-compose.yml` requires in `.env`. Log in as that admin (OTP or passkey) and use the UI for everything after.

The SQL route below is for when bootstrapping is disabled (`PEDALONS_BOOTSTRAP_ENABLED=false`): you need a domain before you can register a user, and a user before anyone can be an admin. Break the cycle with SQL, once.

**1. Create the first domain** (see [Running SQL](#running-sql) for how to get a `psql` prompt):

```sql
INSERT INTO domains (id, domain, name, base_url, single_team, active, deleted, created_at, updated_at, version)
VALUES (
    (EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT * 1000000 + (RANDOM() * 999999)::INT,
    'monclub.fr',                    -- domain: hostname used to access the site
    'Mon Club Cycliste',             -- name: displayed in emails, UI, WebAuthn prompts
    'https://monclub.fr',            -- base_url: full URL for email/calendar links
    false,                           -- single_team: if true, domain has only one team
    true,                            -- active
    false,                           -- deleted
    NOW(),
    NOW(),
    0
);
```

| Field | Description |
|-------|-------------|
| `domain` | HTTP hostname (matched against `Host`/`X-Forwarded-Host` header) |
| `name` | App name shown in emails, WebAuthn prompts, and UI |
| `base_url` | Full URL with protocol, used in email links and calendar feeds |

Verify the backend resolves it — a known host returns `200`, an unknown one `404 DOMAIN_NOT_FOUND`:

```bash
curl -s -H 'Host: monclub.fr' http://localhost:8080/api/config
```

**2. Register a user** through the normal signup flow. This sends a verification email, so the mailer must work: in `prod` the backend sends through the Scaleway Transactional Email SMTP relay, which refuses a `FROM` whose domain is not verified in TEM (SPF, DKIM, MX) and credentials that are not a project id + IAM secret key with `TransactionalEmailEmailFullAccess`. A refused message surfaces as a 500 on `/api/auth/register`; the backend log carries the SMTP reply.

**3. Grant the platform admin role** via SQL:

```sql
UPDATE users
   SET platform_role = 'PLATFORM_ADMIN',
       updated_at    = NOW(),
       version       = COALESCE(version, 0) + 1
 WHERE email = 'your-email@example.com'
   AND deleted = false;
```

`platform_role` is constrained to `PLATFORM_ADMIN` or `NULL` — it is the only role in the `PlatformRole` enum. No re-login is needed: the role is not carried in the JWT, `AdminInterceptor` reads it from the database on every request.

The role lives on `users`, a table scoped by `domain_id`. You are therefore an admin *of that domain*, despite the "platform admin" name — add a second domain and you'll need a fresh account and a fresh `UPDATE` there.

### Using the admin interface

Once you are a platform admin, the "Admin" link appears in the header menu, providing access to:

- **Dashboard**: Platform statistics
- **Domains**: Manage domains (create, edit, activate/deactivate)
- **Teams**: View all teams, archive/restore
- **Users**: View all users, grant/revoke platform admin role

## Team Governance

Platform admins control the following per-team attributes (configurable via the team admin page):

| Attribute | Description |
|-----------|-------------|
| `visibilityEditable` | If `true`, team admins can change visibility. If `false`, only platform admins can. |
| `joinable` | If `true` and the team is public, any domain user can self-join. |
| `addMemberAllowed` | If `true`, team admins can add members directly. If `false`, only platform admins can. |

When a user creates a team, defaults are:
- `visibility`: `TEAM` (enforced by the backend)
- `visibilityEditable`: `false`
- `joinable`: `false`
- `addMemberAllowed`: `false`

A non-platform-admin user can create at most one team per domain.

## Garmin Connect IQ App Development

The Garmin app (`garmin-app/`) allows users to browse and download routes directly to their Garmin devices. See README inside `garmin-app/` folder
