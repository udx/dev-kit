#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_HOME="${DEV_KIT_TEST_HOME:-$(mktemp -d "${TMPDIR:-/tmp}/dev-kit-real-repos.XXXXXX")}"
DEV_KIT_BIN_DIR="$TEST_HOME/.local/bin"
KEEP_HOME="${DEV_KIT_TEST_KEEP_HOME:-0}"
REAL_REPOS_CSV="${DEV_KIT_TEST_REAL_REPOS:-}"

usage() {
  cat <<'EOF'
Usage: bash tests/real-repos.sh [/abs/path/to/repo ...]

Runs the current dev.kit working tree against real local repos using a temporary
plain `dev.kit` shim, without changing the global install.

Options via environment:
  DEV_KIT_TEST_REAL_REPOS   Colon-separated repo paths when no CLI args are given
  DEV_KIT_TEST_HOME         Temp home for the test run
  DEV_KIT_TEST_KEEP_HOME    Keep temp home after exit (default: 0)

Examples:
  bash tests/real-repos.sh ~/git/udx/reusable-workflows ~/git/udx/www.peakclt.com
  DEV_KIT_TEST_REAL_REPOS="$HOME/git/udx/reusable-workflows:$HOME/git/udx/www.peakclt.com" bash tests/real-repos.sh
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

repo_paths=()
if [ "$#" -gt 0 ]; then
  while [ "$#" -gt 0 ]; do
    repo_paths+=("$1")
    shift
  done
elif [ -n "$REAL_REPOS_CSV" ]; then
  while IFS= read -r repo_path; do
    [ -n "$repo_path" ] || continue
    repo_paths+=("$repo_path")
  done <<EOF
$(printf '%s' "$REAL_REPOS_CSV" | tr ':' '\n')
EOF
else
  usage >&2
  exit 1
fi

mkdir -p "$DEV_KIT_BIN_DIR"
ln -sfn "$REPO_DIR/bin/dev-kit" "$DEV_KIT_BIN_DIR/dev.kit"

export HOME="$TEST_HOME"
export PATH="$DEV_KIT_BIN_DIR:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
unset DEV_KIT_HOME
unset DEV_KIT_BIN_DIR

for repo_path in "${repo_paths[@]}"; do
  repo_path="$(cd "$repo_path" 2>/dev/null && pwd || true)"
  [ -n "$repo_path" ] || { printf 'repo not found\n' >&2; exit 1; }
  [ -d "$repo_path/.git" ] || { printf 'not a git repo: %s\n' "$repo_path" >&2; exit 1; }
  run_out="$(mktemp "$TEST_HOME/dev-kit-real.XXXXXX.out")"

  printf '\n===== %s =====\n' "$repo_path"
  (
    cd "$repo_path"
    if ! dev.kit >"$run_out"; then
      cat "$run_out" >&2
      exit 1
    fi
    dev.kit repo >/dev/null
    [ -f .rabbit/context.yaml ] || { printf 'missing .rabbit/context.yaml\n' >&2; exit 1; }

    printf 'context: %s\n' "$repo_path/.rabbit/context.yaml"
    printf '\nrepo:\n'
    sed -n '1,20p' .rabbit/context.yaml
    printf '\ngaps:\n'
    awk '/^gaps:/{flag=1;next} /^# Dependencies/{if(flag) exit} flag{print}' .rabbit/context.yaml || true
    printf '\ndependencies:\n'
    awk '/^dependencies:/{flag=1;next} /^# Manifests/{if(flag) exit} flag{print}' .rabbit/context.yaml | sed -n '1,80p'
  )
done
