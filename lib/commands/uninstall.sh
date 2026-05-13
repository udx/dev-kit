#!/usr/bin/env bash

# @description: Remove the local dev.kit installation

dev_kit_cmd_uninstall() {
  local format="${1:-text}"
  local target="${DEV_KIT_BIN_DIR:-$HOME/.local/bin}/dev.kit"
  local home="${DEV_KIT_HOME:-$HOME/.udx/dev.kit}"
  local yes_mode="false"
  local arg=""
  local stdout_file=""
  local stderr_file=""
  local uninstall_status=0
  local uninstall_error=""
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

    stdout_file="$(mktemp "${TMPDIR:-/tmp}/dev-kit-uninstall-out.XXXXXX")" || {
      printf '{ "command": "uninstall", "ok": false, "error": "failed to create temp output file" }\n'
      return 1
    }
    stderr_file="$(mktemp "${TMPDIR:-/tmp}/dev-kit-uninstall-err.XXXXXX")" || {
      rm -f "$stdout_file"
      printf '{ "command": "uninstall", "ok": false, "error": "failed to create temp error file" }\n'
      return 1
    }

    set +e
    "$REPO_DIR/bin/scripts/uninstall.sh" "$@" >"$stdout_file" 2>"$stderr_file"
    uninstall_status=$?
    set -e

    [ -s "$stderr_file" ] && cat "$stderr_file" >&2

    if [ "$uninstall_status" -ne 0 ]; then
      uninstall_error="$(awk 'NF { print; exit }' "$stderr_file")"
      [ -n "$uninstall_error" ] || uninstall_error="$(awk 'NF { print; exit }' "$stdout_file")"
      [ -n "$uninstall_error" ] || uninstall_error="uninstall failed"
      rm -f "$stdout_file" "$stderr_file"
      printf '{ "command": "uninstall", "ok": false, "error": "%s", "binary": "%s", "binary_removed": %s, "home": "%s", "home_removed": %s }\n' \
        "$(dev_kit_json_escape "$uninstall_error")" \
        "$(dev_kit_json_escape "$target")" \
        "$([ -e "$target" ] && printf 'false' || printf 'true')" \
        "$(dev_kit_json_escape "$home")" \
        "$([ -e "$home" ] && printf 'false' || printf 'true')"
      return "$uninstall_status"
    fi

    rm -f "$stdout_file" "$stderr_file"
    printf '{ "command": "uninstall", "ok": true, "binary": "%s", "binary_removed": %s, "home": "%s", "home_removed": %s }\n' \
      "$(dev_kit_json_escape "$target")" \
      "$([ -e "$target" ] && printf 'false' || printf 'true')" \
      "$(dev_kit_json_escape "$home")" \
      "$([ -e "$home" ] && printf 'false' || printf 'true')"
    return 0
  fi

  "$REPO_DIR/bin/scripts/uninstall.sh" "$@"
}
