#!/usr/bin/env bash

# @description: Remove the local dev.kit installation

dev_kit_cmd_uninstall() {
  local format="${1:-text}"
  local target="${DEV_KIT_BIN_DIR:-$HOME/.local/bin}/dev.kit"
  local home="${DEV_KIT_HOME:-$HOME/.udx/dev.kit}"
  local yes_mode="false"
  local arg=""
  shift || true

  if [ "$format" = "json" ]; then
    for arg in "$@"; do
      if [ "$arg" = "--yes" ]; then
        yes_mode="true"
        break
      fi
    done

    if [ "$yes_mode" != "true" ]; then
      printf '{ "command": "uninstall", "ok": false, "error": "JSON output requires --yes to avoid interactive prompts" }\n'
      return 1
    fi

    "$REPO_DIR/bin/scripts/uninstall.sh" "$@" >/dev/null
    printf '{ "command": "uninstall", "ok": true, "binary": "%s", "binary_removed": %s, "home": "%s", "home_removed": %s }\n' \
      "$(dev_kit_json_escape "$target")" \
      "$([ -e "$target" ] && printf 'false' || printf 'true')" \
      "$(dev_kit_json_escape "$home")" \
      "$([ -e "$home" ] && printf 'false' || printf 'true')"
    return 0
  fi

  "$REPO_DIR/bin/scripts/uninstall.sh" "$@"
}
