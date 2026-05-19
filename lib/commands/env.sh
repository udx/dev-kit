#!/usr/bin/env bash

# @description: Inspect environment tools and dev.kit usage config

dev_kit_env_workflow_status() {
  local missing_tools=""
  local disabled_tools=""
  local disabled_credentials=""

  missing_tools="$(dev_kit_env_missing_base_tools)"
  disabled_tools="$(dev_kit_env_config_list "disabled_tools")"
  disabled_credentials="$(dev_kit_env_config_list "disabled_credentials")"

  if [ -n "$missing_tools" ]; then
    printf '%s' "blocked"
    return 0
  fi

  if [ -n "$disabled_tools" ] || [ -n "$disabled_credentials" ]; then
    printf '%s' "customized"
    return 0
  fi

  printf '%s' "ready"
}

dev_kit_env_workflow_step_summaries() {
  local config_path=""

  config_path="$(dev_kit_env_config_path)"
  printf '%s\n' "Detect local tools and auth capabilities."
  printf '%s\n' "Resolve repo-facing capabilities from the current machine."
  if [ -f "$config_path" ]; then
    printf '%s\n' "Review environment config overrides at ${config_path}."
  else
    printf '%s\n' "Create ${config_path} with dev.kit env --config when overrides are needed."
  fi
}

dev_kit_env_workflow_job_json() {
  local config_path=""
  local disabled_tools=""
  local disabled_credentials=""
  local missing_tools=""
  local workflow_status=""
  local config_status="ready"

  config_path="$(dev_kit_env_config_path)"
  disabled_tools="$(dev_kit_env_config_list "disabled_tools")"
  disabled_credentials="$(dev_kit_env_config_list "disabled_credentials")"
  missing_tools="$(dev_kit_env_missing_base_tools)"
  workflow_status="$(dev_kit_env_workflow_status)"

  if [ -n "$disabled_tools" ] || [ -n "$disabled_credentials" ]; then
    config_status="customized"
  fi

  printf '{ "id": "env", "label": "Resolve local environment", "command": "dev.kit env", "status": "%s", "steps": [' \
    "$(dev_kit_json_escape "$workflow_status")"
  printf '{ "id": "detect_tools", "type": "inspect", "label": "Detect local tools", "status": "%s", "missing_required": %s, "tools": %s }, ' \
    "$(if [ -n "$missing_tools" ]; then printf 'blocked'; else printf 'ready'; fi)" \
    "$(printf '%s' "$missing_tools" | tr ' ' '\n' | awk 'NF' | dev_kit_lines_to_json_array)" \
    "$(dev_kit_env_tools_json)"
  printf '{ "id": "resolve_capabilities", "type": "inspect", "label": "Resolve capabilities from the current machine", "status": "ready", "capabilities": %s }, ' \
    "$(dev_kit_global_context_capabilities_json)"
  printf '{ "id": "review_config", "type": "read", "label": "Review environment config overrides", "status": "%s", "path": "%s", "exists": %s, "disabled_tools": %s, "disabled_credentials": %s }' \
    "$(dev_kit_json_escape "$config_status")" \
    "$(dev_kit_json_escape "$config_path")" \
    "$([ -f "$config_path" ] && printf 'true' || printf 'false')" \
    "$(printf '%s' "$disabled_tools" | dev_kit_lines_to_json_array)" \
    "$(printf '%s' "$disabled_credentials" | dev_kit_lines_to_json_array)"
  printf '] }'
}

dev_kit_cmd_env() {
  local format="${1:-text}"
  local manage_config=0

  if [ "$#" -ge 1 ]; then
    shift
  fi

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --config) manage_config=1 ;;
      --*)
        printf 'Unknown flag: %s\n' "$1" >&2
        printf 'Usage: dev.kit env [--json] [--config]\n' >&2
        return 1
        ;;
    esac
    shift
  done

  if [ "$manage_config" -eq 1 ]; then
    dev_kit_env_config_ensure
  fi

  local config_path disabled_tools disabled_credentials
  config_path="$(dev_kit_env_config_path)"
  disabled_tools="$(dev_kit_env_config_list "disabled_tools")"
  disabled_credentials="$(dev_kit_env_config_list "disabled_credentials")"

  if [ "$format" = "json" ]; then
    printf '{\n'
    printf '  "command": "env",\n'
    printf '  "home": "%s",\n' "$(dev_kit_json_escape "$DEV_KIT_HOME")"
    printf '  "workflow": { "id": "dev-kit", "label": "Normalize repo and environment", "jobs": [%s] },\n' "$(dev_kit_env_workflow_job_json)"
    printf '  "tools": %s,\n' "$(dev_kit_env_tools_json)"
    printf '  "capabilities": %s,\n' "$(dev_kit_global_context_capabilities_json)"
    printf '  "config": {\n'
    printf '    "path": "%s",\n' "$(dev_kit_json_escape "$config_path")"
    printf '    "exists": %s,\n' "$([ -f "$config_path" ] && printf 'true' || printf 'false')"
    printf '    "disabled_tools": %s,\n' "$(printf '%s' "$disabled_tools" | dev_kit_lines_to_json_array)"
    printf '    "disabled_credentials": %s\n' "$(printf '%s' "$disabled_credentials" | dev_kit_lines_to_json_array)"
    printf '  }\n'
    printf '}\n'
    return 0
  fi

  dev_kit_output_title "dev.kit env"

  dev_kit_output_section "workflow"
  dev_kit_output_row "job" "env"
  dev_kit_output_row "status" "$(dev_kit_env_workflow_status)"
  dev_kit_output_list_from_lines <<EOF
$(dev_kit_env_workflow_step_summaries)
EOF

  local _env_line _env_cat _env_val _prev_cat=""
  while IFS= read -r _env_line; do
    [ -n "$_env_line" ] || continue
    _env_cat="${_env_line%%|*}"
    _env_val="${_env_line#*|}"
    if [ "$_env_cat" != "$_prev_cat" ]; then
      dev_kit_output_section "$_env_cat"
      _prev_cat="$_env_cat"
    fi
    dev_kit_output_list_item "$_env_val"
  done <<EOF
$(dev_kit_env_tools_text)
EOF

  dev_kit_output_section "config"
  dev_kit_output_row "path" "$config_path"
  if [ "$manage_config" -eq 1 ]; then
    dev_kit_output_list_item "Config ensured. Edit the file to disable tools or credential use."
  fi
  if [ -n "$disabled_tools" ]; then
    dev_kit_output_row "disabled tools" "$(printf '%s' "$disabled_tools" | dev_kit_lines_to_csv)"
  fi
  if [ -n "$disabled_credentials" ]; then
    dev_kit_output_row "disabled creds" "$(printf '%s' "$disabled_credentials" | dev_kit_lines_to_csv)"
  fi
  if [ -z "$disabled_tools" ] && [ -z "$disabled_credentials" ]; then
    dev_kit_output_list_item "No tool or credential overrides configured."
  fi
}
