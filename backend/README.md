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

- Java 25+
- Maven 3.9+
- Docker & Docker Compose

## Getting Started

### 1. Start infrastructure

The backing services live in the repository-root stack — `docker-compose.yml` plus the workstation
overlay `docker-compose.local.yml`, which is what publishes the loopback ports below. See
[Quick Start](../README.md#quick-start) for the `.env` a workstation needs.

```bash
cd .. && docker compose up -d
```

`backend`, `frontend` and `traefik` sit behind an `app` profile in the overlay, so this starts the
backing services alone — which is what dev mode wants. They provide:

| Service | Port | Purpose |
|---------|------|---------|
| PostgreSQL + PostGIS | 5432 | Database |
| MinIO | 9000 (API), 9001 (console) | S3-compatible object storage |
| imgproxy | 38080 | Image transformation |
| valhalla | 8002 | Cycling route engine |
| tileserver | 18080 | Server-side raster map rendering |
| Mailpit | 1025 (SMTP), 8025 (web) | Email testing |

### 2. Start the backend

```bash
source ../scripts/dev-env.sh   # postgres + MinIO credentials, from the .env the stack reads
mvn quarkus:dev
```

`dev-env.sh` exports those five values and nothing else: Quarkus reads environment variables above
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
mvn test                                               # Run all tests (TestContainers)
mvn test -Dtest=RideResourceTest                       # Single test class
mvn test -Dtest="RideResourceTest#testCreateRide"      # Single test method
mvn spotless:apply                                     # Format (Google Java Format)
mvn checkstyle:check                                   # Lint
mvn package -DskipTests                                # Build + generate OpenAPI contract
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
├── api/               # REST resources organized by domain
│   ├── admin/         #   Platform admin endpoints
│   ├── auth/          #   Login, passkeys, OTP
│   ├── device/        #   Device code flow (Karoo, Garmin)
│   └── ...            #   rides, routes, posts, trips, teams, ads, notifications, moderation, etc.
├── common/            # TsidUtils, custom exceptions, ErrorCode
├── domain/            # JPA entities
│   ├── common/        #   BaseEntity, TeamEntity, Publication
│   ├── ride/          #   Ride, RideGroup, RideParticipation
│   ├── route/         #   Route, GpxTrack, GpxWaypoint
│   ├── trip/          #   Trip, TripStage, TripParticipation
│   └── ...            #   post, comment, team, user, auth, gps, etc.
├── dto/               # Request/response DTOs by domain
├── enums/             # Status, TeamRole, Visibility, AssetType
├── infrastructure/    # Security, caching, valhalla client, imgproxy
├── repository/        # Panache repositories with query builder
└── service/           # Business logic

src/main/resources/
├── application.properties    # Configuration (dev/test/prod profiles)
├── db/migration/             # Flyway migrations (V1__…, V2__…, one file per version)
└── templates/                # Qute templates (emails)

keys/                         # JWT key pair for dev and test (backend/keys/, generate-keys.sh)
```

## API Domains

The API covers these functional areas:

| Domain | Resources | Description |
|--------|-----------|-------------|
| Auth | AuthResource, PasskeyResource | Login (password, OTP, passkeys), token refresh |
| Teams | TeamResource, TeamMemberResource | Team CRUD, member management, roles |
| Invitations | TeamInvitationResource, InvitationResource, UserInvitationResource | Team invitations |
| Webhooks | TeamWebhookResource | Team outgoing webhooks |
| Users | UserResource, UserBlockResource, UserExportDownloadResource | Profile, blocking, data export |
| Rides | RideResource, RideTemplateResource | Scheduled group rides with participation |
| Routes | RouteResource, AllRouteResource | GPX routes with tracks, waypoints, elevation |
| Posts | PostResource | Team blog posts |
| Trips | TripResource | Multi-day trips with stages |
| Publications | PublicationResource, TeamPublicationResource | Cross-type publication feeds |
| Pages | TeamPageResource | Team pages |
| Ads | AdResource | Classified ads (blurred position, e-mail relay) |
| Comments | Post/Ride/Route/TripCommentResource | Comments on any entity |
| Assets | AssetResource, Download*Resource | File uploads (images, GPX) via S3 |
| Places | PlaceResource | Named locations |
| Calendar | CalendarResource, TeamCalendarResource | iCal feed generation |
| GPS | GpsResource | GPS device integrations (Hammerhead, Garmin, Wahoo) |
| Device | Device*Resource | Device code flow + routes for Karoo/Garmin apps |
| Admin | Admin*Resource | Platform admin (domains, teams, users) |
| Config | ConfigResource | Frontend app configuration |
| Router | RouterResource | valhalla proxy for route computation |
| Tiles | TileTokenResource | Short-lived tokens for vector tiles |
| Notifications | NotificationResource, PushDeviceResource | In-app notifications, push device registration |
| Moderation | ReportResource, TeamReportResource | Content reports |
| Feedback | FeedbackResource | In-app feedback |
| Migration | BiketeamMigration*Resource | Biketeam → Pédalons migration (see docs/MIGRATE_BIKETEAM.md) |

## Configuration

Configuration uses Quarkus profiles (`%dev`, `%test`, `%prod`) in `application.properties`.

**Dev defaults** match `.env.example`, so a stack left at those credentials needs no export at all.
A stack with its own `POSTGRES_*` / `MINIO_*` values needs `source ../scripts/dev-env.sh` first —
`%dev` reads them from the environment, defaulting to the `.env.example` ones.

**Production** requires environment variables:

| Variable | Purpose |
|----------|---------|
| `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB` | Database |
| `MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY` | S3 storage |
| `IMGPROXY_URL` | Image proxy |
| `VALHALLA_URL` | Route engine |
| `ENCRYPTION_KEY` | Token encryption (base64-encoded 32-byte key) |
| `TILESERVER_URL` | Tile server for map thumbnails |
| `QUARKUS_MAILER_*` | SMTP relay (Scaleway TEM on a server, Mailpit on a workstation) |
| `PEDALONS_BOOTSTRAP_*` | Default domain and platform admin created on startup |
| `FCM_PROJECT_ID`, `FCM_CREDENTIALS`, `FCM_WEB_*` | Push notifications (service account defaults to `/mnt/keys/fcm-service-account.json`) |

The JWT key pair is read from `/mnt/keys` (`data/keys` mounted by `docker-compose.yml`). The
complete, commented list is `../.env.example`; the deployment itself is described in
[docs/OPERATIONS.md](../docs/OPERATIONS.md).

## Contract-First Workflow

The backend generates the OpenAPI contract consumed by the frontend:

1. Annotate resources with SmallRye OpenAPI (`@Tag`, `@Operation`, `@APIResponses`)
2. Run `mvn package -DskipTests` — generates `../contracts/openapi.yaml` and `openapi.json`
3. In `../frontend/`, run `pnpm generate-api` — generates TypeScript client from the contract

## Multi-Tenancy

Each HTTP domain has isolated data. `DomainResolver` extracts the domain from `X-Forwarded-Host` or `Host` headers and resolves it to a `Domain` entity. All database queries filter by `domainId`.
