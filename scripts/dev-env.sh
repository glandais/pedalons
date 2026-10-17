#!/usr/bin/env bash
# Exports the handful of .env values the dev backend needs (postgres, MinIO, the Stadia Maps
# routing key), and nothing else.
#
#   cd backend && source ../scripts/dev-env.sh && mvn quarkus:dev
#
# `mvn quarkus:dev` runs outside Docker and talks to the workstation stack over the loopback ports
# docker-compose.local.yml publishes, so it needs that stack's postgres and MinIO credentials. It
# must NOT get the rest of the file: PEDALONS_BOOTSTRAP_* and QUARKUS_MAILER_* are read by Quarkus
# too, at a higher ordinal than application.properties, and would replace the %dev bootstrap domain
# (`localhost`, the WebAuthn origin of dev passkeys) with the stack's own.
#
# Sourced, not executed — exporting from a subshell would leave the parent untouched.

_dev_env_file="${ENV_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env}"

if [ ! -f "$_dev_env_file" ]; then
  echo "dev-env.sh: no $_dev_env_file — copy .env.example and fill it in" >&2
else
  # Values are taken verbatim: no expansion, no word splitting, so a password full of $ ! % or
  # spaces survives. Trailing \r from a file edited on Windows is dropped.
  while IFS='=' read -r _dev_env_key _dev_env_value; do
    _dev_env_value="${_dev_env_value%$'\r'}"
    _dev_env_value="${_dev_env_value%\"}"
    _dev_env_value="${_dev_env_value#\"}"
    export "$_dev_env_key=$_dev_env_value"
  done < <(grep -E '^(POSTGRES_(DB|USER|PASSWORD|HOST_PORT)|MINIO_(ACCESS_KEY|SECRET_KEY)|STORAGE_BUCKET|STADIAMAPS_API_KEY)=' "$_dev_env_file")
  echo "dev-env.sh: exported postgres + MinIO credentials and STADIAMAPS_API_KEY from $_dev_env_file"
fi

unset _dev_env_file _dev_env_key _dev_env_value
