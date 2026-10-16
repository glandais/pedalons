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

# Full gate: format + assembleDebug
bash check.sh
```

## Architecture

```
app/src/main/kotlin/fr/pedalons/karoo/
├── PedalonsExtension.kt  # KarooExtension service entry point (bonus action handler)
├── MainActivity.kt       # Route browser UI (Compose)
├── auth/
│   ├── AuthActivity.kt       # Device code flow UI (QR code + polling)
│   ├── GpsConnectActivity.kt # QR code to the profile page, to connect the Hammerhead account (OAuth)
│   └── AuthManager.kt        # Token storage via DataStore
├── api/
│   ├── PedalonsApiClient.kt  # Ktor HTTP client with Karoo engine
│   └── Models.kt             # Kotlinx serialization data classes
└── ui/theme/
    └── Theme.kt          # Dark theme for outdoor visibility
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
- Client created in Activities after system service connects

**Home screen and navigation (`MainActivity.kt`):**
- `NavState` is a stack-based state machine driven by the Karoo keys (`onKeyDown` → callbacks).
- Home lists `homeEntries()`: « My next rides » (`registeredGroups`) always first, then Rides and
  Routes (Routes first when there is no ride). An empty entry stays visible with its empty text.
- Selecting a registered group syncs its route straight away (no route detail screen); the status
  shows on the row. The sync itself is `launchSync`, shared with the route detail screen.
- `registeredGroups` defaults to an empty list, so an older backend still parses.

**Token Storage:**
- DataStore preferences for access/refresh tokens
- Auto-refresh when token expires (5-minute buffer)

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
| `GET /api/device/routes` | Rides, standalone routes, and the groups the user is registered in (`registeredGroups`, API 11.4.0) |
| `POST /api/device/routes/{teamSlug}/{routeSlug}/sync?type=hammerhead` | Sync route to Karoo |

## String Resources

Localized strings in `app/src/main/res/values/strings.xml` and `values-fr/strings.xml`.
