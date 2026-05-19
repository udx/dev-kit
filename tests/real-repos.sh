#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_HOME="${DEV_KIT_TEST_HOME:-$(mktemp -d "${TMPDIR:-/tmp}/dev-kit-real-repos.XXXXXX")}"
DEV_KIT_BIN_DIR="$TEST_HOME/.local/bin"
KEEP_HOME="${DEV_KIT_TEST_KEEP_HOME:-0}"
REAL_REPOS_CSV="${DEV_KIT_TEST_REAL_REPOS:-}"
REPORT_DIR="${DEV_KIT_TEST_REPORT_DIR:-$TEST_HOME/reports}"

# shellcheck disable=SC1091
. "$REPO_DIR/lib/modules/utils.sh"
# shellcheck disable=SC1091
. "$REPO_DIR/lib/modules/config_catalog.sh"
# shellcheck disable=SC1091
. "$REPO_DIR/lib/modules/output.sh"

MODE="${DEV_KIT_TEST_MODE:-$(dev_kit_repo_validation_scalar "real_repo_probe" "default_mode")}"
MODE="${MODE:-check}"
COMMAND_SOFT_TIMEOUT="${DEV_KIT_TEST_SOFT_TIMEOUT:-$(dev_kit_repo_validation_scalar "real_repo_probe" "soft_timeout_seconds")}"
COMMAND_SOFT_TIMEOUT="${COMMAND_SOFT_TIMEOUT:-15}"
COMMAND_HARD_TIMEOUT="${DEV_KIT_TEST_HARD_TIMEOUT:-$(dev_kit_repo_validation_scalar "real_repo_probe" "hard_timeout_seconds")}"
COMMAND_HARD_TIMEOUT="${COMMAND_HARD_TIMEOUT:-180}"

usage() {
  cat <<'EOF'
Usage: bash tests/real-repos.sh [--check|--write] [/abs/path/to/repo ...]

Runs the current dev.kit working tree against real local repos using a temporary
plain `dev.kit` shim, without changing the global install.

Default mode is --check, which is read-only for target repos.

Options via environment:
  DEV_KIT_TEST_REAL_REPOS   Colon-separated repo paths when no CLI args are given
  DEV_KIT_TEST_HOME         Temp home for the test run
  DEV_KIT_TEST_REPORT_DIR   Directory for per-repo JSON reports
  DEV_KIT_TEST_SOFT_TIMEOUT Seconds before a slow-command notice (default: 15)
  DEV_KIT_TEST_HARD_TIMEOUT Seconds before stopping a command (default: 180)
  DEV_KIT_TEST_KEEP_HOME    Keep temp home after exit (default: 0)

Examples:
  bash tests/real-repos.sh --check ./reusable-workflows ./github-rabbit-action
  DEV_KIT_TEST_REAL_REPOS="./reusable-workflows:./github-rabbit-action" bash tests/real-repos.sh --check
  bash tests/real-repos.sh --write /tmp/dev-kit-probe-clone

Probe examples and release matrix candidates live in src/configs/repo-validation.yaml.
EOF
}

cleanup() {
  if [ "$KEEP_HOME" != "1" ]; then
    rm -rf "$TEST_HOME"
  fi
}

trap cleanup EXIT

repo_paths=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --write) MODE="write" ;;
    -h|--help) usage; exit 0 ;;
    --*) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
    *) repo_paths+=("$1") ;;
  esac
  shift
done

if [ "${#repo_paths[@]}" -eq 0 ] && [ -n "$REAL_REPOS_CSV" ]; then
  while IFS= read -r repo_path; do
    [ -n "$repo_path" ] || continue
    repo_paths+=("$repo_path")
  done <<EOF
$(printf '%s' "$REAL_REPOS_CSV" | tr ':' '\n')
EOF
fi

if [ "${#repo_paths[@]}" -eq 0 ]; then
  usage >&2
  exit 1
fi

mkdir -p "$DEV_KIT_BIN_DIR"
mkdir -p "$REPORT_DIR"
ln -sfn "$REPO_DIR/bin/dev-kit" "$DEV_KIT_BIN_DIR/dev.kit"

export HOME="$TEST_HOME"
export PATH="$DEV_KIT_BIN_DIR:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
unset DEV_KIT_HOME
unset DEV_KIT_BIN_DIR

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    printf 'jq is required for real repo report summaries\n' >&2
    exit 1
  fi
}

report_name_for_repo() {
  basename "$1" | tr -c 'A-Za-z0-9._-' '-'
}

print_check_summary() {
  local repo_path="$1"
  local home_json="$2"
  local repo_json="$3"
  local refs_count=""
  local gap_count=""
  local workflow_status=""
  local context_status=""
  local home_context_status=""

  home_context_status="$(jq -r '.synced.context_status // "none"' "$home_json")"
  workflow_status="$(jq -r '.workflow.jobs[] | select(.id == "repo") | .status' "$repo_json")"
  context_status="$(jq -r '.workflow.jobs[] | select(.id == "repo") | .context_status' "$repo_json")"
  gap_count="$(jq -r '.workflow.jobs[] | select(.id == "repo") | .gap_count' "$repo_json")"
  refs_count="$(jq -r '[.workflow.jobs[] | select(.id == "repo") | .steps[]? | select(.id == "read_repo") | .refs[]?] | length' "$repo_json")"

  printf '%s\tmode=%s\thome_context=%s\trepo_status=%s\trepo_context=%s\tgaps=%s\tread_refs=%s\n' \
    "$repo_path" "$MODE" "$home_context_status" "$workflow_status" "$context_status" "$gap_count" "$refs_count"
}

print_write_summary() {
  local repo_path="$1"
  local repo_json="$2"
  local context_yaml="$repo_path/.rabbit/context.yaml"
  local gap_count=""
  local manifest_count=0
  local dep_count=0

  gap_count="$(jq -r '.workflow.jobs[] | select(.id == "repo") | .gap_count' "$repo_json")"
  if [ -f "$context_yaml" ]; then
    manifest_count="$(awk '/^manifests:/{flag=1;next} flag && /^[^[:space:]#]/{exit} flag && /^  - path:/{count += 1} END{print count + 0}' "$context_yaml")"
    dep_count="$(awk '/^dependencies:/{flag=1;next} /^# Manifests/{if(flag) exit} flag && /^  - repo:/{count += 1} END{print count + 0}' "$context_yaml")"
  fi

  printf '%s\tmode=%s\tcontext=%s\tgaps=%s\tmanifests=%s\tdependencies=%s\n' \
    "$repo_path" "$MODE" "$context_yaml" "$gap_count" "$manifest_count" "$dep_count"
}

run_report_command() {
  local label="$1"
  local output_file="$2"
  shift 2

  local tmp_file="${output_file}.tmp"
  rm -f "$tmp_file"
  DEV_KIT_SPINNER_DISABLE=1 dev_kit_run_guarded \
    "$label" \
    "$COMMAND_SOFT_TIMEOUT" \
    "$COMMAND_HARD_TIMEOUT" \
    "$label is taking longer than usual; still resolving repo evidence" \
    "$@" >"$tmp_file"
  mv "$tmp_file" "$output_file"
}

require_jq
printf 'report_dir: %s\n' "$REPORT_DIR"
printf 'mode: %s\n' "$MODE"

for repo_path in "${repo_paths[@]}"; do
  repo_path="$(cd "$repo_path" 2>/dev/null && pwd || true)"
  [ -n "$repo_path" ] || { printf 'repo not found\n' >&2; exit 1; }
  [ -d "$repo_path/.git" ] || { printf 'not a git repo: %s\n' "$repo_path" >&2; exit 1; }
  repo_report_name="$(report_name_for_repo "$repo_path")"
  home_json="$REPORT_DIR/${repo_report_name}.home.json"
  repo_json="$REPORT_DIR/${repo_report_name}.repo.json"

  printf '\n===== %s =====\n' "$repo_path"
  if [ "$MODE" = "check" ]; then
    (
      cd "$repo_path"
      run_report_command "dev.kit home check: $repo_path" "$home_json" dev.kit --json
      run_report_command "dev.kit repo check: $repo_path" "$repo_json" dev.kit repo --json --check
    )
    print_check_summary "$repo_path" "$home_json" "$repo_json"
  else
    (
      cd "$repo_path"
      run_report_command "dev.kit repo write: $repo_path" "$repo_json" dev.kit repo --json
    )
    print_write_summary "$repo_path" "$repo_json"
  fi
done
