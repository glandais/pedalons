#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

../format.sh karoo
# Stop the Gradle daemon this run spawned, even on failure, so it doesn't linger.
trap './gradlew --quiet --stop' EXIT
./gradlew --quiet assembleDebug
# Unit + behaviour tests (Robolectric) and the pixel goldens, checked against the recorded ones.
./gradlew --quiet verifyRoborazziDebug
