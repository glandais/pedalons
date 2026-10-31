# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Pedalons mobile app: Flutter client for the cycling team platform. See parent `../CLAUDE.md` for full project context.

The app is at **v2** (July 2026): a rewritten design system (`core/pdl`), a single five-tab shell, light *and* dark themes, metric *and* imperial units, and twelve reworked screens. Two documents explain the shape of it — read them before adding a widget or a screen:

- **[lib/core/pdl/README.md](lib/core/pdl/README.md)** — the component library's contract, its naming, and the two `grep`s that enforce it in review. Not optional reading: a widget that can't meet the contract belongs in its feature, without the `Pdl` prefix.
- **[../docs/plans/archive/2026-07-26-mobile-v2-implementation.md](../docs/plans/archive/2026-07-26-mobile-v2-implementation.md)** — the plan that produced v2, kept for the *why* of ~15 arbitrations that still constrain the code (no `createdBy` fallback for a group leader, offset over cursor pagination, device timezone over team timezone — since reversed for rendezvous, which read in the entity's zone (ledger `API-60`) —, Material icons over Tabler). One of them has since been reversed: the GeoJSON fallback that stood in
for `.mvt` tiles is gone — a signed tile token (API 2.3.0) lets MapLibre fetch the real tiles, and
the fallback was deleted rather than kept.

What remains to do — and what was deliberately left out — is in **[../docs/LEDGER_NEXT.md](../docs/LEDGER_NEXT.md)**.

## Commands

```bash
flutter pub get                    # Install dependencies
flutter run                        # Run on connected device/emulator
flutter test                       # Run tests
flutter analyze                    # Static analysis
bash check.sh                      # pub get + both generators + ../format.sh mobile (rewrites files) + analyze + flutter test — the full gate
../format.sh mobile                # dart format (skips generated code) — run before every commit

# Code generation (after modifying models or API)
dart run build_runner build

# API client generation from OpenAPI
dart run openapi_retrofit_generator

# End-to-end tests (Patrol) — on the e2e stack, never production: see patrol_test/README.md
../scripts/e2e.sh up               # from mobile/: start the e2e stack first
bash e2e.sh                        # every test in patrol_test/ (E2E_PLATFORM=android for the emulator)
```

## Agent tooling

Skills from [dart-lang/skills](https://github.com/dart-lang/skills), [flutter/agent-plugins](https://github.com/flutter/agent-plugins)
and [leancodepl/patrol](https://github.com/leancodepl/patrol) are vendored at the repository root, under `../.claude/skills/`
(`dart-*`, `flutter-*` and `patrol-*`, installed via `npx skills add ... --agent claude-code --copy`;
`../skills-lock.json` records those `npx skills` manages) — Claude picks them up automatically for tasks like adding unit or widget tests, fixing runtime
errors or layout overflows, responsive layouts, animations, routing, and writing Patrol tests. Only the skills that fit
the project are kept: the ones that prescribed what it doesn't use (mockito, `package:http`, gen-l10n, `ChangeNotifier`,
`integration_test`), were off-topic (FFI, CLI apps) or duplicated another were removed on purpose — don't reinstall them. Re-run the same `npx skills` command (see each repo's
README) to update the others; there's no dependency on the `.agents/skills` universal layout since we vendor a copy
instead of symlinking.

The [Dart/Flutter MCP server](https://docs.flutter.dev/ai/mcp-server) (`dart mcp-server`) is registered project-wide in
`../.mcp.json` as `dart-mcp-server` — it gives Claude live `analyze_files`, `hot_reload`/`hot_restart`, `get_runtime_errors`,
`widget_inspector`, and device/app-lifecycle tools against a running Flutter app, on top of the static skill
instructions above.

To let it [drive a running app](https://docs.flutter.dev/ai/mcp-server#interact-with-a-running-app) — screenshots, tapping,
entering text, scrolling, hot reload — launch with the Flutter Driver extension enabled (off by default, gated in
`main.dart` behind `ENABLE_FLUTTER_DRIVER`, never in production builds):

```bash
flutter run -d <device-id> --dart-define=ENABLE_FLUTTER_DRIVER=true
```

Then ask Claude to connect to the running app. **Warning**: this disables real keyboard input on the device (typing is
dropped, the on-screen keyboard may not appear) — only launch this way when you actually need the agent to drive the UI.

A second MCP server, `patrol` (`tool/patrol_mcp.sh`, also in `../.mcp.json`), runs a test of `patrol_test/` in a
`patrol develop` session, takes screenshots and reads the native UI tree — on the same e2e stack and device as `e2e.sh`,
never production. The widget keys those tests find live in `lib/keys.dart`.

## Architecture

```
lib/
├── main.dart              # Entry point, deep link handling, ProviderScope
├── app.dart               # PedalonsApp widget, themeMode from user preferences
├── config/
│   ├── router.dart            # GoRouter: StatefulShellRoute.indexedStack, 5 fixed branches
│   ├── paths.dart             # Re-export of paths.generated.dart
│   ├── paths.generated.dart   # Generated from ../../../contracts/routes.yaml — DO NOT EDIT
│   ├── locale_context.dart    # Mutable current-locale, synced from context.locale in app.dart
│   └── app_config.dart        # API URLs, WebAuthn config (compile-time env)
├── api/
│   ├── pedalons_api_client.dart  # Dio providers, client providers
│   ├── interceptors/           # Auth interceptor with token refresh
│   └── generated/              # Auto-generated from OpenAPI (DO NOT EDIT)
│       ├── clients/            # Retrofit API clients
│       ├── models/             # Freezed DTOs
│       └── export.dart         # Barrel file
├── keys.dart              # Widget keys the Patrol tests (patrol_test/) find
├── screenshots/           # Store screenshot mode (--dart-define=SCREENSHOTS=true only)
├── core/
│   ├── pdl/               # THE component library — ~60 Pdl* widgets. See pdl/README.md
│   │   ├── pdl.dart           # Single barrel: import this, never a file directly
│   │   ├── elevation/         # PdlElevationProfile — two hand-written CustomPainters
│   │   └── map/               # PdlMap, its overlays, and the signed-token mass tile layer
│   ├── theme/             # pdl_colors, pdl_tokens, pdl_typography, pdl_icons, enum_colors (+ .generated, from contracts/brand-colors.yaml)
│   ├── units/             # UnitSystem — metric/imperial
│   ├── preferences/       # user_preferences_provider — theme, units, language, contactable
│   ├── adaptive/          # kAppDestinations (the five tabs), breakpoints, AdaptiveScaffold, responsive grid
│   ├── logging/           # AppLog (the recent log a report attaches), ErrorReporter
│   ├── pagination/        # PagedListNotifier (offset-based, dedup by itemKey)
│   ├── geo/               # location_service, polyline_index (client-side hit-testing)
│   ├── animations/, config/, utils/, widgets/
├── dev/                   # PdlGallery, map demo, shell demo — the library's living doc
└── features/              # Feature-based organization
    ├── auth/
    │   ├── data/              # SecureTokenStorage, AuthRepository
    │   ├── domain/            # AuthState (freezed)
    │   ├── providers/         # AuthNotifier (StateNotifier)
    │   ├── presentation/      # LoginPage, VerifyEmailPage
    │   └── services/          # PasskeyService
    ├── home/, teams/, rides/, routes/, calendar/, trips/, posts/, ads/
    ├── comments/, participants/, feed/, profile/, legal/, device/, apps/
    ├── notifications/, feedback/, moderation/
    └── navigation/presentation/shell/main_shell.dart
```

### The design system (`core/pdl`)

Read [lib/core/pdl/README.md](lib/core/pdl/README.md) before touching it. Three rules, all
`grep`-verifiable, all enforced in review:

1. **No colour, size, duration or icon literal** — everything comes from `context.pdl`
   (`PdlColors`), `PdlSpacing` / `PdlRadii` / `PdlMetrics`, `context.pdlText`, `PdlMotion`,
   `PdlIcons`. Dark mode then works *by construction*; a screen that patches a colour with a
   literal is the bug, not the fix.
2. **44 px minimum tap target** (`PdlMetrics.tapTarget`), including for compact sizes — `sm`
   tightens typography and gutters, never the target.
3. **`core/pdl` imports no generated DTO and translates nothing.** A component needing a business
   tint takes a `PdlTone`; a component needing a label takes a `String`. Localisation keys belong to
   screens.

```bash
grep -rn --include='*.dart' "api/generated" lib/core/pdl   # must stay empty
grep -rn --include='*.dart' '\bIcons\.'     lib/core/pdl   # must stay empty — PdlIcons only
```

`PdlIcons` is the only file in the app allowed to name `Icons.*`, so swapping icon sets later
touches one file. `lib/dev/pdl_gallery_page.dart` renders the whole library in both themes — the
fastest way to see what already exists before writing a new widget.

## Contract-First API Workflow

1. Backend generates `contracts/openapi.yaml`
2. Run `dart run openapi_retrofit_generator` → generates `lib/api/generated/`
3. Run `dart run build_runner build` for freezed/json_serializable

Generated code uses:
- **Retrofit** for HTTP clients (annotations → `.g.dart`)
- **Freezed** for immutable models (→ `.freezed.dart`, `.g.dart`)

## Key Patterns

**State Management**: Riverpod 3 — `StateNotifier` for the older providers (it needs
`import 'package:flutter_riverpod/legacy.dart';`), `Notifier` in part of the recent ones

```dart
// Provider definition
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => ...);

// Usage in widgets
class MyWidget extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authProvider);
    final notifier = ref.read(authProvider.notifier);
  }
}
```

**Navigation**: GoRouter with `Paths` class

```dart
// Always use Paths.xxx() instead of hardcoded strings
// Paths is locale-aware: returns /equipes/... when locale is fr, /teams/... for en
context.go(Paths.team(teamSlug));
context.go(Paths.ride(teamSlug, rideSlug));
```

Path declarations live in `../contracts/routes.yaml` (single source of truth shared with the frontend). After editing the YAML, run `pnpm generate-routes` from `frontend/` — it regenerates `lib/config/paths.generated.dart` and the Android deeplink section. See [docs/APP_LINKS.md](../docs/APP_LINKS.md).

`router.dart` registers every locale variant so deep links in any supported language match. Flat routes use `_perLocale(PathVariants.xxx(), ...)`.

**The shell has five fixed branches and only five** — `StatefulShellRoute.indexedStack`, one
`StatefulShellBranch` per tab, declared once in `kAppDestinations` (`core/adaptive/navigation_destination.dart`).
There is no second `NavigationBar`: team sections are **content** (a sticky chip row under the team
header, `features/teams/.../team_sections.dart`), not a nested tab bar. The old `TeamShell` was
removed in v2 — it was the direct cause of sheets rendering under the tab bar and of stacked error
states. Two tests guard this: `shell_branches_test.dart` (branch count and order) and
`destination_index_test.dart` (which tab lights up for a given path — most specific wins, so a team's
route library stays on Teams, not Routes).

A route opened straight from a link starts with an empty back stack, so `_deepLinkHierarchies` declares the ancestors to push underneath it (`ancestorsForDeepLink`). Add an entry for any new deep-linkable route that lives outside a shell — see [docs/APP_LINKS.md](../docs/APP_LINKS.md) and `test/deep_link_hierarchy_test.dart`.

**API Clients**: Provider-based dependency injection

```dart
// Unauthenticated (for login/register)
final baseApiClientProvider = Provider<PedalonsApiClient>((ref) => ...);

// Authenticated (has auth interceptor)
final apiClientProvider = Provider<PedalonsApiClient>((ref) => ...);

// Individual clients
final teamsClientProvider = Provider<TeamsClient>((ref) => ref.watch(apiClientProvider).teams);
```

**Auth Flow**: Token stored in secure storage, synced to `accessTokenHolderProvider` for interceptor

```dart
// Token refresh handled by AuthInterceptor on 401
// Failed requests queued and retried after refresh
```

## Critical Gotchas

- **Never edit generated code** in `lib/api/generated/` or `lib/config/paths.generated.dart` — edit source and regenerate (see Contract-First and Path Management)
- **Build order matters**: freezed → json_serializable → retrofit_generator (configured in `build.yaml`)
- **Two Dio instances**: `baseDioProvider` (no auth) for login/register, `dioProvider` (with auth interceptor) for protected endpoints
- **Token sync**: Auth state updates must call `_syncTokenToHolder()` for interceptor to see new token
- **Deep links**: Handled by `app_links` package, GoRouter processes the path. Manifest intent-filters are generated from `../contracts/routes.yaml` — see [docs/APP_LINKS.md](../docs/APP_LINKS.md)
- **The router is built once**: `routerProvider` must never `ref.watch` auth state — recreating the `GoRouter` restarts the navigator from `initialLocation` and wipes the back stack rebuilt for a deep link. Auth changes flow through `refreshListenable` and re-run `redirect`
- **Deep links wait for the app to be navigable**: `main.dart` opens the pending link only once auth is initialized *and* the router has parsed its first route — `GoRouter.push` stacks onto `routerDelegate.currentConfiguration`, which is empty before that
- **Locale**: `app.dart` propagates `context.locale.languageCode` into `locale_context.dart` so `Paths.xxx()` returns the right variant
- Config via `--dart-define`: `flutter run --dart-define=API_BASE_URL=http://localhost:8080`
- **Adding a capability that touches personal data** (image picker, location, file import, any analytics SDK) means updating `ios/Runner/PrivacyInfo.xcprivacy` and both store privacy forms. [store-metadata/data-safety.md](store-metadata/data-safety.md) is the source of truth and lists which feature triggers which declaration — App Review rejects an app whose manifest under-declares

### v2 invariants — a review rejects a change that breaks one

- **No colour literal outside `core/theme`**: `grep -rnE '0xFF[0-9A-Fa-f]{6}' lib/features` must stay empty. A dark-mode contrast problem is fixed in the token table, never on the screen that shows it
- **`PdlSheet` is the only caller of `showModalBottomSheet`** — that is what keeps sheets above the tab bar
- **Route waypoints** (`MOB-84`): a native `symbol` layer plus images re-added at every layer pass (a basemap change wipes the style's images), never a filter on the coordinate values (`WEB-108`), off-track points never on the profile, an unknown type renders as `INFO`
- **A group's leader is `RideGroupDto.leader`, and nothing else.** It is nullable, and null is the *common* case (most groups have no designated leader) — render nothing. **Never fall back to `createdBy`**, which is the *ride's* creator and therefore identical across all its groups: the fallback would be wrong almost everywhere, and wrong in the way that doesn't announce itself. The backend keeps a test named `groupLeader_isNotTheRideCreator` for exactly this
- **An ad's position is blurred to ~1 km** — render a sector (circle, zone), **never a pin**. A pin on a cell centre claims a precision the data doesn't have, and points at somewhere that isn't the seller's home while looking like an address
- **The bell is back, and it reads a real API** — `features/notifications/` serves the home bell, the `/notifications` inbox and the profile's « Notifications » sub-page (`/profil/notifications`, one row per type with an E-mail/Push chip per channel — `notification_settings_page.dart`) off `/api/notifications*`. What has not changed is the rule that put it away in v2: **no control without effect**. So the channel *chips* are not rendered when `NotificationPreferencesDto.channels` comes back empty, which is the default (`IN_APP` is never configurable, and `PUSH` only shows up once the server has an FCM service account); the per-team mute switches still are, since muting a team also empties the inbox of its announcements — the section disappears, header included, only with neither channel nor team. The daily-digest switch shows only when `EMAIL` is a channel. Two other invariants hold there: the API carries **no rendered text**, so the wording, the icon and the destination are the client's (`presentation/notification_display.dart`), and the **destination comes from `subjectType`, never from `type`** — an unknown subject renders a line that simply isn't tappable, rather than a `go` to a route that doesn't exist. The badge polls `unread-count` at most once a minute (`kUnreadPollInterval`) and stops with the session
- **Push is opt-in from the inbox, and the app never asks at launch** — `PushController`
  (`features/notifications/providers/push_provider.dart`) registers a token *only* once the member
  grants permission, and `PushActivationBanner` only offers to ask when **`PUSH` is in
  `NotificationPreferencesDto.channels`**, i.e. when the server can actually send. The system
  dialog appears once in the life of an installation: spending it at launch, before the member has
  seen what the app notifies about, spends it badly. Two more rules hold there: a tapped
  notification opens `data.path` **as the server computed it** (never a route rebuilt from the
  subject) and goes through the *same* `pendingPushRouteProvider` → `main.dart` waiting logic as a
  web link, so the back stack is rebuilt; and nothing above `PushGateway` touches Firebase, which
  is what lets `push_test.dart` run at all
- **Attachments render through `core/widgets/media_attachments.dart`, everywhere** — the eight screens carrying a `MediaDto` (ride, post, ad, route, trip, stage, team page, about) share one `MediaAttachments`. The three hand-rolled copies it replaced had already drifted: the ride's listed the files with **no button**, naming an attachment while giving no way to open it. Attachments only arrive in the full view — a `COMPACT` list doesn't carry them, which is why no card shows files
- **An attachment is never handed to the browser** — `AssetDto.url` is `/api/download/{visibility}/…` and its authorisation is the *carrying* entity's, so an untokened request to a team-visible ride, ad or page is refused: `openLink` would open a tab on a 403. Fetch it with the authenticated `dioProvider` and hand the file to the system through `core/utils/share_file.dart` — the one path for attachments and a route's GPX/FIT export: on Android a `PdlSheet` offers « Enregistrer sur le téléphone » (the system save dialog, `FilePicker.saveFile`) or « Envoyer vers une autre app » (`SharePlus`), because many Android share sheets (HyperOS…) offer no save target; iOS goes straight to the share sheet, which has « Enregistrer dans Fichiers ». The file carries its real MIME type (`application/gpx+xml`, `application/vnd.ant.fit`) — the `mime` package knows neither, and `octet-stream` hides the GPS apps. An **image** attachment (`imageUrl != null`) is looked at *in* the app, in `PdlImageViewer` on the 1920 variant; the button then downloads the **original**, which is the one thing the viewer doesn't give
- **No waiting list**: "full" is a terminal state. Don't wire a hardcoded `waitlisted: false`
- **Units always go through the single formatter** driven by `UserDto.unitSystem` (`core/units/`, `core/utils/formatters.dart`) — never a hardcoded `km`
- **Pagination is offset-based** (`PagedListNotifier`, dedup by `itemKey`). Cursor pagination isn't in the contract, and the mocked list footer ("60 members of 1,999") needs the `total` a cursor doesn't provide. See ledger `API-21` before changing this
- **Timestamps render in the user's timezone, else the device's; rendezvous in the entity's** (ledgers `API-15`, `API-60`). A *timestamp* (creation, comment, notification received, « il y a 2 h », an ad's date) goes through `AppFormatters.toDisplayTime` / `tryParseDisplayTime`, in `UserDto.timezone` when set (`app.dart` hands it to `AppFormatters.setDisplayTimezone`). A *rendezvous* (ride, group, stage departure, estimated return, trip dates, a post's date) goes through `toZoneTime` / `tryParseZoneTime` with the entity's `timezone` (`RideDto.timezone`…), and shows `ZoneMentionLine` / `formatZoneMention` — « heure de Tokyo (ven. 01:00 chez vous) » — which renders nothing when the offsets match at that instant. **Never `.toLocal()`**, and "now" goes through `AppFormatters.displayNow()`, never `DateTime.now()`, wherever it is compared with a converted date. The converted value is a *wall clock* (a local `DateTime` carrying that zone's fields): convert **once**, then hand it to the formatters, which leave a non-UTC value alone; it is fine for formatting, wrong for comparing instants — compare the contract's values (a relative « dans 2 jours » takes the contract instant). « Aujourd'hui », « demain », the calendar grid and grouping by day stay the reader's. A group's time is `startAt` in the ride's zone (`formatGroupStart`), never the raw `time`. Two more rendezvous read in the entity's zone: weather times (leg start and arrival, checkpoint passages, the rain alert, the timeline hours, sunrise and sunset), **with no mention**, go through `formatWeatherTime` / `formatRainAlert` with the ride's or stage's `timezone` — on a trip's card, `RideWeatherSummaryDto.timezone` (its next stage's) wins over `TripDto.timezone` — never the display zone; and a notification's subject date (`NotificationDto.subjectDateTime`) goes through `subjectDateLine` / `formatRendezvous` in `subjectTimezone`, with the mention (a notification sent before that column existed has none and reads in the reader's zone), while its `createdAt` stays a timestamp. 12 h / 24 h follows the phone (`MediaQuery.alwaysUse24HourFormat` → `AppFormatters.setUse24HourFormat`), not the language. A month boundary sent back to the API goes through `displayWallClockToUtc`
- **The elevation profile is derived from `tracks[].line`, and there is no endpoint for it.** Since API 2.0.0 the geometry is served exactly as stored (no `simplify`/`points`), so every coordinate carries `[lon, lat, ele, cumulativeDistance]` — everything a profile needs, at higher resolution than the removed `/elevation-profile` gave. Build it with `elevationSamplesFromLines` (`features/routes/domain/route_elevation_builder.dart`), which goes through `PolylineIndex`: that is what keeps the profile's x-axis and the map cursor on the *same* distances, including the haversine bridge between the tracks of a multi-track route. **Memoize the `ElevationSamples` in a provider** — `ElevationBarsPainter.shouldRepaint` compares by `identical`, so rebuilding it inside `build()` repaints every frame. Ask for `geometry: false` on `getRoutesBulk` when a screen names routes without drawing them

## Detailed Guidelines

`lib/core/pdl/README.md` is the authority on the component library (contract, naming, what not to
port). `../docs/LEDGER_NEXT.md` lists what's left and what was ruled out.

See `RULES.md` for the project's Flutter/Dart conventions: Riverpod patterns, generated-code
workflow, logging, testing and accessibility. Visual design lives in `lib/core/pdl/README.md`,
not in `RULES.md`.
