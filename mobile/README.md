# Pedalons Mobile

Flutter mobile app for the Pedalons cycling team platform.

## Prerequisites

- Flutter SDK whose bundled Dart satisfies `sdk: ^3.10.4` (`pubspec.yaml`)
- iOS: a recent Xcode — the e2e scripts target an "iPhone 17 Pro Max" simulator (`tool/e2e_env.sh`)
- Android: Android Studio with SDK 21+ (for Android development)

## Setup

```bash
# Install dependencies
flutter pub get
```

Then generate the API client and the models — see [Code Generation](#code-generation). `./check.sh`
does both, then formats, analyzes and runs the tests.

## Development

### iOS Simulator

```bash
# List available simulators
xcrun simctl list devices

# Start a specific simulator
open -a Simulator

# Or boot a specific device
xcrun simctl boot "iPhone 15 Pro"

# Run app on iOS simulator
flutter run -d iphone
```

### Android Emulator

```bash
# List available emulators
emulator -list-avds

# Start an emulator
emulator -avd <emulator_name>

# Or via Android Studio: Tools > Device Manager > Start

# Run app on Android emulator
flutter run -d android
```

### Physical iPhone

1. Connect iPhone via USB
2. On iPhone: Settings > Privacy & Security > Developer Mode > Enable
3. Trust the computer when prompted
4. In Xcode: Preferences > Accounts > Add Apple ID (for signing)
5. Open `ios/Runner.xcworkspace` in Xcode, select your Team in Signing & Capabilities

```bash
# Run on connected iPhone
flutter run -d <device_id>

# Or let Flutter pick the device
flutter run
```

### Physical Android

1. On device: Settings > About phone > Tap "Build number" 7 times (enables Developer options)
2. Settings > Developer options > Enable "USB debugging"
3. Connect device via USB, accept "Allow USB debugging" prompt

```bash
# Run on connected Android device
flutter run -d <device_id>

# Or let Flutter pick the device
flutter run
```

### General Commands

```bash
# List all available devices
flutter devices

# Run on a specific device
flutter run -d <device_id>

# Run with custom API URL
flutter run --dart-define=API_BASE_URL=http://localhost:8080

# Run tests
flutter test

# Static analysis
flutter analyze
```

## Release Builds

`flutter build appbundle`/`flutter build apk` always prefer the JDK bundled with the latest Android
Studio install over `JAVA_HOME` — exporting `JAVA_HOME` alone has no effect on the JDK Gradle runs
with. If Android Studio ships a JDK newer than what the Gradle/AGP version in `android/` supports
(e.g. JDK 25), the build fails with a cryptic error whose message is just the JDK version number
(e.g. `25.0.2`). Force Flutter to use a specific JDK instead:

```bash
flutter config --jdk-dir="$(/usr/libexec/java_home -v 21)"
```

This is a persistent Flutter setting (not per-shell), so it only needs to be run once per machine.

## Code Generation

After modifying models or when the backend API changes:

```bash
# Regenerate API client from OpenAPI spec
dart run openapi_retrofit_generator

# Regenerate freezed/json models
dart run build_runner build
```

## Project Structure

```
lib/
├── api/               # HTTP client, interceptors, generated API
├── config/            # Router, paths, app configuration
├── core/              # Shared widgets and utilities
└── features/          # Feature modules (auth, teams, rides, routes, etc.)
```

## Configuration

Environment variables via `--dart-define`:

| Variable | Default | Description |
|----------|---------|-------------|
| `API_BASE_URL` | `https://www.pedalons.fr` | Backend API URL |
| `WEBAUTHN_RP_ID` | `www.pedalons.fr` | WebAuthn Relying Party ID |
| `DEEP_LINK_HOST` | `www.pedalons.fr` | Deep link host |
| `SCREENSHOTS` | `false` | Store-screenshot mode (see [screenshots/README.md](screenshots/README.md)) |
| `ENABLE_FLUTTER_DRIVER` | `false` | Lets the Dart/Flutter MCP server drive the build (disables real keyboard input; see `CLAUDE.md`) |
| `REPORT_ERRORS_IN_DEBUG` | `false` | Send error reports from a debug build too |

## Scripts

| Script | Purpose |
|--------|---------|
| `check.sh` | Regenerate, format, analyze, test |
| `clean.sh` | Clean both platforms, reinstall and regenerate |
| `e2e.sh` | Patrol end-to-end tests against the e2e stack — see [patrol_test/README.md](patrol_test/README.md) |
| `publish_test.sh` | Bump the build number, upload to TestFlight (`fastlane beta`) and to the Play internal track (`fastlane internal`) |
| `publish_beta.sh` | Same, for beta testers: external TestFlight group NP (after Apple's beta review) and Play closed testing (`fastlane beta external:true`, `fastlane closed`) |

## Related Documentation

- [CLAUDE.md](CLAUDE.md) - AI assistant guidance for this codebase
- [RULES.md](RULES.md) - Flutter/Dart coding standards and best practices
- [patrol_test/README.md](patrol_test/README.md) - Patrol end-to-end tests
- [store-metadata/README.md](store-metadata/README.md) - Store listings, privacy declarations
- [screenshots/README.md](screenshots/README.md) - Store screenshots
- [docs/APP_LINKS.md](../docs/APP_LINKS.md) - Deep links and passkeys (`.well-known` files, signing fingerprints)
- [../CLAUDE.md](../CLAUDE.md) - Full project documentation (backend, frontend, mobile, karoo)
