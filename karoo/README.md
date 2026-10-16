# Pédalons Karoo Extension

Hammerhead Karoo extension for syncing routes from Pédalons directly to your device.

## Features

- Browse your upcoming registrations (« My next rides »), the upcoming rides of your Pédalons teams
  and their routes
- One-tap sync to Karoo, with each route's state at Hammerhead (already on the Karoo, older version…)
- Device code authentication (no typing on Karoo)
- Hammerhead account connection from the Karoo (QR code to the Pédalons profile page), required
  to sync routes
- Automatic token refresh

## Requirements

- Hammerhead Karoo (new generation, not Karoo 2)
- Pédalons account with team membership

## Installation

Download `pedalons.apk` from the [`karoo-latest`](https://github.com/glandais/pedalons/releases/tag/karoo-latest)
release (every version is a `karoo.X.Y.Z` [release](https://github.com/glandais/pedalons/releases?q=karoo)),
then either:

- share the APK link to the [Hammerhead Companion app](https://support.hammerhead.io/hc/en-us/articles/31576497036827)
  and confirm « Install » on the Karoo — the Karoo then offers later updates itself; or
- sideload it with ADB: `adb install -r pedalons.apk`.

## Usage

1. Open the Pédalons app on your Karoo and tap "Connect"
2. Scan the QR code with your phone, or go to `pedalons.fr/karoo` and enter the code shown
3. Log in to your Pédalons account and authorize the Karoo
4. Link your Hammerhead account when the Karoo asks for it (a second QR code)
5. Pick a ride, a route or one of your next rides, and sync it to your Karoo

## Authentication

The app uses the OAuth Device Code flow (RFC 8628), since Karoo devices don't have a keyboard:

1. The app requests a device code from the server
2. The Karoo displays a QR code and a 6-character code
3. The user scans the QR code (which carries the code), or visits `pedalons.fr/karoo` and enters it
4. The user authenticates with their Pédalons account
5. The app polls until authentication completes
6. Tokens are stored on the device (DataStore) and refreshed before they expire

## Development

Prerequisites: JDK 17+ and the Android SDK. A fresh checkout has no `local.properties` (it is
gitignored): create it with `sdk.dir=/path/to/Android/Sdk`, or set `ANDROID_HOME`.

`ktor-client-karoo` is hosted on GitHub Packages, which needs authentication even for reads. Put a
GitHub token with the `read:packages` scope in `~/.gradle/gradle.properties`:

```properties
gpruser=YOUR_GITHUB_USERNAME
gprkey=YOUR_GITHUB_TOKEN
```

```bash
./gradlew installDebug       # build and install on the Karoo connected over ADB
./gradlew assembleDebug      # debug APK only
bash check.sh                # local gate: format + assembleDebug
```

The app talks to production (`https://www.pedalons.fr`, `BASE_URL` in `MainActivity.kt`), debug
builds included.

A local `assembleRelease` is signed only if `keystore.properties` exists (template:
`keystore.properties.example`). Real releases are built by CI from a `karoo.X.Y.Z` tag — see
[PUBLISH.md](PUBLISH.md) for the release process, the manifest Karoo devices poll for updates, and
the Hammerhead Extensions Library.

Code layout, patterns and the API endpoints used are described in [CLAUDE.md](CLAUDE.md).

### Key Dependencies

- [karoo-ext](https://github.com/hammerheadnav/karoo-ext) - Karoo Extension SDK
- [ktor-client-karoo](https://github.com/jonasfranz/ktor-client-karoo) - HTTP client engine for Karoo
- Jetpack Compose - UI framework
- Kotlinx Serialization - JSON parsing

### Notes

- HTTP requests go through Karoo System Service (required for network access)
- Response size limited to 100KB by Karoo System Service
- Dark theme optimized for outdoor visibility on Karoo display

## License

[PolyForm Noncommercial 1.0.0](LICENSE)
