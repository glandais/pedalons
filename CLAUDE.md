# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Pedalons: multi-tenant cycling team platform (rides, routes with GPX/maps, posts). Contract-first API development.

Each module has its own `CLAUDE.md` with commands, architecture, and gotchas — it loads automatically when you work with files in that directory:
[backend/](backend/CLAUDE.md) · [frontend/](frontend/CLAUDE.md) · [mobile/](mobile/CLAUDE.md) · [karoo/](karoo/CLAUDE.md) · [garmin-app/](garmin-app/CLAUDE.md)

See [docs/BRANDING.md](docs/BRANDING.md) for the brand charter — logo and icon assets, palette,
typography, components, French lexicon. **Start there**: its header maps which of the two brand
sources is authoritative over what (that file for assets, the web theme and the written charter,
`mobile/lib/core/theme/` for Flutter and the derived dark mode). The business colour code is semantic and shared by
both clients: changing it in one place only makes them diverge silently.

**French copy is gender-neutral (épicène), never point médian** — web, mobile, backend e-mails and
notifications alike. Rephrase rather than agree: « Vous participez » not « Vous êtes inscrit »,
« Voulez-vous vraiment… ? » not « Êtes-vous sûr… ? », « Léa a rejoint » not « Léa s'est inscrit »,
*personnes / membres / capitaine / tout le monde* not *participants / meneur / tous*. Role names
(« Administrateur », « Organisateur ») stay as they are. Rules and lexicon: BRANDING.md §8.2 and §8.4.

## Where things are written down

| Question | Read |
|---|---|
| What's left to do, and what was deliberately ruled out | **[docs/LEDGER_NEXT.md](docs/LEDGER_NEXT.md)** — start here: a generated index, one line per entry, each linking to its file `docs/ledger/<PREFIX>/<ID>.md` |
| What was delivered, and the decisions not to undo | [docs/LEDGER_DONE.md](docs/LEDGER_DONE.md), the generated index of delivered entries; the text is in each entry's file |
| How the ledger works (entry format, commands, prefix table) | [docs/ledger/README.md](docs/ledger/README.md) |
| Product roadmap (P0 → Icebox): ideas with no ledger entry yet, nothing delivered | [docs/BACKLOG.md](docs/BACKLOG.md) |
| Notifications (event pipeline, channels, what's left) | design in [docs/plans/archive/2026-09-18-notifications.md](docs/plans/archive/2026-09-18-notifications.md) (delivered, archived); what's left is `NOTIF-1`…`NOTIF-4`, `NOTIF-11` and `NOTIF-12`, what shipped `NOTIF-9` |
| Why the mobile app / the site / the API look the way they do | [docs/plans/archive/](docs/plans/archive/) — executed plans, kept for their arbitrations |
| Security findings still open | the `SEC` section of [docs/LEDGER_NEXT.md](docs/LEDGER_NEXT.md) (context in [docs/ledger/SEC/README.md](docs/ledger/SEC/README.md)); the September 2026 audit (H/M/L/V IDs, verified controls) is archived in [docs/plans/archive/2026-09-security-audit.md](docs/plans/archive/2026-09-security-audit.md) |
| Infrastructure, CI/CD and code-quality audit (February 2026, statuses partly refreshed on 2026-09-29) — some rows still open; not the security reference | [docs/plans/2026-02-14-project-audit.md](docs/plans/2026-02-14-project-audit.md) |
| TLA+/Lean models of backend concurrency (October 2026), what each established, how to rerun them | [docs/formal/README.md](docs/formal/README.md) |
| Manual recette by a person or an agent (stable `.test` accounts, the e2e stack local or on optiplex, Chrome on the Android phone over CDP, the app on the Android phone or the iPhone) | `scripts/recette.sh` + [frontend/e2e/README.md](frontend/e2e/README.md#manual-recette-scriptsrecettesh) |
| Deployment, backups, restore (the runbook) | [docs/OPERATIONS.md](docs/OPERATIONS.md) |
| What the product does, for whom | [docs/PRODUCT_SHEET.md](docs/PRODUCT_SHEET.md) |
| Biketeam → Pédalons migration, team by team, server to server over HTTPS (contract with biketeam, operations) | [docs/plans/2026-09-22-biketeam-live-migration.md](docs/plans/2026-09-22-biketeam-live-migration.md) + [docs/MIGRATE_BIKETEAM.md](docs/MIGRATE_BIKETEAM.md) |
| Monetisation plan (pricing tiers, annual invoicing through Qonto, subscription tracking, per-team entitlements) — a proposal, nothing decided | [docs/plans/2026-10-17-monetisation.md](docs/plans/2026-10-17-monetisation.md) |
| Free-tier limits before any payment (25 members, 20 planner saves a month per team and 10 per user in the GPX tools, platform admin unlocks a team) — delivered (contract `14.2.0`–`14.5.0`), e2e still to run | [docs/plans/archive/2026-11-11-limites-offre-gratuite.md](docs/plans/archive/2026-11-11-limites-offre-gratuite.md) (ledger `BILL-10`, `BILL-11`) |
| Route generator: engine in osm-route-details (api 1.9), team overlays deposited at night, the Java search removed — lots 0 to 3 coded (contract `15.0.0`) and in production since 2026-11-16, backend tests and e2e green; France served since 2026-11-17 (engine 1.9.2, lot 6); learned taste per team and organic shapes by default since engine 1.12.0 (lot 4, `OPS-64`); OSM attractors shipped off in 1.13.0 (`OPS-65`); the planet served since engine 1.14.0 (30 s budget, `OPS-66`); off-road share and rideability bounds since engine 1.15.0 and contract `16.3.0` (lot 5, `OPS-67`) | [docs/plans/2026-11-15-generateur-parcours-osm.md](docs/plans/2026-11-15-generateur-parcours-osm.md) + lot 3b [docs/plans/2026-11-16-generateur-parcours-osm-lot3b.md](docs/plans/2026-11-16-generateur-parcours-osm-lot3b.md) (ledger `API-207`, `API-206`, `WEB-179`, `OPS-60`, `OPS-61`, `OPS-64`, `OPS-65`, `OPS-66`, `OPS-67`, `API-215`, `WEB-197`) |
| Retouching an existing route with the generator's engine (aim at a distance, move the finish, by a local splice that leaves the rest of the route untouched) — decided on 2026-11-22; lot 0 measured the same day (no criterion met as such, shortening fails, moving the finish is close), next lot awaits the owner | [docs/plans/2026-11-22-retouche-parcours.md](docs/plans/2026-11-22-retouche-parcours.md) (ledger `API-212`) |
| Who may read or write a team entity (audit of 2026-11-11), and the plan to let a private team publish one by link with backend-computed permissions — delivered (contract `13.6.0`–`13.8.0`, e2e and Patrol green on 2026-11-16) | [docs/plans/archive/2026-11-11-visibilite-contenu-equipe-privee.md](docs/plans/archive/2026-11-11-visibilite-contenu-equipe-privee.md) (ledger `API-176`, `WEB-166`, `MOB-137`) |
| The design brief the v2 came from (state *before* v2) | [docs/plans/archive/audit-ux/](docs/plans/archive/audit-ux/) |

### Task workflow: one file per ledger entry

Every ledger entry carries a **stable ID, `PREFIX-n`** (`API-21`, `MOB-7`, `NOTIF-9`…) and lives in
its own file, `docs/ledger/<PREFIX>/<ID>.md`, with a small frontmatter (`id`, `title`,
`status: open | done | out`, optional `size`, `group` and `kind`, `verified` or `done` dates). The prefix
names the domain (`MOB`, `WEB`, `API`, `OPS`, `NOTIF`, `MOD`, `ISSUE`, `MIG`, `BRAND`, `SEC`, `AUD`,
`LEGAL`, `BILL` — the table and the full rules are in [docs/ledger/README.md](docs/ledger/README.md)).
`docs/LEDGER_NEXT.md` and `docs/LEDGER_DONE.md` are **generated indexes — never hand-edit them**.
References cite the **ID only**, never a title or a file: « ledger `WEB-3` » in docs,
`docs/LEDGER_*.md WEB-14` in code comments (still right: both indexes name every ID).
`grep -rn 'WEB-14'` finds the entry and everything that points at it. Read the index first, then
only the entry files you need — never the whole directory.

- **Creating a task**: `node scripts/ledger.mjs new API "Title" --size S` creates the file with the
  next free number of that prefix. Under « Reste à faire », name the degradation it removes and
  where it lives in the code. A large task gets its own plan in `docs/plans/` and a one-paragraph
  entry that links to it. Something deliberately **not** done gets `status: out` with its reason
  under « Écarté » — never silently dropped.
- **Resolving a task**: in the same commit as the work, set `status: done` and `done: <date>`,
  drop `verified`, and rewrite the text under « Livré » in the past tense, with the API version if
  the contract changed, the test that covers it, and the decisions that must not be undone. If a
  part is still open, keep `status: open` and both sections in the same file (a split into two
  subjects keeps the ID on one and takes a new number for the other).
- **`kind` marks an open entry no code change can close**: `recette` (to be seen by hand on a
  device, in a browser, on a GPS unit or in production), `externe` (a store, a third party, an
  operation outside the repository) or `decision`. The index lists them apart; don't spend a
  session « fixing » one, and drop the field with `verified` when the entry is resolved.
- **Rereading an open entry against the code** updates its `verified` date, changed or not;
  `node scripts/ledger.mjs stale` lists the ones not reread for thirty days.
- **Always finish with `node scripts/ledger.mjs index`** and commit the two indexes with the entry;
  `node scripts/ledger.mjs check` (run by CI) fails on a stale index, a malformed entry, a dead link
  or a code comment citing an ID that does not exist.
- **IDs are never renumbered or reused**, an entry file is never deleted, and a prefix is never
  renamed; a new domain adds a row to the prefix table of `docs/ledger/README.md`.
- A plan in `docs/plans/` that is fully executed moves to `docs/plans/archive/` (with its row in the
  archive README); its leftovers become ledger entries.

Four invariants that cut across modules, each of which a plausible-looking change would break:

- **A ride group's leader is `RideGroupDto.leader`, nullable, and null is the common case** — render
  nothing, and never fall back to `createdBy` (the *ride's* creator, identical across all its
  groups). Guarded by the backend test `groupLeader_isNotTheRideCreator`.
- **An ad's position is blurred to ~1 km and the proximity probe is quantised on the same grid** —
  every client renders a **sector, never a pin**. `AdDto` carries no contact field either: messages
  go through an e-mail relay so no address ever appears in the API.
- **List lookups resolve per *page*, never per row** — `ParticipationLookup`, `CommentCountLookup`
  and `ThumbnailLookup` each take a fixed number of queries for a whole page. The
  `…QueryCountTest` classes fail if someone reintroduces a per-row query; don't disable them to make
  a build pass.
- **Member names never reach a non-member — the count only.** Anonymous, no-team and other-team callers get
  no participant, leader or author name, avatar or id (`member || platformAdmin`, resolved once per page by
  `MemberNamesVisibility`); the `…/participants` endpoints refuse them like comments. Guarded by the backend
  test `MemberNamesVisibilityResourceTest` (ledger `API-144`).

## Tech Stack

| Layer | Technologies |
|-------|-------------|
| Backend | Java 25, Quarkus 3.39.x, PostgreSQL 18 + PostGIS, Hibernate/Panache, Flyway |
| Frontend | TypeScript 7 (tsgo native compiler), React 19, Vite 8, Mantine UI, Zustand, React Query |
| Mobile | Flutter, Dart (see `mobile/RULES.md` for detailed guidelines) |
| Karoo | Kotlin, Jetpack Compose, karoo-ext SDK, ktor-client-karoo |
| Auth | Database auth with JWT (password, OTP, passkeys/WebAuthn) |
| IDs | TSID via hypersistence-utils (Long internally, lowercase string in API) |
| API | OpenAPI 3.1 contract-first with code generation |

## Infrastructure

**One** stack serves both workflows on a workstation — there is no separate dev compose file.

```bash
# Backing services only, for `mvn quarkus:dev` + `pnpm dev`.
docker compose up -d

# The whole application, from the images built by ./build.sh.
docker compose --profile app up -d
```

`docker-compose.yml` **is the deployment file** — keep dev tooling out of it; what a workstation
needs on top lives in `docker-compose.local.yml`, picked up through `COMPOSE_FILE` in the local
`.env`. It is deployed as a **Docker Swarm** stack (always via `scripts/deploy.sh`) yet run by plain
`docker compose` on a workstation, so it must stay valid for both: no `profiles:` and no top-level
`name:` (they make `docker stack deploy` fail), Traefik routing labels under both `labels` and
`deploy.labels` (one YAML anchor), and no published postgres port (Swarm cannot bind the loopback).
The overlay undoes what only Swarm wants — traefik's Docker provider, its loopback port, a bridge
network (`!reset`). The overlay, its ports and the `.env` keys are described in the [README](README.md#quick-start)
([Running the full stack locally](README.md#running-the-full-stack-locally)); deployment, the shared
stack, backups and restore in [docs/OPERATIONS.md](docs/OPERATIONS.md) — read its
[Deployment](docs/OPERATIONS.md#deployment) section before touching networks or the compose files.

Five rules hold whatever the change:

- **The dev backend needs the stack's credentials**: `source scripts/dev-env.sh` before
  `mvn quarkus:dev`. It exports the postgres/MinIO values from `.env` and nothing else — Quarkus reads
  env vars above `application.properties`, so the full file would override the `%dev` bootstrap
  domain (`localhost`, the WebAuthn origin of dev passkeys).
- **End-to-end tests run on a stack of their own**: `scripts/e2e.sh` starts `tribly-e2e` (empty
  database, mail to mailpit only, ports offset so it runs beside `tribly-local`). Never point the suite at the workstation stack — see
  [frontend/e2e/README.md](frontend/e2e/README.md).
- **`ENV_NAME` names the stack** — containers, network, image tags, the Swarm stack and its
  volumes, and the postgres/minio the backup scripts look up. Keep it `tribly-local` on a workstation: a local stack called `…-prod` is
  indistinguishable from the real one in `docker ps` and to `scripts/restore.sh`.
- **A local stack must not be able to send mail.** The containers run the `%prod` Quarkus profile,
  whose only way out for mail is the SMTP relay named by `QUARKUS_MAILER_*`. A local `.env`
  therefore points it at `mailpit:1025`, with TLS and login `DISABLED`. This is not cosmetic: after a
  biketeam migration the local database holds thousands of real member addresses, and one OTP or
  team invitation is enough to reach them.
- **Deploys are rolling, start-first**: `build.sh` tags each image `${ENV_NAME}-<sha12>` (plus the
  alias `${ENV_NAME}`), `deploy.sh` deploys the checked-out commit's tag, so for about a minute the
  old and new backends share the database. A Flyway migration must therefore leave the schema usable
  by the previous release, and a scheduled job not claiming its work in the database must be
  idempotent. See [Rolling updates](docs/OPERATIONS.md#rolling-updates-and-rollback).

## Multi-Tenancy

- **Domain-based isolation**: Each HTTP domain has its own teams/users. Same email can exist on different domains.
- **Domain resolution**: `DomainResolver` extracts domain from `X-Forwarded-Host` → `Host` header → finds `Domain` entity
- **Domain entity**: Stores `domain` (hostname), `name`, `baseUrl`. WebAuthn/email settings derived from Domain.
- **All queries must filter by domainId**: Use `pedalonsQueryContext.getDomainId()` in query builders
- **Tests**: Call `dataService.getOrCreateDefaultDomain()` + `domainResolver.setDomainForTest(domain)` in setUp()

## Contract-First Workflow

**API contract**: use the `contract-first-api` skill after modifying backend REST resources or DTOs. Bump `pedalons.api.version` in `backend/src/main/resources/application.properties` with every contract change — it drives both `info.version` in the contract and `GET /api/version`.

**UI routes contract**: `contracts/routes.yaml` is the single source of truth (multi-locale path templates, deeplink/mobile flags). Edit it, then run `pnpm generate-routes` in frontend/ to regenerate `paths.generated.ts`, `paths.generated.dart`, the apple-app-site-association file, and the deeplink section of `AndroidManifest.xml`. Never hand-edit those. See [docs/APP_LINKS.md](docs/APP_LINKS.md).

**Business colour code**: `contracts/brand-colors.yaml` (enum value → colour family, fallback gradients) is its single source. Edit it, then run `pnpm generate-brand-colors` in frontend/ to regenerate `frontend/src/lib/badgeColors.generated.ts` and `mobile/lib/core/theme/enum_colors.generated.dart`. Never hand-edit those, and never add a local colour table for an enum in a component. See [docs/BRANDING.md](docs/BRANDING.md) §3.6.

## Formatting

```bash
./format.sh                        # format every module
./format.sh mobile                 # or one module: backend|frontend|mobile|karoo|garmin-app
```

Every module has an auto-formatter (Spotless/google-java-format, Prettier, `dart format`, Spotless/ktfmt,
prettier-plugin-monkeyc). `format.sh` fails loudly if a toolchain is missing rather than skipping a module.

- **Don't spend effort on formatting** — never hand-align code, reflow lines, or reorder imports for style, and
  don't raise formatting nits in reviews. Write code naturally and let the formatters decide.
- **Always run `./format.sh` before any commit**, and include its output in that commit.

## Critical Prohibitions

- **Never run backend tests yourself** — give instructions to the user instead. You're bad at fixing tests from test outcomes.

## Dev URLs

| Service | URL |
|---------|-----|
| Backend API | http://localhost:8080/api |
| Swagger UI | http://localhost:8080/q/swagger-ui |
| Frontend | https://localhost:5173 (needs the [mkcert certificates](frontend/README.md#https-setup-required-for-webauthnpasskeys) — without them it falls back to http and dev passkeys fail) |
