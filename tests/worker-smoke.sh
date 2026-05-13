#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${DEV_KIT_TEST_IMAGE:-usabilitydynamics/udx-worker:latest}"
SOURCE_REPO="${DEV_KIT_TEST_SOURCE_REPO:-$REPO_DIR}"
TARGET_REPO="${DEV_KIT_TEST_TARGET_REPO:-$REPO_DIR}"
TARGET_REPO_NAME="${DEV_KIT_TEST_TARGET_REPO_NAME:-target-repo}"
KEEP_HOME="${DEV_KIT_TEST_KEEP_HOME:-0}"
TEST_HOME="${DEV_KIT_TEST_HOME:-$(mktemp -d "${TMPDIR:-/tmp}/dev-kit-worker-home.XXXXXX")}"
DISABLED_TOOLS="${DEV_KIT_TEST_DISABLED_TOOLS:-}"
DISABLED_CREDS="${DEV_KIT_TEST_DISABLED_CREDS:-}"
SCRATCH_MODE="${DEV_KIT_TEST_SCRATCH_MODE:-copy}"
PREPARE_CMD="${DEV_KIT_TEST_PREPARE_CMD:-}"

usage() {
  cat <<'EOF'
Usage: bash tests/worker-smoke.sh

Runs dev.kit inside the published udx/worker image after installing the current
repo with `npm install -g /workspace`.

Environment:
  DEV_KIT_TEST_IMAGE              Worker image to use
  DEV_KIT_TEST_SOURCE_REPO        Repo containing dev.kit source (default: current repo)
  DEV_KIT_TEST_TARGET_REPO        Repo to run dev.kit against (default: current repo)
  DEV_KIT_TEST_TARGET_REPO_NAME   Mount name inside container (default: target-repo)
  DEV_KIT_TEST_HOME               Host temp dir mounted as container HOME
  DEV_KIT_TEST_KEEP_HOME          Keep the temp home after exit (default: 0)
  DEV_KIT_TEST_DISABLED_TOOLS     Comma-separated tools to disable in env config
  DEV_KIT_TEST_DISABLED_CREDS     Comma-separated credentials to disable in env config
  DEV_KIT_TEST_SCRATCH_MODE       copy or direct (default: copy)
  DEV_KIT_TEST_PREPARE_CMD        Shell command to run against the test repo copy before dev.kit
EOF
}

cleanup() {
  if [ "$KEEP_HOME" != "1" ]; then
    rm -rf "$TEST_HOME"
  fi
}

trap cleanup EXIT

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  printf 'docker is required for tests/worker-smoke.sh\n' >&2
  exit 1
fi

if [ ! -d "$SOURCE_REPO" ]; then
  printf 'source repo not found: %s\n' "$SOURCE_REPO" >&2
  exit 1
fi

if [ ! -d "$TARGET_REPO" ]; then
  printf 'target repo not found: %s\n' "$TARGET_REPO" >&2
  exit 1
fi

mkdir -p "$TEST_HOME"

build_yaml_list() {
  local csv="$1"
  local line=""

  if [ -z "$csv" ]; then
    printf '[]'
    return 0
  fi

  printf '\n'
  printf '%s' "$csv" | tr ',' '\n' | while IFS= read -r line; do
    line="$(printf '%s' "$line" | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print}')"
    [ -n "$line" ] || continue
    printf '  - %s\n' "$line"
  done
}

write_env_config() {
  local config_dir="$TEST_HOME/.udx/dev.kit/config"
  local tools_yaml creds_yaml

  tools_yaml="$(build_yaml_list "$DISABLED_TOOLS")"
  creds_yaml="$(build_yaml_list "$DISABLED_CREDS")"

  mkdir -p "$config_dir"
  cat > "$config_dir/env.yaml" <<EOF
kind: envConfig
version: udx.dev/dev.kit/v1

config:
  disabled_tools:${tools_yaml}
  disabled_credentials:${creds_yaml}
EOF
}

if [ -n "$DISABLED_TOOLS" ] || [ -n "$DISABLED_CREDS" ]; then
  write_env_config
fi

CONTAINER_HOME="/tmp/dev-kit-home"
CONTAINER_TARGET_SOURCE="/repos/${TARGET_REPO_NAME}"
CONTAINER_TARGET_WORK="/tmp/test-repo"
CONTAINER_SOURCE="/workspace"

printf 'image: %s\n' "$IMAGE"
printf 'source: %s\n' "$SOURCE_REPO"
printf 'target: %s\n' "$TARGET_REPO"
[ -n "$PREPARE_CMD" ] && printf 'prepare: %s\n' "$PREPARE_CMD"
[ -n "$SCRATCH_MODE" ] && printf 'scratch mode: %s\n' "$SCRATCH_MODE"
[ -n "$DISABLED_TOOLS" ] && printf 'disabled tools: %s\n' "$DISABLED_TOOLS"
[ -n "$DISABLED_CREDS" ] && printf 'disabled creds: %s\n' "$DISABLED_CREDS"

docker run --rm \
  -e HOME="$CONTAINER_HOME" \
  -e DEV_KIT_TEST_SCRATCH_MODE="$SCRATCH_MODE" \
  -e DEV_KIT_TEST_PREPARE_CMD="$PREPARE_CMD" \
  -v "$SOURCE_REPO:$CONTAINER_SOURCE" \
  -v "$TARGET_REPO:$CONTAINER_TARGET_SOURCE" \
  -v "$TEST_HOME:$CONTAINER_HOME" \
  "$IMAGE" \
  /bin/bash -lc "
    set -euo pipefail
    npm install -g $CONTAINER_SOURCE >/tmp/dev-kit-install.log
    rm -rf $CONTAINER_TARGET_WORK
    if [ \"\$DEV_KIT_TEST_SCRATCH_MODE\" = \"copy\" ]; then
      cp -R $CONTAINER_TARGET_SOURCE $CONTAINER_TARGET_WORK
    else
      ln -s $CONTAINER_TARGET_SOURCE $CONTAINER_TARGET_WORK
    fi
    cd $CONTAINER_TARGET_WORK
    if [ -n \"\$DEV_KIT_TEST_PREPARE_CMD\" ]; then
      eval \"\$DEV_KIT_TEST_PREPARE_CMD\"
    fi
    printf '\n== dev.kit ==\n'
    dev.kit
    printf '\n== dev.kit env --json ==\n'
    dev.kit env --json
    printf '\n== dev.kit repo --json ==\n'
    dev.kit repo --json
  "
