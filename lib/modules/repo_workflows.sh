#!/usr/bin/env bash

dev_kit_repo_entrypoints_json() {
  local repo_dir="$1"
  local verify_cmd=""
  local build_cmd=""
  local run_cmd=""

  verify_cmd="$(dev_kit_repo_factor_entrypoint "$repo_dir" "verification" || true)"
  build_cmd="$(dev_kit_repo_factor_entrypoint "$repo_dir" "build_release_run" || true)"
  run_cmd="$(dev_kit_repo_factor_entrypoint "$repo_dir" "runtime" || true)"

  printf '{ "verify": %s, "build": %s, "run": %s }' \
    "$(if [ -n "$verify_cmd" ]; then printf '"%s"' "$(dev_kit_json_escape "$verify_cmd")"; else printf 'null'; fi)" \
    "$(if [ -n "$build_cmd" ]; then printf '"%s"' "$(dev_kit_json_escape "$build_cmd")"; else printf 'null'; fi)" \
    "$(if [ -n "$run_cmd" ]; then printf '"%s"' "$(dev_kit_json_escape "$run_cmd")"; else printf 'null'; fi)"
}

dev_kit_repo_entrypoint_source() {
  local repo_dir="$1"
  local kind="$2"
  local result=""

  result="$(dev_kit_repo_command_detection_result "$repo_dir" "$kind" 2>/dev/null || true)"
  [ -n "$result" ] || return 1
  printf "%s" "$(printf '%s' "$result" | cut -d'|' -f3)"
}

dev_kit_repo_gap_count() {
  local repo_dir="$1"
  local factor=""
  local status=""
  local gap_count=0

  while IFS= read -r factor; do
    [ -n "$factor" ] || continue
    status="$(dev_kit_repo_factor_status "$repo_dir" "$factor")"
    case "$status" in
      missing|partial)
        gap_count=$((gap_count + 1))
        ;;
    esac
  done <<EOF
$(dev_kit_repo_factor_ids)
EOF

  printf '%s' "$gap_count"
}

dev_kit_repo_workflow_status() {
  local repo_dir="$1"
  local gap_count="${2:-}"

  if [ -z "$gap_count" ]; then
    gap_count="$(dev_kit_repo_gap_count "$repo_dir")"
  fi

  if [ "${gap_count:-0}" -gt 0 ]; then
    printf '%s' "needs_repair"
    return 0
  fi

  printf '%s' "ready"
}

dev_kit_repo_workflow_steps() {
  local repo_dir="$1"
  local verify_cmd=""
  local build_cmd=""
  local run_cmd=""
  local context_path=""
  local gap_count=0

  printf "read_repo|Read the highest-priority repo refs first|%s\n" "$(dev_kit_repo_priority_refs "$repo_dir" | dev_kit_lines_to_csv)"

  verify_cmd="$(dev_kit_repo_factor_entrypoint "$repo_dir" "verification" || true)"
  if [ -n "$verify_cmd" ]; then
    printf "verify|Run the canonical verification command|%s\n" "$verify_cmd"
  fi

  build_cmd="$(dev_kit_repo_factor_entrypoint "$repo_dir" "build_release_run" || true)"
  if [ -n "$build_cmd" ]; then
    printf "build|Run the canonical build command when needed|%s\n" "$build_cmd"
  fi

  run_cmd="$(dev_kit_repo_factor_entrypoint "$repo_dir" "runtime" || true)"
  if [ -n "$run_cmd" ]; then
    printf "run|Use the canonical runtime command instead of ad hoc startup paths|%s\n" "$run_cmd"
  fi

  context_path="$(dev_kit_context_yaml_path "$repo_dir")"
  if [ -n "$context_path" ]; then
    printf "read_context|Review the generated repo contract|%s\n" "${context_path#"${repo_dir}/"}"
  fi

  gap_count="$(dev_kit_repo_gap_count "$repo_dir")"
  if [ "${gap_count:-0}" -gt 0 ]; then
    printf "confirm_repair|Confirm whether to start the repair loop|repo-owned gaps\n"
    printf "repair_loop|Repair the strongest gap and rerun dev.kit repo|repo-owned gaps\n"
  fi
}

dev_kit_repo_workflow_step_summaries() {
  local repo_dir="$1"
  local line=""
  local step_id=""
  local command=""

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    step_id="${line%%|*}"
    command="${line##*|}"
    case "$step_id" in
      read_repo)
        printf '%s\n' "Read the highest-priority repo refs."
        ;;
      verify|build|run)
        printf '%s\n' "$command"
        ;;
      read_context)
        printf '%s\n' "Review .rabbit/context.yaml."
        ;;
      confirm_repair)
        printf '%s\n' "Confirm whether to start the repo repair loop."
        ;;
      repair_loop)
        printf '%s\n' "Repair the strongest gap and rerun dev.kit repo."
        ;;
    esac
  done <<EOF
$(dev_kit_repo_workflow_steps "$repo_dir")
EOF
}

dev_kit_repo_workflow_json() {
  local repo_dir="$1"
  local line=""
  local step_id=""
  local label=""
  local command=""
  local first=1

  printf "["
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    step_id="${line%%|*}"
    line="${line#*|}"
    label="${line%%|*}"
    command="${line#*|}"
    if [ "$first" -eq 0 ]; then
      printf ", "
    fi
    if [ "$step_id" = "read_repo" ]; then
      local refs_json ref_item ref_first
      refs_json="["
      ref_first=1
      while IFS= read -r ref_item; do
        [ -n "$ref_item" ] || continue
        if [ "$ref_first" -eq 0 ]; then
          refs_json="${refs_json}, "
        fi
        refs_json="${refs_json}\"$(dev_kit_json_escape "$ref_item")\""
        ref_first=0
      done <<REFS
$(printf '%s\n' "$command" | awk '{ n=split($0,a,", "); for(i=1;i<=n;i++) if(a[i]!="") print a[i] }')
REFS
      refs_json="${refs_json}]"
      printf '{ "id": "%s", "type": "read", "label": "%s", "refs": %s }' \
        "$(dev_kit_json_escape "$step_id")" \
        "$(dev_kit_json_escape "$label")" \
        "$refs_json"
    elif [ "$step_id" = "read_context" ]; then
      printf '{ "id": "%s", "type": "read", "label": "%s", "path": "%s" }' \
        "$(dev_kit_json_escape "$step_id")" \
        "$(dev_kit_json_escape "$label")" \
        "$(dev_kit_json_escape "$command")"
    elif [ "$step_id" = "confirm_repair" ]; then
      printf '{ "id": "%s", "type": "decision", "label": "%s", "subject": "%s" }' \
        "$(dev_kit_json_escape "$step_id")" \
        "$(dev_kit_json_escape "$label")" \
        "$(dev_kit_json_escape "$command")"
    elif [ "$step_id" = "repair_loop" ]; then
      printf '{ "id": "%s", "type": "loop", "label": "%s", "subject": "%s" }' \
        "$(dev_kit_json_escape "$step_id")" \
        "$(dev_kit_json_escape "$label")" \
        "$(dev_kit_json_escape "$command")"
    else
      printf '{ "id": "%s", "type": "run", "label": "%s", "command": "%s" }' \
        "$(dev_kit_json_escape "$step_id")" \
        "$(dev_kit_json_escape "$label")" \
        "$(dev_kit_json_escape "$command")"
    fi
    first=0
  done <<EOF
$(dev_kit_repo_workflow_steps "$repo_dir")
EOF
  printf "]"
}

dev_kit_repo_workflow_job_json() {
  local repo_dir="$1"
  local status="${2:-}"
  local mode="${3:-write}"
  local context_status="${4:-current}"
  local gap_count="${5:-}"

  if [ -z "$gap_count" ]; then
    gap_count="$(dev_kit_repo_gap_count "$repo_dir")"
  fi
  if [ -z "$status" ]; then
    status="$(dev_kit_repo_workflow_status "$repo_dir" "$gap_count")"
  fi

  printf '{ "id": "repo", "label": "Build repo context", "command": "dev.kit repo", "mode": "%s", "status": "%s", "context": "%s", "context_status": "%s", "gap_count": %s, "steps": %s }' \
    "$(dev_kit_json_escape "$mode")" \
    "$(dev_kit_json_escape "$status")" \
    "$(dev_kit_json_escape "$(dev_kit_context_yaml_path "$repo_dir")")" \
    "$(dev_kit_json_escape "$context_status")" \
    "${gap_count:-0}" \
    "$(dev_kit_repo_workflow_json "$repo_dir")"
}
