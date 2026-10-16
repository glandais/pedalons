#!/usr/bin/env bash
# Same as publish_test.sh (bump, build, upload, commit), sent to beta testers:
# the external TestFlight group NP after Apple's beta review, with the version's
# whatsNew as « What to Test », and Play's closed testing track. It also tags
# mobile.X.Y.Z.N, which publishes a signed APK on GitHub for devices without
# Google Play (.github/workflows/mobile-release.yml).
set -euo pipefail
PUBLISH_CHANNEL=beta exec "$(dirname "$0")/publish_test.sh"
