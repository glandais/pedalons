---
name: contract-first-api
description: Generate OpenAPI contract from backend and regenerate frontend/mobile API clients
---

# Contract-First API Workflow

Run this skill after modifying backend REST resources or DTOs to sync the OpenAPI contract and regenerate the frontend/mobile clients.

## Step 0 — Bump the API contract version (always, before generating)

`pedalons.api.version` in `backend/src/main/resources/application.properties` is the single source of
truth for the contract version. It feeds both `info.version` in `contracts/openapi.yaml` and
`GET /api/version` (which also reports the git commit the server was built from), so deployments can
be identified. **Bump it whenever the contract changes** — semver on the contract itself:

- **MAJOR** — breaking change: endpoint or field removed/renamed, type changed, optional field became required
- **MINOR** — backwards-compatible addition: new endpoint, new optional field
- **PATCH** — descriptions/docs only

If the generated `contracts/openapi.yaml` diff turns out to be empty, revert the bump.

## One-shot (preferred)

The repo root has `regenerate.sh`, which runs the whole chain end-to-end and fails fast (`set -e`):

```bash
bash regenerate.sh
```

It performs, in order:
1. `cd backend && mvn clean package -DskipTests` — generates `contracts/openapi.{yaml,json}`
2. `cd mobile && flutter pub get && dart run openapi_retrofit_generator && dart run build_runner build` — generates the mobile client **before** `pnpm check` (see below)
3. `cd frontend && pnpm check` — see below
4. `cd mobile && bash check.sh` — see below

Prefer this over running the steps by hand so nothing drifts out of sync.

## Steps (what the scripts do)

### 1. Generate OpenAPI Contract

```bash
cd backend && mvn clean package -DskipTests
```

Generates `contracts/openapi.yaml` and `contracts/openapi.json`.

### 2. Generate the Mobile Client — before `pnpm check`

```bash
cd mobile && flutter pub get && dart run openapi_retrofit_generator && dart run build_runner build
```

`pnpm check` runs `generate-brand-colors`, which reads the Freezed model of every coloured enum in
`mobile/lib/api/generated/models/` (`contracts/brand-colors.yaml`, ledger `BRAND-5`). A brand-new
enum has no model until the mobile client is generated, so this step must come first — otherwise
the generator stops and names the missing model.

### 3. Regenerate Frontend Client — `pnpm check`

```bash
cd frontend && pnpm check
```

`pnpm check` expands to: `pnpm install && pnpm generate-api && pnpm generate-routes && pnpm generate-brand-colors && pnpm format && pnpm typecheck && pnpm lint && pnpm build`.

- `generate-api` runs Orval → `src/api/dto/`, `src/api/endpoints/`, `src/api/zod/`
- `generate-routes` regenerates the UI routes contract (`paths.generated.*`, AASA, deeplinks) from `contracts/routes.yaml` — **don't skip this**; it's part of the contract surface
- `generate-brand-colors` regenerates `badgeColors.generated.ts` and `enum_colors.generated.dart` from `contracts/brand-colors.yaml` (needs step 2)
- `typecheck` (`tsc -b`) is the real type gate — not `build`

### 4. Check the Mobile Client — `check.sh`

```bash
cd mobile && bash check.sh
```

`check.sh` runs: `flutter pub get && dart run openapi_retrofit_generator && dart run build_runner build && ../format.sh mobile && flutter analyze && bash tool/test.sh`.

- Regenerates `lib/api/generated/clients/` (Retrofit) and `lib/api/generated/models/` (Freezed) — a no-op after step 2 unless something changed in between
- Formats the mobile module (`../format.sh mobile`)
- `flutter analyze` verifies no Dart errors
- `bash tool/test.sh` runs the mobile unit and widget tests (bundled `flutter test`, see `mobile/RULES.md` § Testing)

## After Running

1. Report any errors from the generation or verification steps.
2. If there are TypeScript or Dart errors, help fix them.

## Common Issues

- **Empty schemas in OpenAPI**: Missing `@Schema(implementation = ...)` in `@APIResponse` annotations
- **Orval errors**: Usually caused by an invalid OpenAPI spec — check backend annotations
- **Mobile build_runner conflicts**: `build_runner build` deletes conflicting outputs by default (the old `--delete-conflicting-outputs` flag was removed in build_runner 2.5.0)
- **`@Tag` name collides in the mobile client**: the tag becomes a getter on the generated `PedalonsApiClient`, which already carries `static String get version`. A tag named `Version` therefore produces a Dart compile error, and `flutter analyze` **won't** catch it (`analysis_options.yaml` excludes `lib/api/generated/**`) — run `dart analyze lib/api/generated/` after renaming a tag.
- **Renaming a `@Tag` leaves stale generated files**: the mobile generator writes the new `*_client.dart` but doesn't delete the old one; remove it by hand.
