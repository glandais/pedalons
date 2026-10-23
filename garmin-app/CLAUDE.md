# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Pédalons Garmin Connect IQ app for Garmin Edge cycling computers. Allows users to browse their teams' upcoming rides and routes and download them to the device.

SDK installation, the developer key, simulator setup and troubleshooting are in [README.md](README.md);
store publication, its listing material (`metadata/`) and the signing-key rules in [PUBLISH.md](PUBLISH.md).

## Tech Stack

| Component | Technology |
|-----------|------------|
| Language | Monkey C (Connect IQ SDK) |
| API Level | 3.3.0+ |
| Auth | Device Code Flow (RFC 8628) |
| Build | Docker-based SDK + Makefile |

## Commands

```bash
# Build for default device (edge1040)
make build

# Build for specific device
make build DEVICE=edge530

# Build for all devices
make build-all

# Run in simulator (Ubuntu 24.04+ requires Docker)
make simulator-docker    # Start simulator first
make run-docker DEVICE=edge1040

# Native simulator (if webkit2gtk-4.0 available)
make simulator
make run DEVICE=edge1040

# Unit tests (simulator started first; `make test DEVICE=edge530`)
make test

# Clean build artifacts
make clean

# Create .iq package for Connect IQ Store
make package

# Generate developer key (one-time)
make keygen
```

## Architecture

```
source/
├── PedalonsApp.mc                  # Main app entry, Device Code Flow orchestration
├── AuthManager.mc                  # Token storage (Toybox.Storage), expiry management, logout
├── ApiClient.mc                    # HTTP client, all API calls, token refresh
├── LoginView.mc                    # Device code display: QR code, site and user code
├── QrCode.mc                       # QR encoder (byte mode, level L, versions 3-4, mask 0)
├── QrCodeTest.mc                   # (:test) QrCode vs python-qrcode, from scripts/qr-vectors.py
├── PedalonsView.mc                 # Loads registered groups, rides + routes, then opens the home menu
├── PedalonsDelegate.mc             # Loading/error view input (retry, refresh menu)
├── HomeMenuDelegate.mc             # Home menu: My next rides, Rides, Routes, Logout
├── RegisteredGroupListMenuDelegate.mc # Groups the user is registered in (now-12h to +7d); select = route detail
├── RideListMenuDelegate.mc         # Upcoming rides (D-1 to D+7, server side)
├── RideEntryMenuDelegate.mc        # A ride's routes (one per group)
├── StandaloneRouteMenuDelegate.mc  # Routes not attached to a ride
├── RouteDetailView.mc              # Single route details
├── RouteDetailDelegate.mc          # Route detail input + download
├── FormatUtils.mc                  # Distance / elevation / date formatting
├── VerticalLayout.mc               # Line-by-line drawing helper
└── ErrorView.mc                    # Error display
```

Strings are in `resources/` (English) and `resources-fre/` (French).

## Authentication Flow

Uses Device Code Flow (RFC 8628) since Edge devices have no keyboard:

1. User presses SELECT on LoginView → `PedalonsApp.startDeviceCodeFlow()`
2. App calls `/api/device/oauth/device` with `clientId=garmin`
3. Displays a QR code of `verificationUriComplete` (`<site>/garmin?code=…`), then the host of
   `verificationUri` and the 6-char user code — kept in clear text because the web page asks to
   compare it before pairing (ledger `SEC-2`). Over 78 bytes, no QR: host and code only
4. Polls `/api/device/oauth/token` until user authenticates on phone/computer
5. Receives JWT tokens, stores via `AuthManager.saveTokens()`

## API Endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /api/device/oauth/device` | Request device code |
| `POST /api/device/oauth/token` | Poll for token / refresh token |
| `GET /api/device/routes` | Fetch `registeredGroups`, `rides` and `routes` (accepts `?lat=&lon=` for proximity sort) |
| `GET /api/device/routes/{teamSlug}/{routeSlug}/fit` | Download FIT file |

## Key Patterns

- **Callbacks**: Async operations use method references: `method(:onDeviceCodeReceived)`
- **Polling timer**: `Timer.Timer` with 5s minimum interval per RFC 8628
- **Token refresh**: Automatic before API calls when token expires in <10 min
- **Position-based sorting**: Routes sorted by proximity if GPS available
- **FIT download**: Uses `HTTP_RESPONSE_CONTENT_TYPE_FIT` for direct device import
- **Route already in Garmin Connect** (API-121): of a registered group's `syncStatuses`,
  `ApiClient.parseRegisteredGroupDto` keeps only the GARMIN entry's state as `syncState`;
  `HomeMenuDelegate.syncStateLabel` puts it in the row's sublabel (in Connect / old version /
  update pending / upload failed / reconnect). Absent (older backend, or Garmin does not hold the
  route) means « unknown », not « not sent », and an unknown state shows nothing.

## Supported Devices

edge530, edge540, edge550, edge830, edge840, edge850, edge1030, edge1030bontrager, edge1030plus, edge1040, edge1050, edge1060, edgeexplore2, edgemtb

The list lives in `manifest.xml` and in `DEVICES` in the `Makefile` — change both together.

## Garmin Documentation

Reference PDFs in `docs/`:
- `Garmin Developer Program_Start_Guide_1.2.pdf` - Getting started with Garmin development
- `Courses_API.pdf` - Garmin Courses API for route/course management
- `OAuth2PKCE_2.pdf` - OAuth 2.0 PKCE flow documentation

## Critical Notes

- SDK requires Docker on Ubuntu 24.04+ (webkit2gtk-4.0 incompatibility)
- Developer key must be DER format (see `make keygen`)
- Minimum poll interval is 5 seconds per RFC 8628
- Token expiry includes 5-min buffer for API calls
- Base URL is configured in `ApiClient.mc` (`BASE_URL` constant)
