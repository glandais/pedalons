#!/usr/bin/env bash
# Same as publish_test.sh (bump, build, upload, commit), sent to beta testers:
# the external TestFlight group NP after Apple's beta review, with the version's
# whatsNew as « What to Test », and Play's closed testing track.
set -euo pipefail
PUBLISH_CHANNEL=beta exec "$(dirname "$0")/publish_test.sh"
