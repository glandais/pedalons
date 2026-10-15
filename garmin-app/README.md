# Pédalons Garmin Connect IQ App

A Garmin Connect IQ app for Edge cycling computers that allows users to browse the upcoming rides and the routes of their teams, and download routes to the device.

## Features

- Browse the upcoming rides of all your teams, and the routes attached to them
- Browse the routes of all your teams that are not attached to a ride
- Routes sorted by proximity to current location
- Download routes as FIT files directly to your Garmin
- Device Code Flow authentication (no keyboard needed)
- Logout from the home menu
- Supports English and French

## Supported Devices

| Device | Product ID |
|--------|------------|
| Edge 530 | edge530 |
| Edge 540 | edge540 |
| Edge 550 | edge550 |
| Edge 830 | edge830 |
| Edge 840 | edge840 |
| Edge 850 | edge850 |
| Edge 1030 | edge1030 |
| Edge 1030 Bontrager | edge1030bontrager |
| Edge 1030 Plus | edge1030plus |
| Edge 1040 | edge1040 |
| Edge 1050 | edge1050 |
| Edge Explore 2 | edgeexplore2 |
| Edge MTB | edgemtb |

Requires Connect IQ API 3.3.0 or higher (`minApiLevel` in `manifest.xml`).

## Quick Start

### Prerequisites

- Docker (recommended) or Podman, or the native Connect IQ SDK
- Garmin developer account (free): https://developer.garmin.com/
- Garmin developer key (see [Generate a Developer Key](#step-4-generate-a-developer-key))

### SDK Installation (Docker-based)

On modern Linux distributions (Ubuntu 24.04+), the official SDK Manager has compatibility issues with webkit2gtk. The recommended approach is using Docker with Ubuntu 22.04.

#### Step 1: Build the SDK Manager Container

```bash
cd garmin-app

# Build the container
docker build -t garmin-sdk-manager -f Dockerfile.sdk-manager .
```

#### Step 2: Run SDK Manager to Download SDK

```bash
# Allow X11 forwarding
xhost +local:docker

# Run the SDK Manager GUI
docker run -it --rm \
  --ipc=host \
  -e DISPLAY=$DISPLAY \
  -e WEBKIT_DISABLE_DMABUF_RENDERER=1 \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v ~/.Garmin:/root/.Garmin \
  --security-opt label=disable \
  garmin-sdk-manager

# After done, revoke X11 access
xhost -local:docker
```

In the SDK Manager:
1. Log in with your Garmin developer account
2. Download SDK 8.4.0 (or latest)
3. Download device simulators for the Edge devices you want to test
4. Close the SDK Manager

The SDK will be installed to `~/.Garmin/ConnectIQ/Sdks/`.

#### Step 3: Fix File Permissions

Files created by Docker are owned by root. Fix ownership:

```bash
sudo chown -R $USER:$USER ~/.Garmin/ConnectIQ/
```

#### Step 4: Generate a Developer Key

```bash
make keygen
```

which runs, once:

```bash
# Generate RSA key pair using OpenSSL
openssl genrsa -out ~/.Garmin/ConnectIQ/developer_key.pem 4096

# Convert to DER format (required by Connect IQ SDK)
openssl pkcs8 -topk8 -inform PEM -outform DER \
  -in ~/.Garmin/ConnectIQ/developer_key.pem \
  -out ~/.Garmin/ConnectIQ/developer_key \
  -nocrypt
```

This creates `~/.Garmin/ConnectIQ/developer_key` (DER format, used for signing builds).

### Build

```bash
# Build for Edge 1040 (default)
make build

# Build for a specific device
make build DEVICE=edge530

# Build for all supported devices
make build-all

# Build debug version with symbols
make debug DEVICE=edge1040

# Clean build artifacts
make clean

# Create .iq package for Connect IQ Store
make package
```

The built `.prg` files will be in the `bin/` directory.

To build inside Docker instead of with a native SDK:

```bash
docker build -t pedalons-garmin-builder -f Dockerfile.build .
docker run --rm \
  -v ~/.Garmin/ConnectIQ:/root/.Garmin/ConnectIQ:ro \
  -v $(pwd):/app \
  -w /app \
  pedalons-garmin-builder \
  make build
```

### Run in Simulator

#### Using Docker (Ubuntu 24.04+)

On modern Linux distributions, the simulator requires Docker due to webkit2gtk compatibility issues.

```bash
# 1. Start the simulator (runs in background)
make simulator-docker

# 2. Wait 2-3 seconds for simulator to initialize

# 3. Build and load the app
make run-docker DEVICE=edge1040
```

#### Using Native SDK (macOS or older Linux)

If webkit2gtk-4.0 is available on your system:

```bash
# 1. Start the simulator
make simulator

# 2. Build and load the app
make run DEVICE=edge1040
```

#### Manual Docker Commands

For more control over the simulator:

```bash
# Allow X11 forwarding
xhost +local:docker

# Start simulator manually
docker run --rm -d \
  --ipc=host \
  --net=host \
  -e DISPLAY=$DISPLAY \
  -e NO_AT_BRIDGE=1 \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v ~/.Garmin/ConnectIQ:/root/.Garmin/ConnectIQ \
  --security-opt label=disable \
  garmin-sdk-manager \
  /root/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-8.4.0-2025-12-03-5122605dc/bin/simulator

# Load app into running simulator
docker run --rm \
  --net=host \
  -v ~/.Garmin/ConnectIQ:/root/.Garmin/ConnectIQ \
  -v $(pwd):/app \
  -w /app \
  garmin-sdk-manager \
  /root/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-8.4.0-2025-12-03-5122605dc/bin/monkeydo bin/Pedalons-edge1040.prg edge1040

# When done, revoke X11 access
xhost -local:docker
```

#### Simulator Tips

- The simulator must be running before loading an app
- Use different `DEVICE` values to test on different screen sizes
- Login works as on a device: the app shows a code, you complete it in any browser, and the app
  polls until it is done (see [Authentication](#authentication)). The app talks to
  `https://www.pedalons.fr` (`source/ApiClient.mc`)

### Deploy to Device

1. Connect your Edge device via USB
2. Copy `bin/Pedalons-{device}.prg` to `GARMIN/Apps/` on the device
3. Safely eject the device

For the Connect IQ Store — listing material in `metadata/`, versions, signing key, beta and
review — see [PUBLISH.md](PUBLISH.md).

## Authentication

The app uses Device Code Flow (RFC 8628) since Edge devices don't have keyboards:

1. Open the app on your Garmin
2. Press SELECT to start login
3. Note the 6-character code displayed
4. On your phone or computer, go to `pedalons.fr/garmin`
5. Enter the code and log in with your Pédalons account
6. The app automatically detects authentication and shows your rides and routes

## Troubleshooting

### SDK Manager Shows Blank Window

This is a known issue on Ubuntu 24.04+. Use the Docker approach described above.

### "Unable to find manifest"

Ensure you're running the build command from the `garmin-app` directory.

### "Key not found"

Generate a developer key as described in [Step 4](#step-4-generate-a-developer-key).

### Build Fails with "Device not supported"

Check that the device ID in your command matches one in `manifest.xml`.

### "Permission denied" or "Permission non accordée"

SDK files are owned by root after Docker installation. Fix with:

```bash
sudo chown -R $USER:$USER ~/.Garmin/ConnectIQ/
```

### Simulator: "libwebkit2gtk-4.0.so.37: cannot open shared object file"

On Ubuntu 24.04+, the simulator requires webkit2gtk-4.0 which is not available. Use Docker:

```bash
make simulator-docker
make run-docker DEVICE=edge1040
```

### "Unable to connect to simulator"

The simulator must be running before loading an app. Start it first:

```bash
make simulator-docker
# Wait 2-3 seconds for it to start
make run-docker DEVICE=edge1040
```

## Project Structure

```
garmin-app/
├── manifest.xml               # App manifest (permissions, devices)
├── monkey.jungle              # Build configuration
├── Makefile                   # Build automation
├── Dockerfile.sdk-manager     # Docker image for SDK Manager
├── Dockerfile.build           # Docker image for building
├── source/
│   ├── PedalonsApp.mc         # Main app entry
│   ├── AuthManager.mc         # Token management
│   ├── ApiClient.mc           # HTTP API client
│   ├── LoginView.mc           # Login/auth screen
│   ├── PedalonsView.mc        # Loading view, then home menu (rides, routes, logout)
│   ├── PedalonsDelegate.mc    # Input for the loading/error view
│   ├── HomeMenuDelegate.mc    # Home menu input
│   ├── RideListMenuDelegate.mc       # Ride list
│   ├── RideEntryMenuDelegate.mc      # Routes of a ride (one per group)
│   ├── StandaloneRouteMenuDelegate.mc # Routes not attached to a ride
│   ├── RouteDetailView.mc     # Route detail and download
│   ├── RouteDetailDelegate.mc # Route detail input
│   ├── ErrorView.mc           # Error display
│   ├── FormatUtils.mc         # Distance, elevation, time and date formatting
│   └── VerticalLayout.mc      # Vertical text layout helper
├── resources/
│   ├── drawables/
│   └── strings.xml            # English strings
└── resources-fre/
    └── strings.xml            # French strings
```

## Documentation

- [Connect IQ SDK Documentation](https://developer.garmin.com/connect-iq/overview/)
- [Monkey C Programming Guide](https://developer.garmin.com/connect-iq/monkey-c/)
- [Connect IQ API Reference](https://developer.garmin.com/connect-iq/api-docs/)
- [SDK Manager Linux Workaround](https://github.com/pcolby/connectiq-sdk-manager/issues/3)

### Garmin Reference PDFs (in `docs/`)

- `Garmin Developer Program_Start_Guide_1.2.pdf` - Getting started with Garmin development
- `Courses_API.pdf` - Garmin Courses API for route/course management
- `OAuth2PKCE_2.pdf` - OAuth 2.0 PKCE flow documentation

## License

[PolyForm Noncommercial 1.0.0](../LICENSE)
