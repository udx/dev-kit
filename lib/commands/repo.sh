#!/usr/bin/env bash

# @description: Analyze repo structure and factors

dev_kit_repo_recommended_repos_text() {
  dev_kit_repo_validation_list "recommended_repos"
}

dev_kit_repo_recommended_repos_json() {
  dev_kit_repo_recommended_repos_text | dev_kit_lines_to_json_array
}

dev_kit_repo_actions_json() {
  local gap_count="${1:-0}"

  if [ "$gap_count" -gt 0 ]; then
    cat <<'EOF'
[
  { "id": "read-context", "type": "read", "label": "Read .rabbit/context.yaml", "path": ".rabbit/context.yaml" },
  { "id": "confirm-research-fix-loop", "type": "user_decision", "label": "Confirm whether to start the research-and-fix loop for repo-owned gaps" },
  { "id": "repair-loop", "type": "loop", "label": "After confirmation, research the strongest gap, repair the owning repo asset, then rerun dev.kit repo" }
]
EOF
    return 0
  fi

  cat <<'EOF'
[
  { "id": "read-context", "type": "read", "label": "Read .rabbit/context.yaml", "path": ".rabbit/context.yaml" }
]
EOF
}

dev_kit_cmd_repo() {
  local format="${1:-text}"
  local repo_dir="$(pwd)"
  local mode="write"
  local repo_root=""
  local repo_name=""
  local gaps_json=""
  local actions_json=""
  local context_yaml_path=""
  local gap_lines=""
  local workflow_status=""
  local workflow_context_status=""

  local force_resolve=0
  local repo_soft_timeout="${DEV_KIT_REPO_SOFT_TIMEOUT:-15}"
  local repo_hard_timeout="${DEV_KIT_REPO_HARD_TIMEOUT:-180}"

  # Parse flags from remaining args (skip format which is first arg)
  if [ "$#" -ge 1 ]; then
    shift
  fi
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --check) mode="check" ;;
      --force) force_resolve=1 ;;
      --*)
        printf 'Unknown flag: %s\n' "$1" >&2
        printf 'Usage: dev.kit repo [--json] [--check] [--force]\n' >&2
        return 1
        ;;
      *)       repo_dir="$1" ;;
    esac
    shift
  done

  repo_root="$(dev_kit_repo_root "$repo_dir")"
  repo_dir="${repo_root:-$repo_dir}"
  repo_name="$(dev_kit_repo_name "$repo_dir")"
  context_yaml_path="$(dev_kit_context_yaml_path "$repo_dir")"
  gaps_json="$(dev_kit_scaffold_gaps_json "$repo_dir")"
  local gap_count
  gap_count="$(printf '%s\n' "$gaps_json" | grep -c '"factor"' 2>/dev/null || true)"
  gap_count="${gap_count:-0}"
  workflow_status="$(dev_kit_repo_workflow_status "$repo_dir" "$gap_count")"
  actions_json="$(dev_kit_repo_actions_json "$gap_count")"

  # JSON mode: compute everything up front then emit template
  if [ "$format" = "json" ]; then
    if [ "$mode" = "write" ]; then
      dev_kit_context_yaml_write "$repo_dir" "$force_resolve" >/dev/null
      workflow_context_status="current"
    elif [ -f "$context_yaml_path" ]; then
      workflow_context_status="existing"
    else
      workflow_context_status="missing"
    fi
    dev_kit_template_render "repo.json" \
      "command=repo" \
      "repo=$(dev_kit_json_escape "$repo_name")" \
      "path=$(dev_kit_json_escape "$repo_dir")" \
      "mode=$(dev_kit_json_escape "$mode")" \
      "archetype=$(dev_kit_json_escape "$(dev_kit_repo_primary_archetype "$repo_dir")")" \
      "markers=$(dev_kit_repo_markers_json "$repo_dir")" \
      "factors=$(dev_kit_repo_factor_summary_json "$repo_dir")" \
      "gaps=$gaps_json" \
      "actions=$actions_json" \
      "workflow={ \"id\": \"dev-kit\", \"label\": \"Normalize repo and environment\", \"jobs\": [$(dev_kit_repo_workflow_job_json "$repo_dir" "$workflow_status" "$mode" "$workflow_context_status" "$gap_count")] }" \
      "context=$(dev_kit_json_escape "$context_yaml_path")" \
      "dependencies=$(dev_kit_deps_json "$repo_dir")" \
      "recommended_repos=$(dev_kit_repo_recommended_repos_json)"
    return 0
  fi

  # Text mode: print title immediately, then compute and display progressively.
  dev_kit_output_title "dev.kit repo"

  dev_kit_spinner_start "analyzing repo"
  local archetype
  archetype="$(dev_kit_repo_primary_archetype "$repo_dir")"
  dev_kit_spinner_stop ""

  dev_kit_output_summary "${repo_name} • ${archetype} • mode: ${mode}"

  dev_kit_output_section "workflow"
  dev_kit_output_row "job" "repo"
  dev_kit_output_row "status" "$workflow_status"
  dev_kit_output_list_from_lines <<EOF
$(dev_kit_repo_workflow_step_summaries "$repo_dir")
EOF

  # ── Priority refs — what to read first ─────────────────────────────────────
  local priority_refs first_ref second_ref
  priority_refs="$(dev_kit_repo_priority_refs "$repo_dir")"
  first_ref="$(printf '%s\n' "$priority_refs" | awk 'NF { print; exit }')"
  second_ref="$(printf '%s\n' "$priority_refs" | awk 'NF { count += 1; if (count == 2) { print; exit } }')"
  if [ -n "$first_ref" ]; then
    dev_kit_output_section "read first"
    dev_kit_output_list_item "$first_ref"
    [ -n "$second_ref" ] && dev_kit_output_list_item "$second_ref"
  fi

  # ── Factors ──────────────────────────────────────────────────────────────────
  dev_kit_output_section "factors"
  local factor status
  for factor in documentation dependencies config pipeline; do
    status="$(dev_kit_repo_factor_status "$repo_dir" "$factor")"
    dev_kit_output_status_row "$factor" "$status"
  done

  # ── Gaps ─────────────────────────────────────────────────────────────────────
  if [ "$gap_count" -gt 0 ]; then
    dev_kit_output_section "gaps"
    gap_lines="$(printf '%s\n' "$gaps_json" | jq -r '.[] | "\(.factor) (\(.status)): \(.message // "needs stronger repo evidence")\n\((if (.repair_target // "") != "" then "  repair: " + .repair_target else empty end))\n\((if (.reference // "") != "" then "  reference: " + .reference else empty end))"' 2>/dev/null | awk 'NF' || true)"
    if [ -n "$gap_lines" ]; then
      while IFS= read -r gap_line; do
        [ -n "$gap_line" ] || continue
        dev_kit_output_list_item "$gap_line"
      done <<EOF
$gap_lines
EOF
    else
      dev_kit_output_list_item "${gap_count} factor(s) missing or partial"
    fi
  fi

  # ── Git state — branch and sync hints ────────────────────────────────────────
  if dev_kit_sync_has_git_repo "$repo_dir"; then
    dev_kit_output_section "git"
    dev_kit_output_list_from_lines <<EOF
$(dev_kit_sync_start_here_text "$repo_dir" | dev_kit_output_first_lines 3)
EOF
  fi

  # ── Write context.yaml ──────────────────────────────────────────────────────
  if [ "$mode" = "write" ]; then
    local write_status=0
    dev_kit_run_guarded \
      "writing context" \
      "$repo_soft_timeout" \
      "$repo_hard_timeout" \
      "repo resolving is taking longer than usual; still tracing manifests and contracts" \
      dev_kit_context_yaml_write "$repo_dir" "$force_resolve" >/dev/null
    write_status=$?
    if [ "$write_status" -ne 0 ]; then
      dev_kit_output_section "error"
      if [ "$write_status" -eq 124 ]; then
        dev_kit_output_list_item "Context write did not finish within the allowed time"
      else
        dev_kit_output_list_item "Context write failed with exit status $write_status"
      fi
      return "$write_status"
    fi
  fi

  if [ -f "$context_yaml_path" ]; then
    local dep_count manifest_count
    dep_count="$(awk '
      /^dependencies:/ { in_d = 1; next }
      in_d && /^# Manifests/ { exit }
      in_d && /^  - repo:/ { count += 1 }
      END { print count + 0 }
    ' "$context_yaml_path")"
    manifest_count="$(awk '
      /^manifests:/ { in_m = 1; next }
      in_m && /^[^[:space:]#]/ { exit }
      in_m && /^  - path:/ { count += 1 }
      END { print count + 0 }
    ' "$context_yaml_path")"
    if [ "${dep_count:-0}" -gt 0 ] || [ "${manifest_count:-0}" -gt 0 ]; then
      dev_kit_output_section "resolved"
      [ "${manifest_count:-0}" -gt 0 ] && dev_kit_output_row "manifests" "$manifest_count"
      [ "${dep_count:-0}" -gt 0 ] && dev_kit_output_row "contracts" "$dep_count"
    fi
  fi

  dev_kit_output_section "context"
  dev_kit_output_list_item "$context_yaml_path"

  dev_kit_output_section "tooling"
  dev_kit_output_list_from_lines <<EOF
$(dev_kit_repo_recommended_repos_text)
EOF

  dev_kit_output_section "next"
  dev_kit_output_row "context" "read .rabbit/context.yaml"
  if [ "$gap_count" -gt 0 ]; then
    dev_kit_output_row "decision" "confirm whether to start the research-and-fix loop now"
    dev_kit_output_row "repair" "after confirmation, research the strongest gap, repair the owning repo asset, then rerun dev.kit repo"
  fi
}
