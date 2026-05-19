#!/usr/bin/env bash

dev_kit_repo_has_reusable_workflow_contract() {
  local repo_dir="$1"
  if [ -n "$(dev_kit_repo_reusable_workflow_contract_files "$repo_dir")" ]; then
    return 0
  fi

  return 1
}

dev_kit_repo_contract_manifest_versioned_files() {
  local repo_dir="$1"
  local manifest_rel=""
  local manifest_path=""

  while IFS= read -r manifest_rel; do
    [ -n "$manifest_rel" ] || continue
    manifest_path="${repo_dir}/${manifest_rel}"
    [ -f "$manifest_path" ] || continue
    if [ -n "$(dev_kit_manifest_version_value "$manifest_path")" ]; then
      printf '%s\n' "$manifest_rel"
    fi
  done <<EOF
$(dev_kit_repo_contract_manifest_files "$repo_dir")
EOF
}

dev_kit_repo_has_contract_manifest_surface() {
  local repo_dir="$1"

  [ -n "$(dev_kit_repo_contract_manifest_files "$repo_dir")" ]
}

dev_kit_repo_has_meaningful_dependency_contract() {
  local repo_dir="$1"

  if dev_kit_repo_has_reusable_workflow_contract "$repo_dir"; then
    return 0
  fi

  if dev_kit_repo_has_any_file_from_list "$repo_dir" "container_files"; then
    return 0
  fi

  if dev_kit_repo_has_any_file_from_list "$repo_dir" "dependency_trace_compose_files"; then
    return 0
  fi

  if [ -n "$(dev_kit_repo_contract_manifest_versioned_files "$repo_dir")" ]; then
    return 0
  fi

  return 1
}

dev_kit_repo_factor_applicable() {
  local repo_dir="$1"
  local factor="$2"

  case "$factor" in
    documentation|config|pipeline)
      return 0
      ;;
    dependencies)
      if dev_kit_repo_has_meaningful_dependency_contract "$repo_dir" || \
         dev_kit_repo_has_contract_manifest_surface "$repo_dir"; then
        return 0
      fi
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

dev_kit_repo_factor_status() {
  local repo_dir="$1"
  local factor="$2"
  local _ck="fstatus:${repo_dir}:${factor}"
  local _cv
  if _cv="$(dev_kit_cache_get "$_ck")"; then
    printf '%s' "$_cv"; return 0
  fi
  local _result
  _result="$(_dev_kit_repo_factor_status_compute "$repo_dir" "$factor")"
  dev_kit_cache_set "$_ck" "$_result"
  printf '%s' "$_result"
}

_dev_kit_repo_factor_status_compute() {
  local repo_dir="$1"
  local factor="$2"
  local present_threshold=""
  local partial_threshold=""

  if ! dev_kit_repo_factor_applicable "$repo_dir" "$factor"; then
    printf "%s" "not_applicable"
    return 0
  fi

  case "$factor" in
    documentation)
      # README or docs/ is enough — no deep validation needed
      if dev_kit_repo_has_any_file_from_list "$repo_dir" "documentation_files" || \
         dev_kit_repo_has_any_file_from_list "$repo_dir" "documentation_hub_files"; then
        printf "%s" "present"
      else
        printf "%s" "missing"
      fi
      ;;
    dependencies)
      if dev_kit_repo_has_meaningful_dependency_contract "$repo_dir"; then
        printf "%s" "present"
      elif dev_kit_repo_has_contract_manifest_surface "$repo_dir"; then
        printf "%s" "partial"
      else
        printf "%s" "missing"
      fi
      ;;
    config)
      if dev_kit_repo_has_any_file_from_list "$repo_dir" "config_contract_files"; then
        printf "%s" "present"
      elif dev_kit_repo_has_any_file_from_list "$repo_dir" "config_runtime_files" || dev_kit_repo_documented_env_var "$repo_dir"; then
        printf "%s" "partial"
      else
        printf "%s" "missing"
      fi
      ;;
    pipeline)
      # CI/CD pipeline: workflows, test commands, deploy configs are all the same signal.
      if dev_kit_repo_has_any_glob_from_list "$repo_dir" "workflow_globs" && \
         (dev_kit_repo_has_make_target "$repo_dir" "test" || \
          dev_kit_repo_has_node_test_script "$repo_dir" || \
          dev_kit_repo_has_composer_test_script "$repo_dir" || \
          dev_kit_repo_has_any_file_from_list "$repo_dir" "deploy_files"); then
        printf "%s" "present"
      elif dev_kit_repo_has_any_glob_from_list "$repo_dir" "workflow_globs" || \
           dev_kit_repo_has_any_dir_from_list "$repo_dir" "test_dirs" || \
           dev_kit_repo_has_any_file_from_list "$repo_dir" "deploy_files" || \
           dev_kit_repo_has_any_file_from_list "$repo_dir" "container_files"; then
        printf "%s" "partial"
      else
        printf "%s" "missing"
      fi
      ;;
    *)
      printf "%s" "unknown"
      ;;
  esac
}

dev_kit_repo_factor_evidence() {
  local repo_dir="$1"
  local factor="$2"
  local evidence=""
  local documented=""
  local path=""
  local pattern=""

  if ! dev_kit_repo_factor_applicable "$repo_dir" "$factor"; then
    printf "%s\n" "not applicable"
    return 0
  fi

  case "$factor" in
    documentation)
      while IFS= read -r path; do
        [ -n "$path" ] || continue
        if dev_kit_has_file "$repo_dir" "$path"; then
          evidence="${evidence}${path}
"
        fi
      done <<EOF
$(printf '%s\n%s\n' "$(dev_kit_detection_list "documentation_files")" "$(dev_kit_detection_list "documentation_hub_files")")
EOF
      while IFS= read -r path; do
        [ -n "$path" ] || continue
        if dev_kit_repo_has_dir "$repo_dir" "$path"; then
          evidence="${evidence}${path}/
"
        fi
      done <<EOF
$(dev_kit_detection_list "example_dirs")
EOF
      if dev_kit_repo_has_documentation_sections "$repo_dir"; then
        evidence="${evidence}structured docs sections
"
      fi
      ;;
    dependencies)
      if dev_kit_repo_has_reusable_workflow_contract "$repo_dir"; then
        evidence="${evidence}reusable workflow ref
"
      fi
      while IFS= read -r path; do
        [ -n "$path" ] || continue
        if dev_kit_has_file "$repo_dir" "$path"; then
          evidence="${evidence}image contract: ${path}
"
        fi
      done <<EOF
$(printf '%s\n%s\n' "$(dev_kit_detection_list "container_files")" "$(dev_kit_detection_list "dependency_trace_compose_files")")
EOF
      while IFS= read -r path; do
        [ -n "$path" ] || continue
        evidence="${evidence}versioned manifest: ${path}
"
      done <<EOF
$(dev_kit_repo_contract_manifest_versioned_files "$repo_dir")
EOF
      while IFS= read -r path; do
        [ -n "$path" ] || continue
        case "$evidence" in
          *"versioned manifest: ${path}"*) continue ;;
        esac
        evidence="${evidence}custom manifest surface: ${path}
"
      done <<EOF
$(dev_kit_repo_contract_manifest_files "$repo_dir")
EOF
      ;;
    config)
      while IFS= read -r path; do
        [ -n "$path" ] || continue
        if dev_kit_has_file "$repo_dir" "$path"; then
          evidence="${evidence}env contract: ${path}
"
        fi
      done <<EOF
$(dev_kit_detection_list "config_contract_files")
EOF
      while IFS= read -r path; do
        [ -n "$path" ] || continue
        if dev_kit_has_file "$repo_dir" "$path"; then
          evidence="${evidence}runtime config: ${path}
"
        fi
      done <<EOF
$(dev_kit_detection_list "config_runtime_files")
EOF
      while IFS= read -r path; do
        [ -n "$path" ] || continue
        evidence="${evidence}env vars documented in ${path}
"
      done <<EOF
$(dev_kit_repo_documented_env_var_sources "$repo_dir")
EOF
      ;;
    pipeline)
      # Test signals
      if dev_kit_repo_has_make_target "$repo_dir" "test"; then
        evidence="${evidence}Makefile:test
"
      fi
      if dev_kit_repo_has_node_test_script "$repo_dir"; then
        evidence="${evidence}package.json scripts.test
"
      fi
      if dev_kit_repo_has_composer_test_script "$repo_dir"; then
        evidence="${evidence}composer.json scripts.test
"
      fi
      while IFS= read -r path; do
        [ -n "$path" ] || continue
        if dev_kit_has_file "$repo_dir" "$path" || dev_kit_repo_has_dir "$repo_dir" "$path"; then
          evidence="${evidence}${path}
"
        fi
      done <<EOF
$(dev_kit_detection_list "test_dirs")
EOF
      # Deploy/CI signals
      while IFS= read -r path; do
        [ -n "$path" ] || continue
        if dev_kit_has_file "$repo_dir" "$path"; then
          evidence="${evidence}${path}
"
        fi
      done <<EOF
$(dev_kit_detection_list "deploy_files")
EOF
      while IFS= read -r pattern; do
        [ -n "$pattern" ] || continue
        if dev_kit_repo_has_glob "$repo_dir" "$pattern"; then
          evidence="${evidence}${pattern}
"
        fi
      done <<EOF
$(dev_kit_detection_list "workflow_globs")
EOF
      ;;
    *)
      ;;
  esac

  if [ -z "$evidence" ]; then
    printf "%s\n" "none"
    return 0
  fi

  printf "%s" "$evidence" | awk '!seen[$0]++'
}

dev_kit_repo_factor_evidence_json() {
  dev_kit_repo_factor_evidence "$1" "$2" | dev_kit_lines_to_json_array
}

dev_kit_repo_factor_summary_json() {
  local repo_dir="$1"
  local factor=""
  local status=""
  local first=1

  printf "{"
  while IFS= read -r factor; do
    status="$(dev_kit_repo_factor_status "$repo_dir" "$factor")"
    if [ "$first" -eq 0 ]; then
      printf ","
    fi
    printf '\n    "%s": {' "$factor"
    printf '\n      "status": "%s",' "$status"
    printf '\n      "evidence": '
    dev_kit_repo_factor_evidence_json "$repo_dir" "$factor"
    if [ "$status" = "missing" ] || [ "$status" = "partial" ]; then
      local _msg _repair _reference
      _msg="$(dev_kit_repo_factor_message "$repo_dir" "$factor" "$status" 2>/dev/null || true)"
      _repair="$(dev_kit_repo_factor_repair_target "$repo_dir" "$factor" "$status" 2>/dev/null || true)"
      _reference="$(dev_kit_repo_factor_reference "$repo_dir" "$factor" "$status" 2>/dev/null || true)"
      [ -n "$_msg" ] && printf ',\n      "message": "%s"' "$(dev_kit_json_escape "$_msg")"
      [ -n "$_repair" ] && printf ',\n      "repair_target": "%s"' "$(dev_kit_json_escape "$_repair")"
      [ -n "$_reference" ] && printf ',\n      "reference": "%s"' "$(dev_kit_json_escape "$_reference")"
    fi
    if dev_kit_repo_factor_entrypoint "$repo_dir" "$factor" >/dev/null 2>&1; then
      printf ',\n      "entrypoint": "%s"\n    }' "$(dev_kit_repo_factor_entrypoint "$repo_dir" "$factor")"
    else
      printf '\n    }'
    fi
    first=0
  done <<EOF
$(dev_kit_repo_factor_ids)
EOF
  printf '\n  }'
}

dev_kit_repo_command_kind_id() {
  case "$1" in
    pipeline|verify|verification) printf '%s' "verify" ;;
    build|build_release_run)       printf '%s' "build" ;;
    run|runtime)                   printf '%s' "run" ;;
    *) return 1 ;;
  esac
}

dev_kit_repo_command_detection_result() {
  local repo_dir="$1"
  local kind="$2"
  local command_kind=""
  local source_type=""

  command_kind="$(dev_kit_repo_command_kind_id "$kind" 2>/dev/null || true)"
  [ -n "$command_kind" ] || return 1

  while IFS= read -r source_type; do
    [ -n "$source_type" ] || continue
    case "$source_type:$command_kind" in
      make_targets:verify)
        if dev_kit_repo_has_make_target "$repo_dir" "test"; then
          printf '%s|%s|%s\n' "make_targets" "make test" "Makefile"
          return 0
        fi
        ;;
      make_targets:build)
        if dev_kit_repo_has_make_target "$repo_dir" "build"; then
          printf '%s|%s|%s\n' "make_targets" "make build" "Makefile"
          return 0
        fi
        ;;
      make_targets:run)
        if dev_kit_repo_has_make_target "$repo_dir" "run"; then
          printf '%s|%s|%s\n' "make_targets" "make run" "Makefile"
          return 0
        fi
        ;;
      package_scripts:verify)
        if dev_kit_repo_has_node_test_script "$repo_dir"; then
          printf '%s|%s|%s\n' "package_scripts" "npm test" "package.json"
          return 0
        fi
        if dev_kit_repo_has_composer_test_script "$repo_dir"; then
          printf '%s|%s|%s\n' "package_scripts" "composer test" "composer.json"
          return 0
        fi
        ;;
      package_scripts:build)
        if dev_kit_repo_has_node_build_script "$repo_dir"; then
          printf '%s|%s|%s\n' "package_scripts" "npm run build" "package.json"
          return 0
        fi
        if dev_kit_repo_has_composer_build_script "$repo_dir"; then
          printf '%s|%s|%s\n' "package_scripts" "composer build" "composer.json"
          return 0
        fi
        ;;
      package_scripts:run)
        if dev_kit_repo_has_node_start_script "$repo_dir"; then
          printf '%s|%s|%s\n' "package_scripts" "npm start" "package.json"
          return 0
        fi
        ;;
      documented_commands:verify)
        local documented_command documented_source
        documented_command="$(dev_kit_repo_documented_command "$repo_dir" "verification" || true)"
        documented_source="$(dev_kit_repo_documented_command_source "$repo_dir" "verification" || true)"
        if [ -n "$documented_command" ]; then
          printf '%s|%s|%s\n' "documented_commands" "$documented_command" "$documented_source"
          return 0
        fi
        ;;
      documented_commands:build)
        local documented_command documented_source
        documented_command="$(dev_kit_repo_documented_command "$repo_dir" "build" || true)"
        documented_source="$(dev_kit_repo_documented_command_source "$repo_dir" "build" || true)"
        if [ -n "$documented_command" ]; then
          printf '%s|%s|%s\n' "documented_commands" "$documented_command" "$documented_source"
          return 0
        fi
        ;;
      documented_commands:run)
        local documented_command documented_source
        documented_command="$(dev_kit_repo_documented_command "$repo_dir" "run" || true)"
        documented_source="$(dev_kit_repo_documented_command_source "$repo_dir" "run" || true)"
        if [ -n "$documented_command" ]; then
          printf '%s|%s|%s\n' "documented_commands" "$documented_command" "$documented_source"
          return 0
        fi
        ;;
    esac
  done <<EOF
$(dev_kit_context_section_list "commands" "prefer_sources")
EOF

  return 1
}

dev_kit_repo_factor_entrypoint() {
  local repo_dir="$1"
  local kind="$2"
  local result=""

  result="$(dev_kit_repo_command_detection_result "$repo_dir" "$kind" 2>/dev/null || true)"
  [ -n "$result" ] || return 1
  printf "%s" "$(printf '%s' "$result" | cut -d'|' -f2)"
}

dev_kit_repo_factor_ids() {
  printf '%s\n' documentation dependencies config pipeline
}

dev_kit_repo_first_existing_signal() {
  local repo_dir="$1"
  local list_name="$2"
  local path=""

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if dev_kit_has_file "$repo_dir" "$path" || dev_kit_repo_has_dir "$repo_dir" "$path"; then
      printf '%s' "$path"
      return 0
    fi
  done <<EOF
$(dev_kit_detection_list "$list_name")
EOF

  return 1
}

dev_kit_repo_factor_message() {
  local repo_dir="$1"
  local factor="$2"
  local status="$3"
  local rule_id=""
  local fallback=""
  local runtime_config=""
  local config_doc=""
  local manifest_path=""
  local workflow_path=""
  local test_path=""
  local deploy_path=""
  local container_path=""
  local found=""

  rule_id="$(dev_kit_repo_factor_rule_id "$factor" "$status" 2>/dev/null || true)"
  fallback="$([ -n "$rule_id" ] && dev_kit_rule_message "$rule_id" || printf '%s is %s' "$factor" "$status")"

  case "${factor}:${status}" in
    config:partial)
      runtime_config="$(dev_kit_repo_first_existing_signal "$repo_dir" "config_runtime_files" 2>/dev/null || true)"
      config_doc="$(dev_kit_repo_documented_env_var_sources "$repo_dir" | awk 'NF { print; exit }')"
      if [ -n "$runtime_config" ] && [ -n "$config_doc" ]; then
        printf '%s' "Found config-bearing repo assets in ${runtime_config} and documented config in ${config_doc}, but no single checked-in config contract is declared yet."
        return 0
      fi
      if [ -n "$runtime_config" ]; then
        printf '%s' "Found config-bearing repo assets in ${runtime_config}, but no canonical checked-in config contract is declared yet."
        return 0
      fi
      if [ -n "$config_doc" ]; then
        printf '%s' "Configuration is documented in ${config_doc}, but the repo does not declare a canonical checked-in config contract yet."
        return 0
      fi
      ;;
    config:missing)
      printf '%s' "No repo-owned configuration contract was found in docs, manifests, or checked-in example files."
      return 0
      ;;
    dependencies:partial)
      manifest_path="$(dev_kit_repo_contract_manifest_files "$repo_dir" | awk 'NF { print; exit }')"
      if [ -n "$manifest_path" ]; then
        printf '%s' "Found custom manifest surface in ${manifest_path}, but the dependency contract is not traced clearly yet."
        return 0
      fi
      ;;
    pipeline:partial)
      workflow_path="$(dev_kit_repo_find_from_glob_list "$repo_dir" "workflow_globs" | awk -v repo="$repo_dir/" 'NF { sub("^" repo, ""); print; exit }')"
      test_path="$(dev_kit_repo_first_existing_signal "$repo_dir" "test_dirs" 2>/dev/null || true)"
      deploy_path="$(dev_kit_repo_first_existing_signal "$repo_dir" "deploy_files" 2>/dev/null || true)"
      container_path="$(dev_kit_repo_first_existing_signal "$repo_dir" "container_files" 2>/dev/null || true)"
      [ -n "$workflow_path" ] && found="$workflow_path"
      [ -n "$test_path" ] && found="${found:+$found, }$test_path"
      [ -n "$deploy_path" ] && found="${found:+$found, }$deploy_path"
      [ -n "$container_path" ] && found="${found:+$found, }$container_path"
      if [ -n "$found" ]; then
        printf '%s' "Found partial pipeline signals in ${found}, but the repo does not declare a complete validation/deploy contract yet."
        return 0
      fi
      ;;
  esac

  printf '%s' "$fallback"
}

dev_kit_repo_factor_repair_target() {
  local repo_dir="$1"
  local factor="$2"
  local status="$3"
  local runtime_config=""
  local config_doc=""
  local first_doc=""
  local first_manifest=""
  local first_workflow=""

  case "${factor}:${status}" in
    documentation:missing)
      if dev_kit_has_file "$repo_dir" "README.md"; then
        printf '%s' "README.md"
        return 0
      fi
      printf '%s' "README.md or docs/"
      return 0
      ;;
    dependencies:partial)
      first_manifest="$(dev_kit_repo_contract_manifest_files "$repo_dir" | awk 'NF { print; exit }')"
      if [ -n "$first_manifest" ]; then
        printf '%s' "$first_manifest"
        return 0
      fi
      first_workflow="$(dev_kit_repo_first_existing_signal "$repo_dir" "workflow_primary_files" 2>/dev/null || true)"
      if [ -n "$first_workflow" ]; then
        printf '%s' "$first_workflow"
        return 0
      fi
      printf '%s' "deploy.yml or .github/workflows/"
      return 0
      ;;
    dependencies:missing)
      first_workflow="$(dev_kit_repo_first_existing_signal "$repo_dir" "workflow_primary_files" 2>/dev/null || true)"
      if [ -n "$first_workflow" ]; then
        printf '%s' "$first_workflow"
        return 0
      fi
      printf '%s' "deploy.yml or .github/workflows/"
      return 0
      ;;
    config:partial)
      runtime_config="$(dev_kit_repo_first_existing_signal "$repo_dir" "config_runtime_files" 2>/dev/null || true)"
      config_doc="$(dev_kit_repo_documented_env_var_sources "$repo_dir" | awk 'NF { print; exit }')"
      if [ -n "$config_doc" ] && [ -n "$runtime_config" ]; then
        printf '%s' "${config_doc} or .env.example"
        return 0
      fi
      if [ -n "$config_doc" ]; then
        printf '%s' "${config_doc} or .env.example"
        return 0
      fi
      if [ -n "$runtime_config" ]; then
        printf '%s' "${runtime_config} or .env.example"
        return 0
      fi
      printf '%s' ".env.example or repo config docs"
      return 0
      ;;
    config:missing)
      if dev_kit_has_file "$repo_dir" "README.md"; then
        printf '%s' "README.md or .env.example"
        return 0
      fi
      printf '%s' ".env.example or docs/config.md"
      return 0
      ;;
    pipeline:partial|pipeline:missing)
      if dev_kit_has_file "$repo_dir" "package.json"; then
        printf '%s' "package.json scripts.test"
        return 0
      fi
      if dev_kit_has_file "$repo_dir" "composer.json"; then
        printf '%s' "composer.json scripts.test"
        return 0
      fi
      if dev_kit_has_file "$repo_dir" "Makefile"; then
        printf '%s' "Makefile:test"
        return 0
      fi
      first_workflow="$(dev_kit_repo_first_existing_signal "$repo_dir" "workflow_primary_files" 2>/dev/null || true)"
      if [ -n "$first_workflow" ]; then
        printf '%s' "$first_workflow"
        return 0
      fi
      printf '%s' ".github/workflows/ or canonical verify command"
      return 0
      ;;
  esac

  first_doc="$(dev_kit_repo_first_existing_signal "$repo_dir" "documentation_files" 2>/dev/null || true)"
  [ -n "$first_doc" ] && printf '%s' "$first_doc"
}

dev_kit_repo_prefers_internal_references() {
  local repo_dir="$1"
  local repo_name=""
  local repo_slug=""
  local real_repo_dir=""

  repo_name="$(dev_kit_repo_name "$repo_dir" 2>/dev/null || true)"
  repo_slug="$(dev_kit_repo_current_slug "$repo_dir" "$repo_name" 2>/dev/null || true)"
  real_repo_dir="$(cd "$repo_dir" 2>/dev/null && pwd || true)"

  [ "$real_repo_dir" = "$REPO_DIR" ] || { [ "$repo_slug" = "udx/dev.kit" ] && [ "$repo_name" = "dev.kit" ]; }
}

dev_kit_repo_reference_doc_default() {
  local repo_dir="$1"
  local first_doc=""

  first_doc="$(dev_kit_repo_first_existing_signal "$repo_dir" "documentation_files" 2>/dev/null || true)"
  if [ -n "$first_doc" ]; then
    printf '%s' "$first_doc"
    return 0
  fi

  if dev_kit_repo_has_dir "$repo_dir" "docs"; then
    printf '%s' "docs/"
    return 0
  fi

  printf '%s' "README.md"
}

dev_kit_repo_dependency_reference_local() {
  local repo_dir="$1"
  local first_manifest=""
  local first_workflow=""

  first_manifest="$(dev_kit_repo_contract_manifest_files "$repo_dir" | awk 'NF { print; exit }')"
  if [ -n "$first_manifest" ]; then
    printf '%s' "$first_manifest"
    return 0
  fi

  first_workflow="$(dev_kit_repo_first_existing_signal "$repo_dir" "workflow_primary_files" 2>/dev/null || true)"
  if [ -n "$first_workflow" ]; then
    printf '%s' "$first_workflow"
    return 0
  fi

  if dev_kit_has_file "$repo_dir" "deploy.yml"; then
    printf '%s' "deploy.yml"
    return 0
  fi

  dev_kit_repo_reference_doc_default "$repo_dir"
}

dev_kit_repo_config_reference_local() {
  local repo_dir="$1"
  local runtime_config=""
  local config_doc=""

  config_doc="$(dev_kit_repo_documented_env_var_sources "$repo_dir" | awk 'NF { print; exit }')"
  if [ -n "$config_doc" ]; then
    printf '%s' "$config_doc"
    return 0
  fi

  runtime_config="$(dev_kit_repo_first_existing_signal "$repo_dir" "config_runtime_files" 2>/dev/null || true)"
  if [ -n "$runtime_config" ]; then
    printf '%s' "$runtime_config"
    return 0
  fi

  if dev_kit_has_file "$repo_dir" ".env.example"; then
    printf '%s' ".env.example"
    return 0
  fi

  dev_kit_repo_reference_doc_default "$repo_dir"
}

dev_kit_repo_pipeline_reference_local() {
  local repo_dir="$1"
  local verify_source=""
  local first_workflow=""

  verify_source="$(dev_kit_repo_command_detection_result "$repo_dir" "verification" 2>/dev/null | cut -d'|' -f3)"
  if [ -n "$verify_source" ]; then
    printf '%s' "$verify_source"
    return 0
  fi

  first_workflow="$(dev_kit_repo_first_existing_signal "$repo_dir" "workflow_primary_files" 2>/dev/null || true)"
  if [ -n "$first_workflow" ]; then
    printf '%s' "$first_workflow"
    return 0
  fi

  if dev_kit_has_file "$repo_dir" "deploy.yml"; then
    printf '%s' "deploy.yml"
    return 0
  fi

  dev_kit_repo_reference_doc_default "$repo_dir"
}

dev_kit_repo_factor_reference() {
  local repo_dir=""
  local factor="$1"
  local status="$2"

  if [ "$#" -ge 3 ]; then
    repo_dir="$1"
    factor="$2"
    status="$3"
  fi

  if [ -n "$repo_dir" ] && ! dev_kit_repo_prefers_internal_references "$repo_dir"; then
    case "${factor}:${status}" in
      dependencies:partial|dependencies:missing)
        dev_kit_repo_dependency_reference_local "$repo_dir"
        ;;
      config:partial|config:missing)
        dev_kit_repo_config_reference_local "$repo_dir"
        ;;
      pipeline:partial|pipeline:missing)
        dev_kit_repo_pipeline_reference_local "$repo_dir"
        ;;
    esac
    return 0
  fi

  case "${factor}:${status}" in
    dependencies:partial|dependencies:missing)
      printf '%s' "docs/references/dependency-contracts.md"
      ;;
    config:partial|config:missing)
      printf '%s' "docs/references/config-contract-surfaces.md"
      ;;
    pipeline:partial|pipeline:missing)
      printf '%s' "docs/references/command-surfaces.md"
      ;;
  esac
}

dev_kit_repo_factor_rule_id() {
  local factor="$1"
  local status="$2"

  case "${factor}:${status}" in
    documentation:missing) printf "%s" "missing-documentation" ;;
    dependencies:missing) printf "%s" "missing-dependency-contract" ;;
    dependencies:partial) printf "%s" "partial-dependency-contract" ;;
    config:missing) printf "%s" "missing-config-contract" ;;
    config:partial) printf "%s" "partial-config-contract" ;;
    pipeline:missing) printf "%s" "missing-pipeline" ;;
    pipeline:partial) printf "%s" "partial-pipeline" ;;
    *) return 1 ;;
  esac
}
