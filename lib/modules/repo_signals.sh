#!/usr/bin/env bash

DEV_KIT_REPO_ROOT_CACHE_INPUT=""
DEV_KIT_REPO_ROOT_CACHE_VALUE=""
DEV_KIT_REPO_MARKERS_CACHE_REPO=""
DEV_KIT_REPO_MARKERS_CACHE_VALUE=""

dev_kit_detection_catalog_path() {
  printf "%s" "$REPO_DIR/src/configs/detection-patterns.yaml"
}

dev_kit_detection_signals_path() {
  printf "%s" "$REPO_DIR/src/configs/detection-signals.yaml"
}

dev_kit_detection_pattern() {
  local kind="$1"

  dev_kit_yaml_mapping_scalar "$(dev_kit_detection_catalog_path)" "command_patterns" "$kind"
}

dev_kit_detection_list() {
  local list_name="$1"

  dev_kit_yaml_config_list "$(dev_kit_detection_signals_path)" "$list_name"
}

dev_kit_repo_name() {
  basename "${1:-$(pwd)}"
}

dev_kit_repo_has_root_file_marker() {
  local repo_dir="$1"
  local path=""

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if dev_kit_has_file "$repo_dir" "$path"; then
      return 0
    fi
  done <<EOF
$(dev_kit_context_list "repo_root_files")
EOF

  return 1
}

dev_kit_repo_has_root_dir_marker() {
  local repo_dir="$1"
  local path=""

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if dev_kit_repo_has_dir "$repo_dir" "$path"; then
      return 0
    fi
  done <<EOF
$(dev_kit_context_list "repo_root_dirs")
EOF

  return 1
}

dev_kit_repo_has_root_marker() {
  local repo_dir="${1:-$(pwd)}"

  if [ -d "$repo_dir/.git" ]; then
    return 0
  fi

  if dev_kit_repo_has_root_file_marker "$repo_dir"; then
    return 0
  fi

  if dev_kit_repo_has_root_dir_marker "$repo_dir"; then
    return 0
  fi

  if dev_kit_has_file "$repo_dir" ".github/workflows" || dev_kit_repo_has_dir "$repo_dir" ".github/workflows"; then
    return 0
  fi

  return 1
}

dev_kit_repo_root() {
  local input_dir="${1:-$(pwd)}"
  local repo_dir=""
  local parent_dir=""

  repo_dir="$(cd "$input_dir" 2>/dev/null && pwd || printf '%s' "$input_dir")"

  if [ "$DEV_KIT_REPO_ROOT_CACHE_INPUT" = "$repo_dir" ]; then
    printf "%s" "$DEV_KIT_REPO_ROOT_CACHE_VALUE"
    return 0
  fi

  while [ -n "$repo_dir" ] && [ "$repo_dir" != "/" ]; do
    if dev_kit_repo_has_root_marker "$repo_dir"; then
      DEV_KIT_REPO_ROOT_CACHE_INPUT="$input_dir"
      DEV_KIT_REPO_ROOT_CACHE_VALUE="$repo_dir"
      printf "%s" "$repo_dir"
      return 0
    fi
    parent_dir="$(dirname "$repo_dir")"
    [ "$parent_dir" = "$repo_dir" ] && break
    repo_dir="$parent_dir"
  done

  DEV_KIT_REPO_ROOT_CACHE_INPUT="$input_dir"
  DEV_KIT_REPO_ROOT_CACHE_VALUE=""
}

dev_kit_repo_looks_like_repo() {
  [ -n "$(dev_kit_repo_root "${1:-$(pwd)}")" ]
}

dev_kit_repo_marker_lines() {
  local repo_dir="${1:-$(pwd)}"
  local marker_group=""
  local marker_kind=""
  local marker_prefix=""
  local path=""
  local markers=""

  if [ "$DEV_KIT_REPO_MARKERS_CACHE_REPO" = "$repo_dir" ]; then
    printf "%s" "$DEV_KIT_REPO_MARKERS_CACHE_VALUE"
    return 0
  fi

  DEV_KIT_REPO_MARKERS_CACHE_REPO="$repo_dir"
  while IFS= read -r marker_group; do
    [ -n "$marker_group" ] || continue
    marker_kind="$(dev_kit_context_marker_group_field "$marker_group" "kind")"
    marker_prefix="$(dev_kit_context_marker_group_field "$marker_group" "prefix")"
    [ -n "$marker_kind" ] || continue
    [ -n "$marker_prefix" ] || continue

    while IFS= read -r path; do
      [ -n "$path" ] || continue
      case "$marker_kind" in
        file)
          if dev_kit_has_file "$repo_dir" "$path"; then
            markers="${markers}${marker_prefix}:${path}
"
          fi
          ;;
        dir)
          if dev_kit_repo_has_dir "$repo_dir" "$path"; then
            markers="${markers}${marker_prefix}:${path}
"
          fi
          ;;
      esac
    done <<EOF
$(dev_kit_context_marker_group_paths "$marker_group")
EOF
  done <<EOF
$(dev_kit_context_marker_group_ids)
EOF

  DEV_KIT_REPO_MARKERS_CACHE_VALUE="$(printf "%s" "$markers" | dev_kit_unique_lines_ci)"
  printf "%s" "$DEV_KIT_REPO_MARKERS_CACHE_VALUE"
}

dev_kit_repo_markers_json() {
  local repo_dir="${1:-$(pwd)}"
  local markers=""

  markers="$(dev_kit_repo_marker_lines "$repo_dir")"
  if [ -z "$markers" ]; then
    printf "%s" "[]"
    return 0
  fi

  printf "%s" "$markers" | dev_kit_lines_to_json_array
}

dev_kit_has_file() {
  local repo_dir="$1"
  local path="$2"
  [ -e "$repo_dir/$path" ]
}

dev_kit_repo_has_dir() {
  local repo_dir="$1"
  local path="$2"
  [ -d "$repo_dir/$path" ]
}

dev_kit_repo_find() {
  local repo_dir="$1"
  local prune_path=""
  local prune_args=()
  local last_index=0
  shift

  while IFS= read -r prune_path; do
    [ -n "$prune_path" ] || continue
    prune_args+=(-name "$prune_path" -o)
  done <<EOF
$(dev_kit_detection_list "prune_dirs")
EOF

  if [ "${#prune_args[@]}" -eq 0 ]; then
    find "$repo_dir" "$@"
    return 0
  fi

  last_index=$((${#prune_args[@]} - 1))
  unset "prune_args[$last_index]"

  find "$repo_dir" "(" "${prune_args[@]}" ")" -prune -o "$@"
}

dev_kit_repo_content_files() {
  local repo_dir="$1"

  if dev_kit_sync_has_git_repo "$repo_dir"; then
    (
      cd "$repo_dir" &&
      git ls-files -z --cached --others --exclude-standard 2>/dev/null
    ) | tr '\0' '\n' | awk -v repo_dir="$repo_dir" 'NF { printf "%s/%s\n", repo_dir, $0 }'
    return 0
  fi

  dev_kit_repo_find "$repo_dir" -type f 2>/dev/null
}

dev_kit_repo_has_glob() {
  local repo_dir="$1"
  local pattern="$2"

  pattern="${pattern#\"}"
  pattern="${pattern%\"}"

  if [[ "$pattern" == */* ]]; then
    dev_kit_repo_find "$repo_dir" -type f -path "$repo_dir/$pattern" -print -quit | grep -q .
    return $?
  fi

  dev_kit_repo_find "$repo_dir" -type f -name "$pattern" -print -quit | grep -q .
}

dev_kit_repo_find_from_glob_list() {
  local repo_dir="$1"
  local list_name="$2"
  local pattern=""

  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    pattern="${pattern#\"}"
    pattern="${pattern%\"}"
    if [[ "$pattern" == */* ]]; then
      dev_kit_repo_find "$repo_dir" -type f -path "$repo_dir/$pattern" -print
    else
      dev_kit_repo_find "$repo_dir" -type f -name "$pattern" -print
    fi
  done <<EOF
$(dev_kit_detection_list "$list_name")
EOF
}

dev_kit_repo_markdown_files() {
  local repo_dir="$1"

  dev_kit_repo_find_from_glob_list "$repo_dir" "markdown_file_globs" | sort -u
}

dev_kit_repo_command_doc_files() {
  local repo_dir="$1"
  local ref=""

  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    ref="${ref#./}"
    [ -f "$repo_dir/$ref" ] || continue
    case "$ref" in
      AGENTS.md|CLAUDE.md|.rabbit/*) continue ;;
    esac
    case "$ref" in
      docs/references/*) continue ;;
    esac
    case "$ref" in
      *.md|*.markdown) printf '%s/%s\n' "$repo_dir" "$ref" ;;
    esac
  done <<EOF
$(dev_kit_repo_doc_refs "$repo_dir")
EOF
}

dev_kit_repo_has_any_file_from_list() {
  local repo_dir="$1"
  local list_name="$2"
  local path=""

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if dev_kit_has_file "$repo_dir" "$path"; then
      return 0
    fi
  done <<EOF
$(dev_kit_detection_list "$list_name")
EOF

  return 1
}

dev_kit_repo_has_any_dir_from_list() {
  local repo_dir="$1"
  local list_name="$2"
  local path=""

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if dev_kit_repo_has_dir "$repo_dir" "$path"; then
      return 0
    fi
  done <<EOF
$(dev_kit_detection_list "$list_name")
EOF

  return 1
}

dev_kit_repo_has_any_glob_from_list() {
  local repo_dir="$1"
  local list_name="$2"
  local pattern=""

  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    if dev_kit_repo_has_glob "$repo_dir" "$pattern"; then
      return 0
    fi
  done <<EOF
$(dev_kit_detection_list "$list_name")
EOF

  return 1
}

dev_kit_repo_pattern_in_file() {
  local file_path="$1"
  local regex="$2"

  awk -v regex="$regex" '
    match($0, regex) {
      found=1
      exit
    }
    END { exit found ? 0 : 1 }
  ' "$file_path" >/dev/null 2>&1
}

dev_kit_repo_has_pattern_in_glob_list() {
  local repo_dir="$1"
  local list_name="$2"
  local pattern_name="$3"
  local regex=""
  local file_path=""

  regex="$(dev_kit_detection_pattern "$pattern_name")"
  [ -n "$regex" ] || return 1

  while IFS= read -r file_path; do
    [ -n "$file_path" ] || continue
    if dev_kit_repo_pattern_in_file "$file_path" "$regex"; then
      return 0
    fi
  done <<EOF
$(dev_kit_repo_find_from_glob_list "$repo_dir" "$list_name")
EOF

  return 1
}

dev_kit_repo_file_has_all_patterns() {
  local file_path="$1"
  shift
  local pattern_name=""
  local regex=""

  [ -f "$file_path" ] || return 1

  for pattern_name in "$@"; do
    regex="$(dev_kit_detection_pattern "$pattern_name")"
    [ -n "$regex" ] || return 1
    if ! dev_kit_repo_pattern_in_file "$file_path" "$regex"; then
      return 1
    fi
  done

  return 0
}


dev_kit_repo_documented_command() {
  local repo_dir="$1"
  local kind="$2"
  local doc_file=""
  local command=""

  while IFS= read -r doc_file; do
    [ -n "$doc_file" ] || continue
    command="$(dev_kit_repo_extract_first_pattern_command_from_file "$doc_file" "$kind" 2>/dev/null || true)"
    if [ -n "$command" ]; then
      printf "%s" "$command"
      return 0
    fi
  done <<EOF
$(dev_kit_repo_command_doc_files "$repo_dir")
EOF

  return 1
}

dev_kit_repo_extract_first_pattern_command_from_file() {
  local file_path="$1"
  local pattern_name="$2"
  local doc_file=""
  local regex=""
  local command=""

  regex="$(dev_kit_detection_pattern "$pattern_name")"
  [ -n "$regex" ] || return 1
  [ -f "$file_path" ] || return 1

  command="$(awk -v regex="$regex" '
    match($0, regex) {
      command = substr($0, RSTART, RLENGTH)
      gsub(/^`|`$/, "", command)
      print command
      exit
    }
  ' "$file_path")"
  if [ -n "$command" ]; then
    printf "%s" "$command"
    return 0
  fi

  return 1
}

dev_kit_repo_documented_command_source() {
  local repo_dir="$1"
  local kind="$2"
  local doc_file=""
  local regex=""

  regex="$(dev_kit_detection_pattern "$kind")"
  [ -n "$regex" ] || return 1

  while IFS= read -r doc_file; do
    [ -n "$doc_file" ] || continue
    if awk -v regex="$regex" 'match($0, regex) { found = 1; exit } END { exit found ? 0 : 1 }' "$doc_file"; then
      printf "%s" "${doc_file#"${repo_dir}/"}"
      return 0
    fi
  done <<EOF
$(dev_kit_repo_command_doc_files "$repo_dir")
EOF

  return 1
}

dev_kit_repo_documented_verification_sequence_result() {
  local repo_dir="$1"
  local doc_file=""
  local doc_rel=""
  local lint_cmd=""
  local verify_cmd=""
  local build_cmd=""
  local commands=""
  local command=""
  local command_count=0

  while IFS= read -r doc_file; do
    [ -n "$doc_file" ] || continue
    doc_rel="${doc_file#"${repo_dir}/"}"
    lint_cmd="$(dev_kit_repo_extract_first_pattern_command_from_file "$doc_file" "lint" 2>/dev/null || true)"
    verify_cmd="$(dev_kit_repo_extract_first_pattern_command_from_file "$doc_file" "verification" 2>/dev/null || true)"
    build_cmd="$(dev_kit_repo_extract_first_pattern_command_from_file "$doc_file" "build" 2>/dev/null || true)"
    commands=""

    while IFS= read -r command; do
      [ -n "$command" ] || continue
      case "
$commands
" in
        *"
$command
"*) continue ;;
      esac
      commands="${commands}${command}
"
    done <<EOF
$lint_cmd
$verify_cmd
$build_cmd
EOF

    command_count="$(printf '%s' "$commands" | awk 'NF { count += 1 } END { print count + 0 }')"
    if [ "$command_count" -ge 2 ]; then
      printf '%s|%s\n' "$doc_rel" "$(printf '%s' "$commands" | awk 'NF { if (out != "") out = out " && "; out = out $0 } END { print out }')"
      return 0
    fi
  done <<EOF
$(dev_kit_repo_command_doc_files "$repo_dir")
EOF

  return 1
}

dev_kit_repo_contract_doc_refs() {
  local repo_dir="$1"
  local doc_file=""
  local doc_rel=""

  while IFS= read -r doc_file; do
    [ -n "$doc_file" ] || continue
    doc_rel="${doc_file#"${repo_dir}/"}"
    case "$doc_rel" in
      README.md|README|readme.md|changes.md|CHANGELOG.md) continue ;;
    esac

    if grep -Eq '(^|[(/[:space:]])(\.github/workflows/|\.rabbit/)' "$doc_file" 2>/dev/null || \
       dev_kit_repo_extract_first_pattern_command_from_file "$doc_file" "verification" >/dev/null 2>&1 || \
       dev_kit_repo_extract_first_pattern_command_from_file "$doc_file" "lint" >/dev/null 2>&1 || \
       dev_kit_repo_extract_first_pattern_command_from_file "$doc_file" "build" >/dev/null 2>&1; then
      printf './%s\n' "$doc_rel"
    fi
  done <<EOF
$(dev_kit_repo_command_doc_files "$repo_dir")
EOF
}

dev_kit_repo_contract_manifest_refs() {
  local repo_dir="$1"
  local manifest_rel=""

  while IFS= read -r manifest_rel; do
    [ -n "$manifest_rel" ] || continue
    case "$manifest_rel" in
      .rabbit/*/*)
        continue
        ;;
      .rabbit/*.yml|.rabbit/*.yaml|*.yml|*.yaml)
        printf './%s\n' "$manifest_rel"
        ;;
    esac
  done <<EOF
$(dev_kit_repo_contract_manifest_files "$repo_dir")
EOF
}

dev_kit_repo_has_make_target() {
  local repo_dir="$1"
  local target="$2"
  local makefile=""

  while IFS= read -r makefile; do
    [ -n "$makefile" ] || continue
    if [ -f "$repo_dir/$makefile" ] && grep -Eq "^${target}:" "$repo_dir/$makefile"; then
      return 0
    fi
  done <<EOF
$(dev_kit_detection_list "makefiles")
EOF

  return 1
}

dev_kit_repo_manifest_has_script() {
  local repo_dir="$1"
  local manifest="$2"
  local script_name="$3"

  [ -f "$repo_dir/$manifest" ] || return 1

  awk -v script_name="$script_name" '
    /"scripts"[[:space:]]*:[[:space:]]*{/ { in_scripts=1 }
    in_scripts && $0 ~ "\"" script_name "\"[[:space:]]*:" { found=1 }
    in_scripts && /}/ { if (!found) exit }
    END { exit found ? 0 : 1 }
  ' "$repo_dir/$manifest"
}

dev_kit_repo_has_node_test_script() {
  dev_kit_repo_manifest_has_script "$1" "package.json" "test"
}

dev_kit_repo_has_node_build_script() {
  dev_kit_repo_manifest_has_script "$1" "package.json" "build"
}

dev_kit_repo_has_node_start_script() {
  dev_kit_repo_manifest_has_script "$1" "package.json" "start"
}

dev_kit_repo_has_composer_test_script() {
  dev_kit_repo_manifest_has_script "$1" "composer.json" "test"
}

dev_kit_repo_has_composer_build_script() {
  dev_kit_repo_manifest_has_script "$1" "composer.json" "build"
}

dev_kit_repo_documented_env_var() {
  local repo_dir="$1"

  [ -n "$(dev_kit_repo_documented_env_var_sources "$repo_dir")" ]
}

dev_kit_repo_documented_env_var_sources() {
  local repo_dir="$1"
  local doc_file=""
  local regex=""

  regex="$(dev_kit_detection_pattern "env_var")"
  [ -n "$regex" ] || return 1

  while IFS= read -r doc_file; do
    [ -n "$doc_file" ] || continue
    if dev_kit_repo_pattern_in_file "$doc_file" "$regex"; then
      printf '%s\n' "${doc_file#"${repo_dir}/"}"
    fi
  done <<EOF
$(dev_kit_repo_markdown_files "$repo_dir")
EOF
}

dev_kit_repo_has_documentation_sections() {
  local repo_dir="$1"
  local doc_file=""
  local regex=""

  regex="$(dev_kit_detection_pattern "documentation_sections")"
  [ -n "$regex" ] || return 1

  while IFS= read -r doc_file; do
    [ -n "$doc_file" ] || continue
    if dev_kit_repo_pattern_in_file "$doc_file" "$regex"; then
      return 0
    fi
  done <<EOF
$(dev_kit_repo_markdown_files "$repo_dir")
EOF

  return 1
}
