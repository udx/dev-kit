#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO_DIR/tests/helpers/assert.sh"

TEST_HOME="${DEV_KIT_TEST_HOME:-$(mktemp -d "${TMPDIR:-/tmp}/dev-kit-test-home.XXXXXX")}"
BASE_PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
SIMPLE_REPO="$REPO_DIR/tests/fixtures/simple-repo"
DOCUMENTED_SHELL_REPO="$REPO_DIR/tests/fixtures/documented-shell-repo"
DOCKER_REPO="$REPO_DIR/tests/fixtures/docker-repo"
SIMPLE_ACTION_REPO="$TEST_HOME/simple-action-repo"
HOME_ACTION_REPO="$TEST_HOME/home-action-repo"
DOCKER_ACTION_REPO="$TEST_HOME/docker-action-repo"
EMPTY_REPO="$TEST_HOME/empty-repo"
IGNORED_ACTION_REPO="$TEST_HOME/ignored-action-repo"
WORKFLOW_CONTRACT_REPO="$TEST_HOME/workflow-contract-repo"
DECLARED_CONFIG_REPO="$TEST_HOME/declared-config-repo"
REFERENCE_DOC_COMMAND_REPO="$TEST_HOME/reference-doc-command-repo"
AVAILABLE_TEST_GROUPS="core repo-contract"
TEST_ONLY="${DEV_KIT_TEST_ONLY:-}"

cleanup() {
  rm -rf "$TEST_HOME"
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage: bash tests/suite.sh [--only core|repo-contract|core,repo-contract] [--list]

Groups:
  core           command flow, output, and context generation checks
  repo-contract  focused generated-context contract regressions
EOF
}

list_groups() {
  local group=""
  for group in $AVAILABLE_TEST_GROUPS; do
    printf '%s\n' "$group"
  done
}

should_run() {
  local group="$1"
  if [ -z "$TEST_ONLY" ]; then
    return 0
  fi
  case ",$TEST_ONLY," in
    *,"$group",*) return 0 ;;
  esac
  return 1
}

should_run_explicit() {
  [ -n "$TEST_ONLY" ] || return 1
  should_run "$1"
}

replace_in_file() {
  local file_path="$1"
  local before="$2"
  local after="$3"
  local tmp_file=""

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/dev-kit-replace.XXXXXX")" || return 1
  awk -v before="$before" -v after="$after" '
    BEGIN { replaced = 0 }
    {
      line = $0
      pos = index(line, before)
      if (pos > 0 && replaced == 0) {
        line = substr(line, 1, pos - 1) after substr(line, pos + length(before))
        replaced = 1
      }
      print line
    }
    END { exit(replaced == 0) }
  ' "$file_path" >"$tmp_file" && mv "$tmp_file" "$file_path"
}

json_factor_status() {
  local json="$1"
  local factor="$2"

  printf '%s\n' "$json" | awk -v factor="$factor" '
    $0 ~ "\"" factor "\":[[:space:]]*\\{" {
      in_factor = 1
      next
    }
    in_factor && /"status":[[:space:]]*"/ {
      sub(/^.*"status":[[:space:]]*"/, "", $0)
      sub(/".*$/, "", $0)
      print
      exit
    }
    in_factor && /^    }/ {
      exit
    }
  '
}

setup_declared_config_repo() {
  local repo_dir="$1"

  case "$repo_dir" in
    "$TEST_HOME"/*) rm -rf "$repo_dir" ;;
    *) fail "refusing to reset fixture outside TEST_HOME: $repo_dir" ;;
  esac
  mkdir -p "$repo_dir"
  git -C "$repo_dir" init >/dev/null 2>&1
  cat > "$repo_dir/README.md" <<'EOF'
# Declared Config Repo

Runtime variables are declared in `work-conf.yaml`.
EOF
  cat > "$repo_dir/work-conf.yaml" <<'EOF'
---
# Runtime config contract for the local automation surface.
# References:
# - https://github.com/example/runtime/blob/main/docs/config.md
kind: customRuntimeConfig
version: example.dev/runtime-v1/config
config:
  env: {}
  secrets: {}
EOF
  cat > "$repo_dir/interface-contract.yaml" <<'EOF'
---
# Explicit contract marker without typed version metadata.
contract:
  purpose: local automation interface notes
refs:
  - README.md
EOF
  cat > "$repo_dir/source-notes.yaml" <<'EOF'
# Source notes with references are useful context, but not a manifest contract.
sources:
  - https://github.com/example/runtime/blob/main/docs/config.md
refs:
  - README.md
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --only)
      shift
      [ "$#" -gt 0 ] || fail "--only requires a comma-separated list"
      TEST_ONLY="$1"
      ;;
    --list) list_groups; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
  shift
done

mkdir -p "$TEST_HOME"
export HOME="$TEST_HOME"
export PATH="$BASE_PATH"
unset DEV_KIT_HOME
unset DEV_KIT_BIN_DIR

DEV_KIT_HOME="$REPO_DIR"
DEV_KIT_BIN_DIR="$TEST_HOME/.local/bin"
mkdir -p "$DEV_KIT_BIN_DIR"
ln -sf "$REPO_DIR/bin/dev-kit" "$DEV_KIT_BIN_DIR/dev.kit"
export PATH="$DEV_KIT_BIN_DIR:$PATH"
assert_contains "$(command -v dev.kit)" "$DEV_KIT_BIN_DIR/dev.kit" "suite: uses local dev.kit shim"
assert_contains "$(dev.kit --version)" "$(awk -F'"' '/"version"/{print $4; exit}' "$REPO_DIR/package.json")" "suite: uses checkout dev.kit version"
DEV_KIT_VERSION="$(awk -F'"' '/"version"/{print $4; exit}' "$REPO_DIR/package.json")"

# shellcheck disable=SC1090
. "$DEV_KIT_HOME/bin/env/dev-kit.sh"
while IFS= read -r module_file; do
  [ -n "$module_file" ] || continue
  [ "$module_file" = "$REPO_DIR/lib/modules/bootstrap.sh" ] && continue
  # shellcheck disable=SC1090
  . "$module_file"
done <<EOF
$(dev_kit_module_paths)
EOF

while IFS= read -r command_file; do
  [ -n "$command_file" ] || continue
  # shellcheck disable=SC1090
  . "$command_file"
done <<EOF
$(find "$REPO_DIR/lib/commands" -maxdepth 1 -type f -name '*.sh' | sort)
EOF

if should_run_explicit "repo-contract"; then
  self_repo_json="$(cd "$REPO_DIR" && dev.kit repo --json)"
  self_context_yaml="$(cat "$REPO_DIR/.rabbit/context.yaml")"
  repo_validation_manifest="$(
    awk '
      /^  - path: src\/configs\/repo-validation.yaml$/ { flag = 1 }
      flag && /^  - path:/ && $0 !~ /src\/configs\/repo-validation.yaml$/ { exit }
      flag { print }
    ' "$REPO_DIR/.rabbit/context.yaml"
  )"

  assert_not_contains "$self_repo_json" "\"repo\": \"udx/dev.kit\"" "repo contract: omits self dependency contracts"
  assert_not_contains "$self_context_yaml" "source_repo: udx/dev.kit" "repo contract: omits self source repo provenance"
  assert_not_contains "$repo_validation_manifest" "source_repo: udx/worker" "repo contract: does not treat probe repo values as manifest source repo"
  assert_not_contains "$self_context_yaml" ".rabbit/dev.kit/" "repo contract: excludes generated rabbit evidence"
  assert_not_contains "$self_context_yaml" ".rabbit/context.yaml.tmp." "repo contract: excludes context temp files from evidence"
  assert_not_contains "$self_context_yaml" "run: make build" "repo contract: ignores reference-doc build command examples"
  assert_not_contains "$self_context_yaml" "run: make run" "repo contract: ignores reference-doc run command examples"

  cp -R "$DOCKER_REPO" "$DOCKER_ACTION_REPO"
  rm -f "$DOCKER_ACTION_REPO/.rabbit/context.yaml"

  docker_repo_json="$(cd "$DOCKER_ACTION_REPO" && dev.kit repo --json)"
  assert_contains "$docker_repo_json" "\"context\":" "repo contract: docker repo reports context path"

  docker_context_yaml="${DOCKER_ACTION_REPO}/.rabbit/context.yaml"
  assert_contains "$(cat "$docker_context_yaml")" "path: .rabbit/infra_configs/staging/k8s-configmap.yaml" "repo contract: inventories nested rabbit manifests"
  docker_context_refs="$(awk '/^refs:/{flag=1;next} /^# Commands/{if(flag) exit} flag{print}' "$docker_context_yaml")"
  assert_not_contains "$docker_context_refs" ".rabbit/infra_configs/staging/k8s-configmap.yaml" "repo contract: excludes nested rabbit manifests from read-first refs"

  setup_declared_config_repo "$DECLARED_CONFIG_REPO"
  declared_config_json="$(cd "$DECLARED_CONFIG_REPO" && dev.kit repo --json)"
  assert_contains "$(json_factor_status "$declared_config_json" config)" "present" "repo contract: declared root YAML config contract is present"
  assert_contains "$declared_config_json" "config contract manifest: work-conf.yaml" "repo contract: reports declared root YAML config contract"
  declared_config_context_yaml="${DECLARED_CONFIG_REPO}/.rabbit/context.yaml"
  assert_contains "$(cat "$declared_config_context_yaml")" "path: work-conf.yaml" "repo contract: includes declared root YAML manifest"
  assert_contains "$(cat "$declared_config_context_yaml")" "path: interface-contract.yaml" "repo contract: includes contract-marker root YAML manifest"
  assert_contains "$(cat "$declared_config_context_yaml")" "kind: customRuntimeConfig" "repo contract: records declared root YAML manifest kind"
  assert_contains "$(cat "$declared_config_context_yaml")" "source_repo: example/runtime" "repo contract: traces declared root YAML manifest owner from version"
  assert_contains "$(cat "$declared_config_context_yaml")" "github reference: example/runtime" "repo contract: records declared root YAML manifest header refs"
  declared_config_dependencies="$(awk '/^dependencies:/{flag=1;next} /^# /{if(flag) exit} flag{print}' "$declared_config_context_yaml")"
  assert_contains "$declared_config_dependencies" "repo: example/runtime" "repo contract: traces declared root YAML manifest owner as dependency"
  assert_not_contains "$(cat "$declared_config_context_yaml")" "path: source-notes.yaml" "repo contract: does not promote source comments alone to manifest"
fi

if should_run "core"; then
  guard_soft_output="$(
    DEV_KIT_SPINNER_DISABLE=1 \
    dev_kit_run_guarded "guard test" 1 5 "repo resolving is taking longer than usual" \
      bash -lc 'sleep 2; printf done' 2>&1
  )"
  assert_contains "$guard_soft_output" "repo resolving is taking longer than usual" "guard: emits soft timeout notice"
  assert_contains "$guard_soft_output" "done" "guard: preserves command output"

  set +e
  guard_hard_output="$(
    DEV_KIT_SPINNER_DISABLE=1 \
    dev_kit_run_guarded "guard test" 1 2 "repo resolving is taking longer than usual" \
      bash -lc 'sleep 3' 2>&1
  )"
  guard_hard_status=$?
  set -e
  [ "$guard_hard_status" -eq 124 ] || fail "guard: stops hard timeout"
  pass "guard: stops hard timeout"
  assert_contains "$guard_hard_output" "dev.kit timeout: guard test exceeded 2s" "guard: reports hard timeout"

  guard_child_pid_file="$TEST_HOME/guard-child.pid"
  set +e
  guard_group_output="$(
    DEV_KIT_SPINNER_DISABLE=1 \
    dev_kit_run_guarded "guard child test" 1 2 "repo resolving is taking longer than usual" \
      bash -lc 'sleep 30 & child=$!; printf "%s\n" "$child" > "$1"; wait "$child"' _ "$guard_child_pid_file" 2>&1
  )"
  guard_group_status=$?
  set -e
  [ "$guard_group_status" -eq 124 ] || fail "guard: stops child process groups"
  guard_child_pid="$(cat "$guard_child_pid_file")"
  if kill -0 "$guard_child_pid" 2>/dev/null; then
    kill "$guard_child_pid" 2>/dev/null || true
    fail "guard: terminates child processes on timeout"
  fi
  pass "guard: terminates child processes on timeout"
  assert_contains "$guard_group_output" "dev.kit timeout: guard child test exceeded 2s" "guard: reports child timeout"

  cp -R "$DOCUMENTED_SHELL_REPO" "$HOME_ACTION_REPO"
  rm -rf "$HOME_ACTION_REPO/.dev-kit"
  rm -f "$HOME_ACTION_REPO/.rabbit/context.yaml"

  home_json="$(cd "$HOME_ACTION_REPO" && dev.kit --json)"
  assert_contains "$home_json" "\"repo_detected\": true" "home: detects repo"
  assert_contains "$home_json" "\"synced\": {" "home: reports synced artifacts"
  assert_contains "$home_json" "\"context_status\": \"missing\"" "home: reports missing context"
  assert_contains "$home_json" "\"workflow\": {" "home: reports workflow contract"
  assert_contains "$home_json" "\"id\": \"env\"" "home: includes env job"
  assert_contains "$home_json" "\"helpers\": [" "home: reports helpers"

  home_text="$(cd "$HOME_ACTION_REPO" && dev.kit)"
  assert_contains "$home_text" "[workflow]" "home text: renders workflow section"
  assert_contains "$home_text" "[required]" "home text: renders env tools"
  assert_contains "$home_text" "[context]" "home text: renders context section"
  assert_contains "$home_text" "Repo context is missing." "home text: guides missing context"
  assert_contains "$home_text" "dev.kit repo" "home text: suggests repo generation"
  assert_not_contains "$home_text" "env:                dev.kit env" "home text: does not suggest env as next step"
  assert_contains "$home_text" "[next]" "home text: renders next section"
  assert_file_missing "$HOME_ACTION_REPO/.rabbit/context.yaml" "home: does not write context.yaml"
  assert_not_contains "$(dev_kit_github_repo_refs_in_file "$REPO_DIR/src/configs/detection-signals.yaml")" "org/repo" "home: ignores placeholder github refs"

  repo_home_json="$(cd "$HOME_ACTION_REPO" && dev.kit repo --json)"
  assert_contains "$repo_home_json" "\"context\":" "home fixture repo: writes context path"
  assert_contains "$repo_home_json" "\"id\": \"confirm-research-fix-loop\"" "repo json: includes confirmation loop action"

  repo_global_json="$(cd "$HOME_ACTION_REPO" && dev.kit --json repo)"
  assert_contains "$repo_global_json" "\"command\": \"repo\"" "global json: routes to repo command"

  uninstall_bin_dir="$TEST_HOME/uninstall-bin"
  uninstall_home_dir="$TEST_HOME/uninstall-home"
  mkdir -p "$uninstall_bin_dir" "$uninstall_home_dir"
  touch "$uninstall_bin_dir/dev.kit"
  uninstall_json="$(
    cd "$HOME_ACTION_REPO" && \
      DEV_KIT_BIN_DIR="$uninstall_bin_dir" \
      DEV_KIT_HOME="$uninstall_home_dir" \
      dev.kit --json uninstall --yes
  )"
  assert_contains "$uninstall_json" "\"command\": \"uninstall\"" "uninstall json: reports command"
  assert_contains "$uninstall_json" "\"ok\": true" "uninstall json: reports success"
  assert_contains "$uninstall_json" "\"binary_removed\": true" "uninstall json: reports binary removal"
  assert_contains "$uninstall_json" "\"home_removed\": true" "uninstall json: reports home removal"
  assert_file_missing "$uninstall_bin_dir/dev.kit" "uninstall json: removes binary target"
  assert_file_missing "$uninstall_home_dir" "uninstall json: removes home target"

  set +e
  uninstall_failure_json="$(
    REPO_DIR="$TEST_HOME/missing-repo" \
    DEV_KIT_BIN_DIR="$uninstall_bin_dir" \
    DEV_KIT_HOME="$uninstall_home_dir" \
    dev_kit_cmd_uninstall json --yes 2>/dev/null
  )"
  uninstall_failure_status=$?
  set -e
  [ "$uninstall_failure_status" -ne 0 ] || fail "uninstall json: fails when uninstall script fails"
  pass "uninstall json: fails when uninstall script fails"
  assert_contains "$uninstall_failure_json" "\"ok\": false" "uninstall json: reports failure"
  assert_contains "$uninstall_failure_json" "\"error\":" "uninstall json: includes error message"

  home_repeat_json="$(cd "$HOME_ACTION_REPO" && DEV_KIT_REPO_HARD_TIMEOUT=1 dev.kit --json)"
  assert_contains "$home_repeat_json" "\"context_status\": \"existing\"" "home: reuses existing context"
  assert_contains "$home_repeat_json" "\"context_reason\": null" "home: fresh context has no stale reason"

  home_repeat_text="$(cd "$HOME_ACTION_REPO" && dev.kit)"
  assert_contains "$home_repeat_text" "[coverage]" "home text: summarizes coverage"
  assert_contains "$home_repeat_text" "[refs]" "home text: summarizes refs"
  assert_contains "$home_repeat_text" "[gaps]" "home text: summarizes gaps"
  assert_contains "$home_repeat_text" "[next]" "home text: summarizes next step"
  assert_contains "$home_repeat_text" "repair: README.md or .env.example" "home text: shows gap repair target"
  assert_contains "$home_repeat_text" "reference: README.md" "home text: shows local gap reference"
  assert_contains "$home_repeat_text" "repair:            fix repo-owned gaps, then rerun dev.kit repo" "home text: prints repair loop next step"

  replace_in_file \
    "$HOME_ACTION_REPO/.rabbit/context.yaml" \
    "  version: ${DEV_KIT_VERSION}" \
    "  version: 0.0.0-test"

  stale_version_home_json="$(cd "$HOME_ACTION_REPO" && dev.kit --json)"
  assert_contains "$stale_version_home_json" "\"context_status\": \"stale\"" "home: marks version-mismatched context as stale"
  assert_contains "$stale_version_home_json" "\"context_reason\": \"context was generated by dev.kit 0.0.0-test; current dev.kit is ${DEV_KIT_VERSION}\"" "home: reports stale generator and current versions"

  replace_in_file \
    "$HOME_ACTION_REPO/.rabbit/context.yaml" \
    "  version: 0.0.0-test" \
    "  version: ${DEV_KIT_VERSION}"

  replace_in_file \
    "$HOME_ACTION_REPO/.rabbit/context.yaml" \
    "No repo-owned configuration contract was found in docs, manifests, or checked-in example files." \
    "Add .env.example, .env.sample, or .env.template when repo configuration is required."

  stale_home_json="$(cd "$HOME_ACTION_REPO" && dev.kit --json)"
  assert_contains "$stale_home_json" "\"context_status\": \"stale\"" "home: marks outdated context as stale"
  assert_contains "$stale_home_json" "\"context_reason\": \"gap coverage no longer matches current repo evidence\"" "home: reports stale reason"

  stale_home_text="$(cd "$HOME_ACTION_REPO" && dev.kit)"
  assert_contains "$stale_home_text" "Repo context is stale." "home text: warns about stale context"
  assert_contains "$stale_home_text" "gap coverage no longer matches current repo evidence" "home text: explains stale reason"
  assert_not_contains "$stale_home_text" "[refs]" "home text: hides stale refs summary"

  env_json="$(cd "$HOME_ACTION_REPO" && dev.kit env --json)"
  assert_contains "$env_json" "\"command\": \"env\"" "env: reports command name"
  assert_contains "$env_json" "\"workflow\": {" "env: reports workflow contract"

  repo_json="$(cd "$DOCUMENTED_SHELL_REPO" && dev.kit repo --json)"
  assert_contains "$repo_json" "\"archetype\":" "repo: reports archetype"
  assert_contains "$repo_json" "\"context\":" "repo: reports context path"
  assert_contains "$repo_json" "\"context_status\": \"current\"" "repo: reports current workflow context after write"
  assert_contains "$repo_json" "\"repair_target\": \"README.md or .env.example\"" "repo: includes repair target"
  assert_contains "$repo_json" "\"reference\": \"README.md\"" "repo: includes local reference doc"
  assert_contains "$repo_json" "\"id\": \"confirm-research-fix-loop\"" "repo: includes confirmation loop action"
  assert_contains "$repo_json" "\"workflow\": {" "repo: reports workflow contract"

  repo_text="$(cd "$DOCUMENTED_SHELL_REPO" && dev.kit repo)"
  assert_contains "$repo_text" "[workflow]" "repo text: renders workflow section"
  assert_contains "$repo_text" "[read first]" "repo text: renders read first section"
  assert_contains "$repo_text" "[factors]" "repo text: renders factors section"
  assert_contains "$repo_text" "[context]" "repo text: renders context section"
  assert_contains "$repo_text" "[tooling]" "repo text: renders tooling section"
  assert_contains "$repo_text" "[next]" "repo text: renders next section"
  assert_contains "$repo_text" "confirm whether to start the research-and-fix loop now" "repo text: confirms before repair loop"

  set +e
  repo_write_failure_output="$(
    DEV_KIT_SPINNER_DISABLE=1
    dev_kit_context_yaml_write() {
      printf 'boom\n' >&2
      return 42
    }
    dev_kit_cmd_repo text "$DOCUMENTED_SHELL_REPO" 2>&1
  )"
  repo_write_failure_status=$?
  set -e
  [ "$repo_write_failure_status" -eq 42 ] || fail "repo text: preserves non-timeout write failures"
  pass "repo text: preserves non-timeout write failures"
  assert_contains "$repo_write_failure_output" "Context write failed with exit status 42" "repo text: distinguishes non-timeout write failures"
  assert_contains "$repo_write_failure_output" "boom" "repo text: preserves underlying write error"

  self_repo_json="$(cd "$REPO_DIR" && dev.kit repo --json)"
  self_context_yaml="$(cat "$REPO_DIR/.rabbit/context.yaml")"
  repo_validation_manifest="$(
    awk '
      /^  - path: src\/configs\/repo-validation.yaml$/ { flag = 1 }
      flag && /^  - path:/ && $0 !~ /src\/configs\/repo-validation.yaml$/ { exit }
      flag { print }
    ' "$REPO_DIR/.rabbit/context.yaml"
  )"
  assert_not_contains "$self_repo_json" "\"repo\": \"udx/dev.kit\"" "repo: omits self dependency contracts"
  assert_not_contains "$self_context_yaml" "source_repo: udx/dev.kit" "repo: omits self source repo provenance"
  assert_not_contains "$repo_validation_manifest" "source_repo: udx/worker" "repo: does not treat probe repo values as manifest source repo"
  assert_not_contains "$self_context_yaml" ".rabbit/dev.kit/" "repo: excludes generated rabbit evidence"
  assert_not_contains "$self_context_yaml" ".rabbit/context.yaml.tmp." "repo: excludes context temp files from evidence"
  assert_not_contains "$self_context_yaml" "run: make build" "repo: ignores reference-doc build command examples"
  assert_not_contains "$self_context_yaml" "run: make run" "repo: ignores reference-doc run command examples"

  cp -R "$SIMPLE_REPO" "$SIMPLE_ACTION_REPO"
  rm -rf "$SIMPLE_ACTION_REPO/.dev-kit"
  rm -f "$SIMPLE_ACTION_REPO/.rabbit/context.yaml"

  simple_repo_json="$(cd "$SIMPLE_ACTION_REPO" && dev.kit repo --json)"
  assert_contains "$simple_repo_json" "\"context\":" "simple repo: reports context path"

  context_yaml="${SIMPLE_ACTION_REPO}/.rabbit/context.yaml"
  assert_file_exists "$context_yaml" "repo: creates .rabbit/context.yaml"
  assert_contains "$(cat "$context_yaml")" "kind: repoContext" "repo: context.yaml has kind header"
  assert_contains "$(cat "$context_yaml")" "generator:" "repo: context.yaml has generator metadata"
  assert_contains "$(cat "$context_yaml")" "tool: dev.kit" "repo: context.yaml records generator tool"
  assert_contains "$(cat "$context_yaml")" "repo: https://github.com/udx/dev.kit" "repo: context.yaml records generator repo"
  assert_contains "$(cat "$context_yaml")" "sources:" "repo: context.yaml records generator source refs"
  assert_contains "$(cat "$context_yaml")" "homepage: https://udx.dev/kit" "repo: context.yaml records dev.kit homepage"
  assert_contains "$(cat "$context_yaml")" "package: https://www.npmjs.com/package/@udx/dev-kit" "repo: context.yaml records package source"
  assert_contains "$(cat "$context_yaml")" "installation: https://github.com/udx/dev.kit/blob/latest/docs/installation.md" "repo: context.yaml records installation guide"
  assert_contains "$(cat "$context_yaml")" "generated_at:" "repo: context.yaml records generated timestamp"
  assert_not_contains "$(cat "$context_yaml")" "/Users/" "repo: context.yaml has no absolute paths"
  assert_not_contains "$(cat "$context_yaml")" "/private/" "repo: context.yaml has no private temp paths"
  assert_not_contains "$(cat "$context_yaml")" "file://" "repo: context.yaml has no file URI paths"
  assert_not_contains "$(cat "$context_yaml")" "kind: npm package" "repo: context.yaml omits package inventory"

  cp -R "$DOCKER_REPO" "$DOCKER_ACTION_REPO"
  rm -f "$DOCKER_ACTION_REPO/.rabbit/context.yaml"

  docker_repo_json="$(cd "$DOCKER_ACTION_REPO" && dev.kit repo --json)"
  assert_contains "$docker_repo_json" "\"context\":" "docker repo: reports context path"

  docker_context_yaml="${DOCKER_ACTION_REPO}/.rabbit/context.yaml"
  assert_contains "$(cat "$docker_context_yaml")" "generator:" "docker repo: includes generator metadata"
  assert_contains "$(cat "$docker_context_yaml")" "path: .rabbit/infra_configs/staging/k8s-configmap.yaml" "docker repo: inventories nested rabbit manifests"
  docker_context_refs="$(awk '/^refs:/{flag=1;next} /^# Commands/{if(flag) exit} flag{print}' "$docker_context_yaml")"
  assert_not_contains "$docker_context_refs" ".rabbit/infra_configs/staging/k8s-configmap.yaml" "docker repo: excludes nested rabbit manifests from read-first refs"

  mkdir -p "$IGNORED_ACTION_REPO/.next/cache"
  git -C "$IGNORED_ACTION_REPO" init >/dev/null 2>&1
  cat > "$IGNORED_ACTION_REPO/README.md" <<'EOF'
# Ignored Action Repo
EOF
  cat > "$IGNORED_ACTION_REPO/.gitignore" <<'EOF'
.next/
EOF
  cat > "$IGNORED_ACTION_REPO/runtime.yaml" <<'EOF'
version: example.dev/runtime-v1/config
kind: runtimeConfig
metadata:
  env: staging
EOF
  cat > "$IGNORED_ACTION_REPO/.next/cache/reference.txt" <<'EOF'
runtime.yaml
EOF

  ignored_repo_json="$(cd "$IGNORED_ACTION_REPO" && dev.kit repo --json)"
  assert_contains "$ignored_repo_json" "\"context\":" "ignored repo: reports context path"
  ignored_context_yaml="${IGNORED_ACTION_REPO}/.rabbit/context.yaml"
  assert_not_contains "$(cat "$ignored_context_yaml")" ".next/cache/reference.txt" "ignored repo: excludes gitignored artifact references"

  setup_declared_config_repo "$DECLARED_CONFIG_REPO"
  declared_config_json="$(cd "$DECLARED_CONFIG_REPO" && dev.kit repo --json)"
  assert_contains "$(json_factor_status "$declared_config_json" config)" "present" "declared config repo: explicit config contract satisfies config factor"
  assert_contains "$declared_config_json" "config contract manifest: work-conf.yaml" "declared config repo: reports explicit config contract"
  declared_config_context_yaml="${DECLARED_CONFIG_REPO}/.rabbit/context.yaml"
  assert_contains "$(cat "$declared_config_context_yaml")" "path: work-conf.yaml" "declared config repo: includes explicit root YAML manifest"
  assert_contains "$(cat "$declared_config_context_yaml")" "path: interface-contract.yaml" "declared config repo: includes contract-marker root YAML manifest"
  assert_contains "$(cat "$declared_config_context_yaml")" "kind: customRuntimeConfig" "declared config repo: records explicit root YAML manifest kind"
  assert_contains "$(cat "$declared_config_context_yaml")" "source_repo: example/runtime" "declared config repo: traces explicit root YAML manifest owner from version"
  assert_contains "$(cat "$declared_config_context_yaml")" "github reference: example/runtime" "declared config repo: records explicit root YAML manifest header refs"
  declared_config_dependencies="$(awk '/^dependencies:/{flag=1;next} /^# /{if(flag) exit} flag{print}' "$declared_config_context_yaml")"
  assert_contains "$declared_config_dependencies" "repo: example/runtime" "declared config repo: traces explicit root YAML manifest owner as dependency"
  assert_not_contains "$(cat "$declared_config_context_yaml")" "path: source-notes.yaml" "declared config repo: does not promote source comments alone to manifest"

  mkdir -p "$WORKFLOW_CONTRACT_REPO/.github/workflows"
  git -C "$WORKFLOW_CONTRACT_REPO" init >/dev/null 2>&1
  cat > "$WORKFLOW_CONTRACT_REPO/README.md" <<'EOF'
# Workflow Contract Repo
EOF
  cat > "$WORKFLOW_CONTRACT_REPO/.github/workflows/ci.yml" <<'EOF'
name: CI
on:
  push:
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF
  cat > "$WORKFLOW_CONTRACT_REPO/.github/workflows/deploy.yml" <<'EOF'
name: Deploy
on:
  workflow_dispatch:
jobs:
  deploy:
    uses: udx/reusable-workflows/.github/workflows/deploy.yml@main
EOF

  workflow_repo_json="$(cd "$WORKFLOW_CONTRACT_REPO" && dev.kit repo --json)"
  assert_contains "$workflow_repo_json" "\"context\":" "workflow repo: reports context path"
  workflow_context_yaml="${WORKFLOW_CONTRACT_REPO}/.rabbit/context.yaml"
  assert_contains "$(cat "$workflow_context_yaml")" "path: .github/workflows/deploy.yml" "workflow repo: includes reusable workflow manifest"
  assert_not_contains "$(cat "$workflow_context_yaml")" "path: .github/workflows/ci.yml" "workflow repo: excludes marketplace-only workflow manifest"
  assert_contains "$(cat "$workflow_context_yaml")" "repo: udx/reusable-workflows" "workflow repo: traces reusable workflow dependency"

  mkdir -p "$REFERENCE_DOC_COMMAND_REPO/docs/references"
  git -C "$REFERENCE_DOC_COMMAND_REPO" init >/dev/null 2>&1
  cat > "$REFERENCE_DOC_COMMAND_REPO/README.md" <<'EOF'
# Reference Doc Command Repo

This repo has no build or run command.
EOF
  cat > "$REFERENCE_DOC_COMMAND_REPO/docs/references/command-surfaces.md" <<'EOF'
# Command Surfaces

Examples only:

- `make build`
- `make run`
EOF

  reference_doc_json="$(cd "$REFERENCE_DOC_COMMAND_REPO" && dev.kit repo --json)"
  assert_contains "$reference_doc_json" "\"context\":" "reference docs repo: reports context path"
  reference_doc_context_yaml="${REFERENCE_DOC_COMMAND_REPO}/.rabbit/context.yaml"
  assert_not_contains "$(cat "$reference_doc_context_yaml")" "run: make build" "reference docs repo: ignores reference-only build example"
  assert_not_contains "$(cat "$reference_doc_context_yaml")" "run: make run" "reference docs repo: ignores reference-only run example"

  mkdir -p "$EMPTY_REPO"
  git -C "$EMPTY_REPO" init >/dev/null 2>&1

  empty_repo_json="$(cd "$EMPTY_REPO" && dev.kit repo --json)"
  assert_contains "$empty_repo_json" "\"recommended_repos\":" "empty repo: reports recommended repos"
  assert_contains "$empty_repo_json" "https://github.com/udx/worker" "empty repo: includes worker recommendation"
  assert_contains "$empty_repo_json" "https://github.com/udx/reusable-workflows" "empty repo: includes reusable workflow recommendation"
  assert_contains "$empty_repo_json" "https://github.com/udx/github-rabbit-action" "empty repo: includes rabbit action recommendation"

  empty_repo_text="$(cd "$EMPTY_REPO" && dev.kit repo)"
  assert_contains "$empty_repo_text" "[tooling]" "empty repo: prints tooling section"
  assert_contains "$empty_repo_text" "https://github.com/udx/worker" "empty repo: prints worker recommendation"

  assert_file_exists "$EMPTY_REPO/README.md" "empty repo: creates README"
  assert_file_exists "$EMPTY_REPO/docs" "empty repo: creates docs dir"
  assert_file_exists "$EMPTY_REPO/.rabbit" "empty repo: creates rabbit dir"
  assert_file_exists "$EMPTY_REPO/.github/workflows" "empty repo: creates workflows dir"
  assert_file_exists "$EMPTY_REPO/.github/dependabot.yml" "empty repo: creates dependabot config"
  assert_contains "$(cat "$EMPTY_REPO/.github/dependabot.yml")" "package-ecosystem: github-actions" "empty repo: dependabot targets github actions"
  assert_contains "$(cat "$EMPTY_REPO/README.md")" "This repository uses \`dev.kit\`" "empty repo: seeds README"
fi

printf "ok - dev.kit suite completed\n"
