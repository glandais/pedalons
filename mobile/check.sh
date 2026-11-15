#!/usr/bin/env bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

# The embedded route planner (assets/planner/) is a committed build of the site's planner: fail
# when one of the files it was built from, or one of the files built, is no longer the one the
# build recorded (tool/planner_bundle.sha256, written by `pnpm build:mobile-planner`). Content
# hashes: a checkout does not keep dates. Ledger MOB-170.
if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$@"; }
else
  sha256() { shasum -a 256 "$@"; }
fi
if ! (cd .. && sha256 -c --quiet mobile/tool/planner_bundle.sha256); then
  echo "mobile/assets/planner/ is stale: run \`pnpm build:mobile-planner\` in frontend/ and commit the result." >&2
  exit 1
fi

# Install dependencies
flutter pub get

# Generate API clients and models from OpenAPI
dart run openapi_retrofit_generator

# Generate freezed/json_serializable code
dart run build_runner build

../format.sh mobile

flutter analyze

if [ -d test ]; then
  flutter test
else
  echo "No test directory found, skipping tests"
fi
