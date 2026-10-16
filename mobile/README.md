# Pedalons Mobile

Flutter app for the Pedalons cycling team platform (iOS and Android). Architecture, patterns and
gotchas are in [CLAUDE.md](CLAUDE.md), coding standards in [RULES.md](RULES.md), and the design
system's contract in [lib/core/pdl/README.md](lib/core/pdl/README.md).

## Prerequisites

- A Flutter SDK whose bundled Dart satisfies `sdk: ^3.10.4` (`pubspec.yaml`)
- iOS: Xcode — the e2e scripts target an "iPhone 17 Pro Max" simulator (`tool/e2e_env.sh`)
- Android: Android Studio and its SDK (`minSdk` is Flutter's default)

## Setup and everyday commands

```bash
bash check.sh        # pub get, both generators, ../format.sh mobile, analyze, test — the full gate

flutter devices                  # list simulators, emulators and connected devices
flutter run -d <device_id>       # run on one of them
flutter test
flutter analyze
```

The app talks to **production** (`https://www.pedalons.fr`) unless told otherwise. To use the dev
backend of the [root Quick Start](../README.md#quick-start):

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

A debug Android build allows plain HTTP to `localhost` and `127.0.0.1` only
(`android/app/src/debug/res/xml/network_security_config.xml`), so from an emulator or device
forward the port with `adb reverse tcp:8080 tcp:8080`. Any other hostname, such as a LAN IP, needs
its own `domains` row in the backend — see
[Default domain and platform admin](../README.md#default-domain-and-platform-admin).

On a physical iPhone, enable Developer Mode on the device and pick a signing team in
`ios/Runner.xcworkspace` (Signing & Capabilities) before the first `flutter run`.

## Code generation

When `contracts/openapi.yaml` changes, or after editing a freezed model (`check.sh` runs both):

```bash
dart run openapi_retrofit_generator   # API client → lib/api/generated/ (openapi_generator.yaml)
dart run build_runner build           # freezed / json_serializable / retrofit code
```

## Configuration

Build-time values, via `--dart-define`:

| Variable | Default | Description |
|----------|---------|-------------|
| `API_BASE_URL` | `https://www.pedalons.fr` | Backend API URL |
| `WEBAUTHN_RP_ID` | `www.pedalons.fr` | WebAuthn Relying Party ID |
| `DEEP_LINK_HOST` | `www.pedalons.fr` | Deep link host |
| `SCREENSHOTS` | `false` | Store-screenshot mode (see [screenshots/README.md](screenshots/README.md)) |
| `ENABLE_FLUTTER_DRIVER` | `false` | Lets the Dart/Flutter MCP server drive the app; disables real keyboard input (see [CLAUDE.md](CLAUDE.md#agent-tooling)) |
| `REPORT_ERRORS_IN_DEBUG` | `false` | Send error reports from a debug build too |

## Project structure

```
lib/
├── api/          # HTTP client, interceptors, generated API (api/generated/)
├── config/       # Router, paths (paths.generated.dart), app configuration
├── core/         # Design system (core/pdl), theme, units, shared widgets and utilities
├── features/     # Feature modules (auth, teams, rides, routes, trips, posts, ads…)
├── screenshots/  # Store-screenshot mode
└── dev/          # Design-system gallery and demo pages
patrol_test/      # Patrol end-to-end tests
test/             # Unit and widget tests
```

## Scripts

| Script | Purpose |
|--------|---------|
| `check.sh` | Regenerate, format, analyze, test |
| `clean.sh` | Clean both platforms, reinstall and regenerate |
| `e2e.sh` | Patrol end-to-end tests against the e2e stack — see [patrol_test/README.md](patrol_test/README.md) |
| `publish_test.sh` | Bump the build number, upload to TestFlight (`fastlane beta`) and to the Play internal track (`fastlane internal`), then commit the bump |
| `publish_beta.sh` | Same, for beta testers: external TestFlight group NP (after Apple's beta review) and Play closed testing (`fastlane beta external:true`, `fastlane closed`); then tags `mobile.X.Y.Z.N`, which publishes a signed APK for devices without Google Play (below) |

## Release builds and the JDK

`flutter build appbundle`/`flutter build apk` prefer the JDK bundled with Android Studio over
`JAVA_HOME`, so exporting `JAVA_HOME` alone does not choose the JDK Gradle runs with. If that JDK is
newer than what the Gradle/AGP version in `android/` supports, the build fails with a cryptic error
whose message is just the JDK version number. Pin a JDK once per machine (a persistent Flutter
setting, not per shell):

```bash
flutter config --jdk-dir="$(/usr/libexec/java_home -v 21)"   # macOS; elsewhere, the JDK 21 path
```

## APK without Google Play

The tag `mobile.X.Y.Z.N` (pushed by `publish_beta.sh` after its commit) triggers
`.github/workflows/mobile-release.yml`: a universal APK built from that commit, signed with the
**Karoo key** (secrets `KAROO_KEYSTORE_*`), published on a release of that tag with the version's
whatsNew, and copied to the fixed release `mobile-latest`, the target of the « APK sans Google
Play » buttons (site and app). The workflow fails if the tag does not match `pubspec.yaml`, if
`metadata/version/X.Y.Z/` lacks its whatsNew, or if the APK ends up signed with the debug key.

- Play App Signing re-signs Store builds: an APK install and a Play install never update each other.
- Never change that key: every APK install would stop accepting updates.
- `mobile-latest` is never marked "Latest" and never deleted.
- The key's fingerprint is in `frontend/public/.well-known/assetlinks.json` (App Links, passkeys).
- Without Google Play Services, Firebase fails softly (`main.dart`, `push_gateway.dart`): no FCM
  token, so no push; the rest of the app is unaffected.

## Related documentation

- [patrol_test/README.md](patrol_test/README.md) — Patrol end-to-end tests
- [store-metadata/README.md](store-metadata/README.md) — store listings, privacy declarations
- [screenshots/README.md](screenshots/README.md) — store screenshots
- [docs/APP_LINKS.md](../docs/APP_LINKS.md) — deep links and passkeys (`.well-known` files, signing fingerprints)
- [docs/BRANDING.md](../docs/BRANDING.md) — brand charter; Flutter theme in `lib/core/theme/`
