# Pédalons Garmin Connect IQ App

A Garmin Connect IQ app for Edge cycling computers: browse the upcoming rides and the routes of your
teams, and download routes to the device.

## Features

- **My next rides**: the groups you are registered in, one select away from downloading their route,
  with whether that route is already in Garmin Connect
- Browse the upcoming rides of all your teams, and the routes attached to them
- Browse the routes of all your teams that are not attached to a ride, sorted by proximity to the
  current location
- Download routes as FIT files directly to the Edge
- Device Code Flow login (no keyboard needed), logout from the home menu
- English and French

## Supported Devices

edge530, edge540, edge550, edge830, edge840, edge850, edge1030, edge1030bontrager, edge1030plus,
edge1040, edge1050, edgeexplore2, edgemtb — Connect IQ API 3.3.0 or higher (`minApiLevel`).

The list lives in `manifest.xml` and in `DEVICES` in the `Makefile`: change both together.

## Setup

You need Docker (or Podman), or a native Connect IQ SDK, and a free
[Garmin developer account](https://developer.garmin.com/).

### SDK (Docker-based)

On Ubuntu 24.04+ the official SDK Manager and simulator need webkit2gtk-4.0, which is no longer
packaged (the SDK Manager shows a blank window, the simulator fails on
`libwebkit2gtk-4.0.so.37`). `Dockerfile.sdk-manager` runs them on Ubuntu 22.04 instead:

```bash
cd garmin-app
docker build -t garmin-sdk-manager -f Dockerfile.sdk-manager .

xhost +local:docker
docker run -it --rm \
  --ipc=host \
  -e DISPLAY=$DISPLAY \
  -e WEBKIT_DISABLE_DMABUF_RENDERER=1 \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v ~/.Garmin:/root/.Garmin \
  --security-opt label=disable \
  garmin-sdk-manager
xhost -local:docker
```

In the SDK Manager, log in with your developer account, download the latest SDK and the simulators
of the Edge devices you want to test, then close it. The SDK lands in `~/.Garmin/ConnectIQ/Sdks/`,
owned by root — give it back to yourself (this also fixes "Permission denied" later on):

```bash
sudo chown -R $USER:$USER ~/.Garmin/ConnectIQ/
```

The `Makefile` picks the most recent SDK under `~/.Garmin/ConnectIQ/Sdks/` (or
`~/Library/Application Support/Garmin/ConnectIQ/Sdks/` on macOS); set `CIQ_HOME` to override.

### Developer key

```bash
make keygen   # once
```

It writes a 4096-bit RSA key in DER format to `~/.Garmin/ConnectIQ/developer_key` (with the PEM
next to it). The store version is signed with a specific key that must never change — see
[PUBLISH.md](PUBLISH.md#current-situation).

## Build

Run from `garmin-app/` (`make help` lists every target):

```bash
make build                   # Edge 1040 (default)
make build DEVICE=edge530    # a specific device
make build-all               # every supported device
make debug DEVICE=edge1040   # with debug symbols
make clean
```

The `.prg` files land in `bin/`. To build inside Docker instead of with a native SDK:

```bash
docker build -t pedalons-garmin-builder -f Dockerfile.build .
docker run --rm \
  -v ~/.Garmin/ConnectIQ:/root/.Garmin/ConnectIQ:ro \
  -v $(pwd):/app \
  -w /app \
  pedalons-garmin-builder \
  make build
```

## Run in the Simulator

The simulator must be running before an app is loaded into it.

```bash
# Ubuntu 24.04+: through the garmin-sdk-manager image built above
make simulator-docker
make run-docker DEVICE=edge1040

# macOS, or a Linux that still has webkit2gtk-4.0
make simulator
make run DEVICE=edge1040
```

Use different `DEVICE` values to test other screen sizes. The app always talks to
`https://www.pedalons.fr` (`BASE_URL` in `source/ApiClient.mc`), simulator included, and login works
as on a device (see [Authentication](#authentication)).

Unit tests (the `(:test)` code, e.g. `QrCodeTest.mc`) run in the native simulator, started first:

```bash
make test DEVICE=edge1040
```

## Deploy to a Device

1. Connect the Edge over USB
2. Copy `bin/Pedalons-<device>.prg` to `GARMIN/Apps/` on the device
3. Eject the device

Publishing to the Connect IQ Store — the `metadata/` listing material, versions, signing key, beta
and review — is in [PUBLISH.md](PUBLISH.md); a release is run with the `garmin-release` skill
(`.claude/skills/garmin-release/`).

## Authentication

The app uses Device Code Flow (RFC 8628), since Edge devices have no keyboard:

1. Open the app on the Edge and press SELECT
2. It shows a QR code, the site's address and a 6-character code
3. Scan the QR code, or open the site's `/garmin` page, on a phone or computer
4. Check the code and log in with your Pédalons account
5. The app detects the login and shows your rides and routes

## Troubleshooting

| Symptom | Fix |
|---|---|
| SDK Manager shows a blank window, or the simulator can't open `libwebkit2gtk-4.0.so.37` | Use the Docker setup and the `*-docker` targets above |
| "Permission denied" (or "Permission non accordée") | `sudo chown -R $USER:$USER ~/.Garmin/ConnectIQ/` |
| `Developer key not found` | `make keygen` |
| `Connect IQ SDK not found` | Install an SDK, or set `CIQ_HOME` |
| Manifest not found | Run `make` from `garmin-app/` |
| Device not supported | Use a `DEVICE` listed in `manifest.xml` |
| "Unable to connect to simulator" | Start the simulator first, wait a few seconds, then `make run-docker` |

## Project Structure

```
garmin-app/
├── manifest.xml            # App id, version, devices, permissions, languages
├── monkey.jungle           # Build configuration
├── Makefile                # Build, simulator, tests, key, package
├── Dockerfile.sdk-manager  # SDK Manager and simulator image
├── Dockerfile.build        # Build image
├── source/                 # Monkey C sources (file by file in CLAUDE.md)
├── resources/              # English strings, launcher icon
├── resources-fre/          # French strings
├── scripts/qr-vectors.py   # Test vectors for QrCodeTest.mc
├── metadata/               # Store listing material (PUBLISH.md)
└── docs/                   # Garmin reference PDFs
```

The source layout, API endpoints and code patterns are in [CLAUDE.md](CLAUDE.md).

## Documentation

- [Connect IQ SDK Documentation](https://developer.garmin.com/connect-iq/overview/)
- [Monkey C Programming Guide](https://developer.garmin.com/connect-iq/monkey-c/)
- [Connect IQ API Reference](https://developer.garmin.com/connect-iq/api-docs/)
- [SDK Manager Linux Workaround](https://github.com/pcolby/connectiq-sdk-manager/issues/3)
- In `docs/`: the Garmin Developer Program start guide, the Courses API and the OAuth 2.0 PKCE
  documentation (PDFs)

## License

[PolyForm Noncommercial 1.0.0](../LICENSE)
