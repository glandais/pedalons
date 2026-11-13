# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Karoo extension for the Pédalons cycling team platform. Allows Hammerhead Karoo device users to browse and sync routes from their Pédalons teams directly to their device.

## Commands

```bash
# Build
./gradlew assembleDebug            # Build debug APK
./gradlew assembleRelease          # Build release APK (requires signing)

# Install on device
./gradlew installDebug             # Install via ADB on connected Karoo
adb install -r app/build/outputs/apk/debug/app-debug.apk  # Manual install

# Clean
./gradlew clean

# Format (Spotless + ktfmt, kotlinlang style)
../format.sh karoo                 # or: ./gradlew spotlessApply — run before every commit

# Full gate: format + assembleDebug + tests and screenshot goldens (see « Tests »)
bash check.sh
```

## Architecture

```
app/src/main/kotlin/fr/pedalons/karoo/
├── PedalonsExtension.kt  # KarooExtension service entry point (reports BuildConfig.VERSION_NAME)
├── MainActivity.kt       # Thin: builds MainViewModel, maps keys (KarooKey), result launchers, effects
├── KarooKey.kt           # The 4 hardware keys
├── browse/
│   ├── Navigation.kt     # NavState (+ RouteDetail.of), HomeEntry, homeEntries, SyncState, routeKey
│   ├── BrowseState.kt    # Pure, immutable: selection, stack, sync; transitions -> BrowseStep(state, outcome)
│   ├── MainUiState.kt    # MainUiState + screen() precedence (SKELETON/CONNECT/ERROR/EMPTY/CONTENT)
│   ├── MainViewModel.kt  # Startup, loads, syncs, sign-in/out; StateFlow + effects Channel
│   └── ui/               # MainRoute (root), then one file per screen: HomeScreen, RegisteredGroupListScreen,
│                         # RideListScreen, RideEntriesScreen, RouteListScreen, RouteDetailScreen,
│                         # StatusScreens (Connect/Error/Empty/Skeleton)
├── auth/
│   ├── AuthActivity.kt       # Device code flow (QR code + polling)
│   ├── AuthScreens.kt        # Stateless auth screens + shared ConnectingScreen
│   ├── GpsConnectActivity.kt # Hammerhead step: polls /me, follows the account
│   ├── GpsConnectContent.kt  # Stateless UI of that step (QR to the Hammerhead step only, never the profile; logout)
│   ├── QrCode.kt             # generateQrCode
│   ├── AuthManager.kt        # TokenStore on DataStore (plain app-private storage)
│   ├── Session.kt            # Token policy: refresh behind a Mutex (SEC-11 rotation)
│   ├── DeviceCodeLogin.kt    # RFC 8628 loop (state + run), started from a LaunchedEffect
│   └── HammerheadLinkWatcher.kt # Polls /me every 5 s until Hammerhead is linked
├── data/
│   ├── PedalonsRepository.kt # Typed results: RoutesResult, HammerheadStatus, SyncResult
│   └── DeviceAuthRepository.kt # DeviceCodeResult, DevicePoll
├── system/
│   └── KarooConnection.kt    # Karoo system service + API client, shared by the 3 activities
├── api/
│   ├── PedalonsApiClient.kt  # Ktor HTTP client with Karoo engine
│   └── Models.kt             # Kotlinx serialization data classes
└── ui/
    ├── Formatters.kt         # The shared formats: formatDeparture / formatZoneMention / formatDistance / formatElevationGain
    ├── ZoneLabel.kt          # The city naming a time zone (port of mobile's zone_label.dart)
    ├── GroupTitle.kt         # « Groupe B » for a one- or two-character group name
    ├── components/           # ScreenScaffold (overlay, back/sync, top bar), ListRows (SelectableRow...)
    └── theme/Theme.kt        # Dark theme for outdoor visibility
```

## Key Patterns

**Device Code Flow Authentication:**
- No keyboard on Karoo, uses OAuth Device Code flow (RFC 8628)
- Shows QR code + 6-character user code
- User authenticates on phone/computer at `<site>/karoo?code=…` (`verificationUriComplete`, built by
  the backend's `DeviceAuthService` — each device has its own page)
- App polls `/api/device/oauth/token` until authorized

**HTTP via Karoo System Service:**
- Uses `ktor-client-karoo` which routes HTTP through Karoo System Service
- Requires `KarooSystemService.connect()` before making API calls
- Client created by `KarooConnection.connect()` (system/), shared by the 3 activities, after the system service connects

**Home screen and navigation (`browse/`):**
- Flow: key or touch -> `MainActivity`/`MainRoute` -> a `MainViewModel` method -> a pure
  `BrowseState` transition returning `BrowseStep(state, outcome)` -> the VM assigns the state on the
  main thread, then runs the outcome (`StartSync`, `Finish`). `MainViewModel` owns the startup
  (Hammerhead check, then the first load: a 401 clears the tokens), Retry/Refresh (a 401 keeps them)
  and the syncs; `MainActivity` only forwards keys, activity results and collects `effects`.
- `NavState` is a stack-based state machine driven by the Karoo keys (`KarooKey` -> `onKey`). Keys act
  on `BrowseState` whatever `MainUiState.screen()` shows, and are ignored until the Karoo system
  service is connected.
- Home lists `homeEntries()`: « My next rides » always first, then Rides and
  Routes (Routes first when there is no ride). An empty entry stays visible with its empty text.
- « My next rides » is `RoutesResponse.registeredItems()`: the ride groups (`registeredGroups`) and
  the stages of the trips the user is registered for (`registeredStages`, API-168), both
  `RegisteredItem`, mixed by departure. The stages only come because `getRoutes` sends
  `stages=true`; the Garmin app does not, and its response must stay without them. The home entry
  counts registrations (`registrationCount()`: one per trip, whatever its stages).
- Selecting a registered row syncs its route straight away (no route detail screen); the status
  shows on the row. The sync is `BrowseState.sync`, shared with the route detail screen (one at a time; a result only
  shows while its generation is current, but a success is always recorded in `syncedRoutes`).
- `registeredGroups` defaults to an empty list, so an older backend still parses.
- An idle row shows where its route stands at Hammerhead (`syncStatuses`, API-121: already on the
  Karoo / older version / update pending / sending failed / reconnect). The field is nullable:
  absent (older backend) means « unknown », not « not sent »; unknown states are ignored rather than
  failing the parse. A route synced from the Karoo since the response was loaded (`syncedRoutes`,
  reset with every new response) shows as on the Karoo, the server state being older than it.

**Formats and words — the app's and the site's (API-191):**
- Every number and date goes through `ui/Formatters.kt`; never a format in `strings.xml` or in a
  screen. The rules are `docs/BRANDING.md` §8.3 and KIT §9 (« Ce qui vaut pour l'app Karoo », which
  also lists the Karoo's deliberate differences); `FormatCasesTest` reads
  `contracts/format-cases.json`, the cases the app and the site read too.
- A departure is « sam. 14 nov. · 09:30 » (« Aujourd'hui », « Demain », the year outside the current
  one), **in the ride's zone** (`timezone` of the DTO), followed by « heure de Tokyo (ven. 01:00 chez
  vous) » when the Karoo is at another offset. 24 h in French, 12 h in English: the language
  decides, not the Karoo's 12/24 setting.
- « 42,0 km », « 1 240 m D+ »: no-break space (U+00A0) before the unit and between thousands.
- Counters are `plurals`; a group named by one or two characters reads « Groupe B » (`groupLabel`).
- `FormatClock` is the « now » of the relative days: the tests and the goldens freeze it
  (`TEST_NOW`), otherwise « Tomorrow » changes a golden from one day to the next.

**Token Storage:**
- DataStore preferences for access/refresh tokens
- `Session` refreshes an expired token behind a Mutex (single flight), using `AuthManager`'s `isUsable` rule (5-minute buffer)

## Critical Constraints

- **100KB response limit**: Karoo System Service limits HTTP response size. Keep route DTOs lightweight (~200 bytes each).
- **New Karoo only**: `ktor-client-karoo` only works on new Karoo devices, not Karoo 2.
- **Dark theme required**: Karoo display is used outdoors, dark theme improves visibility.
- **Java 11 target**: Build targets Java 11 for Karoo compatibility.
- **No wildcard imports**: Follow Hammerhead SDK guidelines.

## Build Toolchain

Aligned with the `karoo-rain-radar` project. Versions live in `gradle/libs.versions.toml`
and `gradle/wrapper/gradle-wrapper.properties` (Gradle, AGP 9, Kotlin — dependabot bumps them;
read them there rather than trusting a copy):
- `compileSdk 37`, `minSdk 26`, `targetSdk 32` (Karoo runs Android 12), Java 11 bytecode
- Kotlin is compiled via **AGP 9 built-in Kotlin** — there is no standalone
  `org.jetbrains.kotlin.android` plugin, and `gradle.properties` does not opt out of the
  new DSL. The Kotlin JVM target is derived from `compileOptions` (Java 11); do not re-add
  an explicit `kotlin { jvmTarget }` block.

## Dependencies

Key dependencies (versions in `gradle/libs.versions.toml`):
- `karoo-ext`: Hammerhead Karoo Extension SDK
- `ktor` + `ktor-client-karoo`: Routes HTTP through Karoo System Service
- `compose-bom`: Jetpack Compose for UI
- `datastore`: Token persistence
- `zxing`: QR code generation

## GitHub Packages Authentication

`ktor-client-karoo` is hosted on GitHub Packages. Configure in `~/.gradle/gradle.properties`:
```properties
gpruser=YOUR_GITHUB_USERNAME
gprkey=YOUR_GITHUB_TOKEN
```

## Release

Pushing a tag matching `karoo.X.Y.Z` (e.g. `karoo.1.2.3`) triggers
`.github/workflows/karoo-release.yml`, which builds a signed release APK and publishes it
as a GitHub Release (see [PUBLISH.md](PUBLISH.md)). `versionCode`/`versionName` are
derived from the tag at build time (`major*10000 + minor*100 + patch`), not from
`app/build.gradle.kts` — the hardcoded `1`/`1.0.0` there only apply to local builds.

```bash
git tag karoo.1.2.3
git push origin karoo.1.2.3
```

Signing secrets (`KAROO_KEYSTORE_BASE64`, `KAROO_KEYSTORE_PASSWORD`, `KAROO_KEY_ALIAS`,
`KAROO_KEY_PASSWORD`) live in the repo's GitHub Actions secrets, alongside `GPR_USER`/
`GPR_KEY` used for GitHub Packages auth.

## API Endpoints Used

| Endpoint | Purpose |
|----------|---------|
| `POST /api/device/oauth/device` | Request device code for auth |
| `POST /api/device/oauth/token` | Poll for tokens / refresh token |
| `GET /api/device/me` | Connected GPS services (is Hammerhead connected?) |
| `GET /api/device/routes?stages=true` | Rides, standalone routes, the groups the user is registered in (`registeredGroups`, API 11.4.0) and, because of `stages=true`, the stages of their trips (`registeredStages`, API 14.10.0) |
| `POST /api/device/routes/{teamSlug}/{routeSlug}/sync?type=hammerhead` | Sync route to Karoo |

## Tests

Harness that pinned the app's behaviour during the refactor (ViewModels, repositories, files), which
has landed; it now guards the new code. `StartupAndAuthFlowTest.coldStartWithAnExpiredToken_targetIsOneOfEach`
passes: the owner can remove its `@Ignore` and delete the characterization ceiling test. JVM only — Robolectric, no device, no network. Everything runs
through one command, which is also the end of `check.sh` and the karoo job of `ci.yml`:

```bash
./gradlew verifyRoborazziDebug     # unit + behaviour tests, then the screenshot goldens are compared
./gradlew recordRoborazziDebug     # re-records the goldens (app/src/test/screenshots/{en,fr}/*.png)
./gradlew testDebugUnitTest --tests '*SyncTest*'   # one class, no pixel comparison
```

| Layer | Where (`app/src/test/kotlin/fr/pedalons/karoo/`) | Pins |
|---|---|---|
| API contract | `api/PedalonsApiClientTest`, `api/ModelsTest` | method, URL, bearer, JSON body (API-65 `clientId`), status -> result mapping, older-backend payloads (Ktor MockEngine) |
| Pure logic | `HomeEntriesTest`, `FormattersTest`, `FormatCasesTest`, `ZoneLabelAndGroupTitleTest`, `ModelsTest`, `auth/QrCodeTest` | `homeEntries`, `startOf`, `registeredItems`, sync states, units, departures in the ride's zone, the formats shared with the app and the site (`contracts/format-cases.json`) |
| Plain JVM | `browse/BrowseStateTest`, `browse/MainUiStateTest`, `browse/MainViewModelTest`, `browse/RouteDetailFactoryTest`, `auth/SessionTest`, `auth/DeviceCodeLoginTest`, `auth/HammerheadLinkWatcherTest`, `auth/TokenExpiryTest`, `data/PedalonsRepositoryTest` (with `support/FakeTokenStore`, `support/TestClock`) | reducer, screen precedence, startup/sign-in sequence (one session per sign-in), single-flight refresh, RFC 8628 loop, repository result mapping |
| Behaviour | `StartupAndAuthFlowTest`, `NavigationTest`, `SyncTest`, `auth/*ActivityTest` | the real activities driven by the Karoo keys and touch against a `FakeBackend`: texts shown, HTTP requests made, tokens stored, activities started |
| Pixels | `screenshots/ScreenshotCases` (run in `en` and `fr`) | every screen on 480x800 px at 300 dpi (the Karoo's own `wm size` / `wm density`), Android 12 |

- Behaviour tests go through `MainActivity` / `AuthActivity` / `GpsConnectActivity` and the
  `support/` helpers (`AppTestBase`, `FakeBackend`, `ShadowKarooSystemService`), never through
  internal state, so they survive moving code around. A test whose name or comment starts with
  `CHARACTERIZATION:` pins behaviour that looks like a bug — do not « fix » it in a refactor without
  changing the test on purpose.
- Test seams in `src/main` (no behaviour): `PedalonsApiClient` takes any Ktor engine through an
  `internal` constructor and `engineFactoryForTests` (null in production); the screens and
  formatters the tests call are `internal` rather than `private`. The screenshot test calls the screens
  by name: after a refactor, adapt the calls, **not** the images.
- **Goldens are re-recorded only for an intended visual change.** A failing `verifyRoborazziDebug`
  after a refactor is a regression: look at `app/build/outputs/roborazzi/*_compare.png` first.
  Goldens are recorded on Linux x86_64 (Robolectric native graphics); do not record them elsewhere.
- Robolectric downloads its Android 12 jar from Maven Central on the first run.

## String Resources

Localized strings in `app/src/main/res/values/strings.xml` and `values-fr/strings.xml`.
