#!/usr/bin/env bash

dev_kit_bootstrap() {
  export DEV_KIT_BIN_DIR="${DEV_KIT_BIN_DIR:-$HOME/.local/bin}"
  export DEV_KIT_HOME="${DEV_KIT_HOME:-$HOME/.udx/dev.kit}"
}

dev_kit_module_paths() {
  cat <<EOF
$REPO_DIR/lib/modules/bootstrap.sh
$REPO_DIR/lib/modules/utils.sh
$REPO_DIR/lib/modules/config_catalog.sh
$REPO_DIR/lib/modules/output.sh
$REPO_DIR/lib/modules/template_renderer.sh
$REPO_DIR/lib/modules/local_env.sh
$REPO_DIR/lib/modules/repo_signals.sh
$REPO_DIR/lib/modules/repo_archetypes.sh
$REPO_DIR/lib/modules/repo_factors.sh
$REPO_DIR/lib/modules/repo_workflows.sh
$REPO_DIR/lib/modules/dev_sync.sh
$REPO_DIR/lib/modules/repo_scaffold.sh
EOF
}

dev_kit_command_description() {
  local file="$1"
  awk -F': ' '/^# @description:/ { print $2; exit }' "$file"
}

dev_kit_public_command_names() {
  printf '%s\n' env repo uninstall
}

dev_kit_command_file_path() {
  local root_dir="$1"
  local command_name="$2"

  printf "%s/lib/commands/%s.sh" "$root_dir" "${command_name//-/_}"
}
