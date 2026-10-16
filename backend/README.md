# Pedalons Backend

Quarkus REST API backend for the Pedalons cycling team management platform.

## Tech Stack

- **Runtime**: Java 25, Quarkus 3.39.x
- **Database**: PostgreSQL 17 + PostGIS (Hibernate Spatial, Panache, Flyway)
- **Auth**: JWT (SmallRye JWT) + WebAuthn/Passkeys (webauthn4j)
- **Storage**: S3-compatible (MinIO in dev)
- **API**: OpenAPI 3.1 contract-first (SmallRye OpenAPI)
- **GPX**: vcyclist library for track processing, timeshape for timezone lookup
- **Images**: imgproxy for on-the-fly optimization (WebP, AVIF, JXL)
- **Routing**: valhalla for cycling route computation and elevation profiles

## Prerequisites

- Java 25+, Maven 3.9+
- Docker with Compose (the backing services in dev, the dev services in tests)
- openssl (`generate-keys.sh`)

## Getting Started

### 1. Start infrastructure

The backing services live in the repository-root stack; the `.env` it needs is described in the
root [Quick Start](../README.md#quick-start).

```bash
cd .. && docker compose up -d
```

The workstation overlay `docker-compose.local.yml` starts the backing services alone (`backend`,
`frontend` and `traefik` sit behind its `app` profile) and publishes them on the loopback:

| Service | Port | Purpose |
|---------|------|---------|
| PostgreSQL + PostGIS | `POSTGRES_HOST_PORT` (5432) | Database |
| MinIO | 9000 (API), 9001 (console) | S3-compatible object storage |
| imgproxy | 38080 | Image transformation |
| valhalla | 8002 | Cycling route engine |
| tileserver | 18080 | Server-side raster map rendering |
| Mailpit | 1025 (SMTP), 8025 (web) | Email testing |

### 2. Start the backend

```bash
./generate-keys.sh             # once: the JWT key pair of dev and test, in keys/ (git-ignored)
source ../scripts/dev-env.sh   # postgres + MinIO credentials, from the .env the stack reads
mvn quarkus:dev
```

Without the keys the backend cannot sign a token (`SRJWT05009`). `dev-env.sh` exports the
`POSTGRES_*` / `MINIO_*` credentials and nothing else: Quarkus reads environment variables above
`application.properties`, so sourcing the whole `.env` would replace the `%dev` bootstrap domain
(`localhost`, the WebAuthn origin of dev passkeys) with the stack's own.

The API is available at http://localhost:8080/api with Swagger UI at http://localhost:8080/q/swagger-ui.

Quarkus dev mode provides live reload — code changes are reflected automatically on the next request.

### 3. The default domain

The platform is multi-tenant by HTTP domain, and there is nothing to create by hand: on startup the
`%dev` profile bootstraps the `localhost` domain (base URL `https://localhost:5173`) and a platform
admin (see `BootstrapService` and `pedalons.bootstrap.*` in `application.properties`). The admin has
no password — first login is by OTP (read the code in Mailpit, http://localhost:8025) or passkey.

Browsing through another hostname — a LAN IP, say — needs its own `domains` row: see
[Default domain and platform admin](../README.md#default-domain-and-platform-admin) in the root
README, and [Running SQL](../README.md#running-sql) for the psql prompt (the container is
`${ENV_NAME}-postgres`) and the rules for hand-written UPDATEs (`version`, `updated_at`).

## Commands

```bash
mvn quarkus:dev                                        # Dev mode with live reload
mvn test                                               # All tests (Quarkus dev services: needs Docker)
mvn test -Dtest=RideResourceTest                       # Single test class
mvn test -Dtest="RideResourceTest#createRide_asAdmin_shouldSucceed"  # Single test method
mvn checkstyle:check                                   # Lint
mvn package -DskipTests                                # Build + generate OpenAPI contract
./check.sh [--tests]                                   # Format + build + lint (+ tests), as in CI
```

### Code Coverage

```bash
mvn test -Dcoverage=true -Dsurefire.forkCount=1   # instrumentation is opt-in
# Reports generated in target/jacoco-report/ (csv, xml, html)

./scripts/coverage-report.sh                              # All classes, sorted by coverage
./scripts/coverage-report.sh 'fr.pedalons.service'         # Filter by package
./scripts/coverage-report.sh 'fr.pedalons.repository' missed  # Sort by missed lines
```

## Project Structure

```
src/main/java/fr/pedalons/
├── api/               # REST resources, one package per area (rides, routes, posts, trips, teams,
│                      #   auth, admin, device, gps, notifications, moderation, migration, ...)
├── common/            # TsidUtils, custom exceptions, ErrorCode
├── domain/            # JPA entities, same split (BaseEntity, TeamEntity, Publication in common/)
├── dto/               # Request/response DTOs
├── enums/             # Shared enums (status, roles, visibility, ...)
├── infrastructure/    # Security, caching, valhalla client, imgproxy
├── repository/        # Panache repositories with query builder
└── service/           # Business logic

src/main/resources/
├── application.properties    # Configuration (dev/test/prod profiles)
├── db/migration/             # Flyway migrations (V1__…, V2__…, one file per version)
└── templates/mail/           # Qute e-mail templates

keys/                         # JWT key pair for dev and test (generate-keys.sh, git-ignored)
```

The endpoints themselves are documented by the contract, `../contracts/openapi.yaml`, browsable in
dev on http://localhost:8080/q/swagger-ui.

## Configuration

Configuration uses Quarkus profiles (`%dev`, `%test`, `%prod`) in `application.properties`.

- **`%dev`** defaults to the `.env.example` credentials, so a stack left at those needs no export;
  otherwise `source ../scripts/dev-env.sh` first (see above).
- **`%prod`** — what the containers run, on a server as on a workstation — reads everything from the
  environment: the complete, commented list is `../.env.example`. Its JWT key pair is read from
  `/mnt/keys`, i.e. `data/keys/` mounted by `docker-compose.yml`. The deployment itself is in
  [docs/OPERATIONS.md](../docs/OPERATIONS.md).

## Contract-First Workflow

The backend generates the OpenAPI contract consumed by the frontend:

1. Annotate resources with SmallRye OpenAPI (`@Tag`, `@Operation`, `@APIResponses`)
2. Bump `pedalons.api.version` in `application.properties` — it is the contract's `info.version`
   and what `GET /api/version` returns
3. Run `mvn package -DskipTests` — generates `../contracts/openapi.yaml` and `openapi.json`
4. In `../frontend/`, run `pnpm generate-api` — generates the TypeScript client; the mobile client
   is regenerated as described in [mobile/README.md](../mobile/README.md)

## Multi-Tenancy

Each HTTP domain has isolated data. `DomainResolver` extracts the domain from `X-Forwarded-Host` or `Host` headers and resolves it to a `Domain` entity. All database queries filter by `domainId`.
