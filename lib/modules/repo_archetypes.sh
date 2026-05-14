#!/usr/bin/env bash

DEV_KIT_REPO_FACETS_CACHE_REPO=""
DEV_KIT_REPO_FACETS_CACHE_VALUE=""
DEV_KIT_REPO_ARCHETYPES_CACHE_REPO=""
DEV_KIT_REPO_ARCHETYPES_CACHE_VALUE=""

dev_kit_repo_has_yaml_manifest() {
  local repo_dir="$1"
  local file_path=""
  local rel_path=""

  while IFS= read -r file_path; do
    [ -n "$file_path" ] || continue
    rel_path="${file_path#"${repo_dir}/"}"
    case "$rel_path" in
      .github/workflows/*|.rabbit/context.yaml) continue ;;
    esac
    if awk '
      /^[[:space:]]*#/ { next }
      /^[[:space:]]*(kind|apiVersion|version|services|resources|modules|config):[[:space:]]*/ { found=1; exit }
      END { exit found ? 0 : 1 }
    ' "$file_path"; then
      return 0
    fi
  done <<EOF
$(dev_kit_repo_find_from_glob_list "$repo_dir" "yaml_manifest_globs")
EOF

  return 1
}

dev_kit_repo_has_facet_in_text() {
  local facets="$1"
  local facet="$2"

  case "
$facets
" in
    *"
$facet
"*) return 0 ;;
  esac

  return 1
}

dev_kit_repo_facets() {
  local repo_dir="$1"
  local facets=""

  if [ "$DEV_KIT_REPO_FACETS_CACHE_REPO" = "$repo_dir" ]; then
    printf "%s" "$DEV_KIT_REPO_FACETS_CACHE_VALUE"
    return 0
  fi

  facets="${facets}repo:detected
"

  if dev_kit_repo_has_yaml_manifest "$repo_dir"; then
    facets="${facets}contract:manifest
"
  fi

  if dev_kit_repo_has_any_glob_from_list "$repo_dir" "workflow_globs" && \
     dev_kit_repo_has_pattern_in_glob_list "$repo_dir" "workflow_globs" "workflow_contract"; then
    facets="${facets}workflow:github
"
    if dev_kit_repo_has_any_file_from_list "$repo_dir" "workflow_primary_files" || \
       { ! dev_kit_repo_has_yaml_manifest "$repo_dir" && \
         ! dev_kit_repo_has_any_file_from_list "$repo_dir" "container_files" && \
         ! dev_kit_repo_has_any_file_from_list "$repo_dir" "deploy_files"; }; then
      facets="${facets}repo:workflow-primary
"
    fi
  fi

  if [ -z "$facets" ]; then
    DEV_KIT_REPO_FACETS_CACHE_REPO="$repo_dir"
    DEV_KIT_REPO_FACETS_CACHE_VALUE=""
    return 0
  fi

  DEV_KIT_REPO_FACETS_CACHE_REPO="$repo_dir"
  DEV_KIT_REPO_FACETS_CACHE_VALUE="$(printf "%s" "$facets" | awk '!seen[$0]++')"
  printf "%s" "$DEV_KIT_REPO_FACETS_CACHE_VALUE"
}

dev_kit_repo_has_facet() {
  local repo_dir="$1"
  local facet="$2"
  local facets=""

  facets="$(dev_kit_repo_facets "$repo_dir")"
  dev_kit_repo_has_facet_in_text "$facets" "$facet"
}

dev_kit_repo_matches_configured_archetype() {
  local repo_dir="$1"
  local archetype="$2"
  local facet=""
  local facets=""

  facets="$(dev_kit_repo_facets "$repo_dir")"

  while IFS= read -r facet; do
    [ -n "$facet" ] || continue
    if ! dev_kit_repo_has_facet_in_text "$facets" "$facet"; then
      return 1
    fi
  done <<EOF
$(dev_kit_archetype_facets "$archetype" "required")
EOF

  return 0
}

dev_kit_repo_configured_archetypes() {
  local repo_dir="$1"
  local archetype=""

  while IFS= read -r archetype; do
    [ -n "$archetype" ] || continue
    if dev_kit_repo_matches_configured_archetype "$repo_dir" "$archetype"; then
      printf "%s\n" "$archetype"
    fi
  done <<EOF
$(dev_kit_archetype_rule_ids)
EOF
}

dev_kit_repo_archetypes() {
  local repo_dir="$1"
  local _ck="archetypes:${repo_dir}"
  local _cv

  # File cache (survives subshell boundaries)
  if _cv="$(dev_kit_cache_get "$_ck")"; then
    printf '%s' "$_cv"; return 0
  fi

  # Global variable cache (fast within same process, lost across subshells)
  if [ "$DEV_KIT_REPO_ARCHETYPES_CACHE_REPO" = "$repo_dir" ]; then
    dev_kit_cache_set "$_ck" "$DEV_KIT_REPO_ARCHETYPES_CACHE_VALUE"
    printf "%s" "$DEV_KIT_REPO_ARCHETYPES_CACHE_VALUE"
    return 0
  fi

  local archetypes=""
  archetypes="$(dev_kit_repo_configured_archetypes "$repo_dir")"

  local result="unknown"
  if [ -n "$archetypes" ]; then
    result="$(printf "%s" "$archetypes" | awk '!seen[$0]++')"
  fi

  DEV_KIT_REPO_ARCHETYPES_CACHE_REPO="$repo_dir"
  DEV_KIT_REPO_ARCHETYPES_CACHE_VALUE="$result"
  dev_kit_cache_set "$_ck" "$result"
  printf '%s' "$result"
}

dev_kit_repo_has_archetype() {
  local repo_dir="$1"
  local archetype="$2"

  case "
$(dev_kit_repo_archetypes "$repo_dir")
" in
    *"
$archetype
"*) return 0 ;;
  esac

  return 1
}

dev_kit_repo_primary_archetype() {
  local repo_dir="$1"
  local _ck="archetype:${repo_dir}"
  local _cv
  if _cv="$(dev_kit_cache_get "$_ck")"; then
    printf '%s' "$_cv"; return 0
  fi

  local archetypes="" archetype="" _result="unknown"
  archetypes="$(dev_kit_repo_archetypes "$repo_dir")"
  while IFS= read -r archetype; do
    [ -n "$archetype" ] || continue
    case "
$archetypes
" in
      *"
$archetype
"*) _result="$archetype"; break ;;
    esac
  done <<EOF
$(dev_kit_archetype_rule_ids)
EOF

  dev_kit_cache_set "$_ck" "$_result"
  printf '%s' "$_result"
}
