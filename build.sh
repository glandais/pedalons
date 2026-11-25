#!/usr/bin/env bash
set -euo pipefail

# What to build: all (default) | frontend | backend
# ENV_FILE picks another env file than ./.env — its ENV_NAME becomes the image tag (scripts/e2e.sh
# builds the tribly-e2e images this way).
TARGET="${1:-all}"
case "$TARGET" in
  all | frontend | backend) ;;
  *)
    echo "Usage: $0 [all|frontend|backend]" >&2
    exit 1
    ;;
esac

# `export $(... | xargs)` splits values on whitespace, quoted or not, so a display name like
# "Gaby Landais" would be exported as two broken words. Let the shell parse the file instead.
set -a
. "${ENV_FILE:-./.env}"
set +a

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$ROOT"
. "$ROOT/scripts/_image_tag.sh"

# Each image goes under the alias :${ENV_NAME} and, from a clean checkout, under its commit too —
# the tag scripts/deploy.sh deploys (see scripts/_image_tag.sh).
COMMIT_TAG=""
if worktree_dirty; then
  echo "Uncommitted changes: tagging :$ENV_NAME only — scripts/deploy.sh deploys commits." >&2
else
  COMMIT_TAG="$ENV_NAME$(image_suffix)"
fi

build_backend() {
  cd "$ROOT/backend"
  export QUARKUS_CONTAINER_IMAGE_GROUP=""
  export QUARKUS_CONTAINER_IMAGE_NAME="pedalons-backend"
  export QUARKUS_CONTAINER_IMAGE_TAG="$ENV_NAME"
  # Jib builds linux/amd64 unless told otherwise. Build for the daemon the image is loaded into:
  # arm64 on an Apple Silicon workstation (Docker VMM cannot emulate amd64), amd64 on a server.
  export QUARKUS_JIB_PLATFORMS="linux/$(docker version --format '{{.Server.Arch}}')"
  export QUARKUS_CONTAINER_IMAGE_ADDITIONAL_TAGS="$COMMIT_TAG"
  # Maven 3.10's super-POM pins project.build.outputTimestamp to 1980-02-01 (reproducible builds),
  # and git-commit-id-maven-plugin takes git.build.time from it: GET /api/version then reports a
  # build from 1980. Pass the real time instead.
  mvn clean package -DskipTests -Dquarkus.container-image.build=true \
    -Dproject.build.outputTimestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

build_frontend() {
  cd "$ROOT/frontend"
  mkdir -p src/assets/legal
  cp "$ROOT"/privacy/*.md src/assets/legal/
  docker build --progress=plain \
    --build-arg VITE_BUILD_SOURCEMAP="${FRONTEND_SOURCEMAP:-false}" \
    --build-arg FRONTEND_PREFETCH_AUDIT="${FRONTEND_PREFETCH_AUDIT:-false}" \
    -t "pedalons-frontend:$ENV_NAME" ${COMMIT_TAG:+-t "pedalons-frontend:$COMMIT_TAG"} .
  rm -rf src/assets/legal
}

# A one-sided build leaves the other image as it was: its latest build is what this commit runs
# with, so it gets this commit's tag too, and deploy.sh finds both.
carry_over() {
  local image="pedalons-$1"
  [[ -n "$COMMIT_TAG" ]] || return 0
  docker image inspect "$image:$COMMIT_TAG" >/dev/null 2>&1 && return 0
  docker image inspect "$image:$ENV_NAME" >/dev/null 2>&1 || return 0
  docker tag "$image:$ENV_NAME" "$image:$COMMIT_TAG"
}

if [ "$TARGET" = "all" ] || [ "$TARGET" = "backend" ]; then
  build_backend
fi
if [ "$TARGET" = "all" ] || [ "$TARGET" = "frontend" ]; then
  build_frontend
fi
[ "$TARGET" = "frontend" ] && carry_over backend
[ "$TARGET" = "backend" ] && carry_over frontend
exit 0
