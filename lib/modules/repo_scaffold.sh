#!/usr/bin/env bash

# Scaffold module — all write operations for dev.kit repo.
# Analysis (what's missing) stays in repo_factors.sh and repo_signals.sh.
# This module only handles creating or updating files and dirs.

dev_kit_repo_write_if_missing() {
  local target_path="$1"
  local file_body="$2"

  [ -e "$target_path" ] && return 0
  printf '%s' "$file_body" > "$target_path"
}

dev_kit_repo_ensure_default_structure() {
  local repo_root="$1"
  local repo_name=""

  repo_name="$(dev_kit_repo_name "$repo_root")"

  mkdir -p "${repo_root}/.github/workflows" "${repo_root}/.rabbit" "${repo_root}/docs"

  dev_kit_repo_write_if_missing "${repo_root}/README.md" "# ${repo_name}

This repository uses \`dev.kit\` for repo-driven context coverage.

- Run \`dev.kit\` to inspect environment and repo context status
- Run \`dev.kit repo\` to regenerate \`.rabbit/context.yaml\`
"

  dev_kit_repo_write_if_missing "${repo_root}/.github/dependabot.yml" "version: 2
updates:
  - package-ecosystem: github-actions
    directory: \"/\"
    schedule:
      interval: weekly
"
}

# Manifest metadata must live in the manifest itself, not in shell code.
dev_kit_manifest_metadata() {
  local manifest_path="$1"
  local manifest_kind=""
  local manifest_description=""

  [ -f "$manifest_path" ] || return 1

  manifest_kind="$(awk '/^kind:/ { sub(/^kind:[[:space:]]*/, ""); print; exit }' "$manifest_path")"
  manifest_description="$(awk '
    /^description:/ {
      sub(/^description:[[:space:]]*/, "")
      print
      exit
    }
  ' "$manifest_path")"

  printf '%s|%s\n' "$manifest_kind" "$manifest_description"
}

dev_kit_manifest_module_values() {
  local manifest_path="$1"

  [ -f "$manifest_path" ] || return 0

  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*module:[[:space:]]*/ {
      value = $0
      sub(/^[[:space:]]*module:[[:space:]]*/, "", value)
      gsub(/["'\''"]/, "", value)
      gsub(/[[:space:]]+$/, "", value)
      if (value != "") print value
    }
  ' "$manifest_path" | awk '!seen[$0]++'
}

dev_kit_manifest_module_backend() {
  local repo_root="$1"
  local module_name="$2"
  local base_dir=""
  local candidate=""

  while IFS= read -r base_dir; do
    [ -n "$base_dir" ] || continue
    candidate="${base_dir}/${module_name}"
    if [ -d "${repo_root}/${candidate}" ]; then
      printf 'terraformModule|%s\n' "$candidate"
      return 0
    fi
  done <<EOF
$(dev_kit_detection_list "manifest_backend_module_dirs")
EOF

  return 1
}

dev_kit_manifest_backend_yaml() {
  local repo_root="$1"
  local manifest_rel="$2"
  local manifest_path="${repo_root}/${manifest_rel}"
  local module_name=""
  local backend=""
  local backend_kind=""
  local backend_path=""

  while IFS= read -r module_name; do
    [ -n "$module_name" ] || continue
    backend="$(dev_kit_manifest_module_backend "$repo_root" "$module_name" 2>/dev/null || true)"
    if [ -n "$backend" ]; then
      backend_kind="${backend%%|*}"
      backend_path="${backend#*|}"
      printf '    backend:\n'
      printf '      kind: %s\n' "$backend_kind"
      printf '      module: %s\n' "$module_name"
      printf '      path: %s\n' "$backend_path"
      if [ -f "${repo_root}/${backend_path}/readme.md" ]; then
        printf '      docs: %s/readme.md\n' "$backend_path"
      elif [ -f "${repo_root}/${backend_path}/README.md" ]; then
        printf '      docs: %s/README.md\n' "$backend_path"
      fi
      return 0
    fi
  done <<EOF
$(dev_kit_manifest_module_values "$manifest_path")
EOF

  return 0
}

dev_kit_github_repo_refs_in_file() {
  local file_path="$1"
  local repo_ref=""

  [ -f "$file_path" ] || return 0

  while IFS= read -r repo_ref; do
    [ -n "$repo_ref" ] || continue
    printf '%s\n' "$repo_ref"
  done <<EOF
$(
  {
    grep -oE 'github\.com[:/][A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' "$file_path" 2>/dev/null || true
  } | awk '
    {
      sub(/github\.com[\/:]+/, "")
      sub(/\.git$/, "")
      if ($0 == "org/repo" || $0 == "test/repo") next
      if ($0 != "") print
    }
  ' | awk '!seen[$0]++'
)
EOF
}

dev_kit_manifest_version_value() {
  local manifest_path="$1"

  [ -f "$manifest_path" ] || return 0

  awk '
    /^version:[[:space:]]*/ {
      value = $0
      sub(/^version:[[:space:]]*/, "", value)
      gsub(/["'\''"]/, "", value)
      gsub(/[[:space:]]+$/, "", value)
      if (value != "") print value
      exit
    }
  ' "$manifest_path"
}

dev_kit_manifest_comment_repo_refs() {
  local manifest_path="$1"

  dev_kit_github_repo_refs_in_file "$manifest_path"
}

dev_kit_repo_is_contract_evidence_path() {
  local path="$1"

  case "$path" in
    ""|.git/*|.rabbit/context.yaml|AGENTS.md|.udx/*|.claude/*|.copilot/*|.cursor/*)
      return 1
      ;;
  esac

  return 0
}

dev_kit_repo_current_slug() {
  local repo_root="$1"
  local repo_name="$2"
  local repo_slug=""
  local repo_org=""

  repo_slug="$(dev_kit_repo_slug_from_remote "$repo_root" 2>/dev/null || true)"
  if [ -n "$repo_slug" ]; then
    printf '%s' "$repo_slug"
    return 0
  fi

  repo_org="$(dev_kit_repo_org_from_remote "$repo_root" 2>/dev/null || true)"
  if [ -n "$repo_org" ] && [ -n "$repo_name" ]; then
    printf '%s/%s' "$repo_org" "$repo_name"
    return 0
  fi
}

dev_kit_manifest_usage_paths() {
  local repo_root="$1"
  local manifest_rel="$2"
  local scan_file=""
  local scan_rel=""

  [ -n "$manifest_rel" ] || return 0

  if dev_kit_sync_has_git_repo "$repo_root"; then
    (
      cd "$repo_root" &&
      git grep -F -l --untracked -- "$manifest_rel" -- . 2>/dev/null || true
    ) | while IFS= read -r scan_rel; do
      [ -n "$scan_rel" ] || continue
      [ "$scan_rel" = "$manifest_rel" ] && continue
      dev_kit_repo_is_contract_evidence_path "$scan_rel" || continue
      printf '%s\n' "$scan_rel"
    done
    return 0
  fi

  while IFS= read -r scan_file; do
    [ -f "$scan_file" ] || continue
    scan_rel="${scan_file#"${repo_root}/"}"

    [ "$scan_rel" = "$manifest_rel" ] && continue
    dev_kit_repo_is_contract_evidence_path "$scan_rel" || continue

    if grep -Fq -- "$manifest_rel" "$scan_file" 2>/dev/null; then
      printf '%s\n' "$scan_rel"
    fi
  done <<EOF
$(dev_kit_repo_content_files "$repo_root")
EOF
}

dev_kit_repo_reusable_workflow_contract_files() {
  local repo_root="$1"
  local workflow_dir=""
  local workflow_file=""

  while IFS= read -r workflow_dir; do
    [ -n "$workflow_dir" ] && [ -d "${repo_root}/${workflow_dir}" ] || continue
    while IFS= read -r workflow_file; do
      [ -f "$workflow_file" ] || continue
      if grep -qE 'uses:[[:space:]]*["'"'"']?[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/\.github/workflows/[^@[:space:]]+@' "$workflow_file" 2>/dev/null; then
        printf '%s\n' "${workflow_file#"${repo_root}/"}"
      fi
    done <<EOF
$(find "${repo_root}/${workflow_dir}" -maxdepth 1 \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null | sort)
EOF
  done <<EOF
$(dev_kit_detection_list "workflow_globs" | sed 's#/[^/]*$##' | awk '!seen[$0]++')
EOF
}

dev_kit_repo_contract_manifest_files() {
  local repo_root="$1"
  local manifest_dir=""
  local manifest_rel=""

  while IFS= read -r manifest_dir; do
    [ -n "$manifest_dir" ] && [ -d "${repo_root}/${manifest_dir}" ] || continue
    while IFS= read -r manifest_rel; do
      [ -n "$manifest_rel" ] || continue
      case "$manifest_rel" in
        */context.yaml) continue ;;
      esac
      printf '%s\n' "${manifest_rel#"${repo_root}/"}"
    done <<EOF
$(find "${repo_root}/${manifest_dir}" -type f \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null | sort)
EOF
  done <<EOF
$(dev_kit_context_section_detection_list_values "dependencies" "versioned_dirs")
EOF

  while IFS= read -r manifest_dir; do
    [ -n "$manifest_dir" ] && [ -d "${repo_root}/${manifest_dir}" ] || continue
    while IFS= read -r manifest_rel; do
      [ -n "$manifest_rel" ] || continue
      case "$manifest_rel" in
        */context.yaml) continue ;;
      esac
      printf '%s\n' "${manifest_rel#"${repo_root}/"}"
    done <<EOF
$(find "${repo_root}/${manifest_dir}" -maxdepth 1 \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null | sort)
EOF
  done <<EOF
$(dev_kit_context_section_detection_list_values "manifests" "config_dirs")
EOF

  while IFS= read -r manifest_rel; do
    [ -n "$manifest_rel" ] && [ -f "${repo_root}/${manifest_rel}" ] || continue
    case "$manifest_rel" in
      */context.yaml) continue ;;
    esac
    printf '%s\n' "$manifest_rel"
  done <<EOF
$(dev_kit_context_section_detection_list_values "manifests" "root_files")
EOF
}

dev_kit_manifest_source_repo() {
  local manifest_path="$1"
  local comment_repo=""
  local version_value=""
  local version_repo=""

  comment_repo="$(dev_kit_manifest_comment_repo_refs "$manifest_path" | head -n 1)"
  if [ -n "$comment_repo" ]; then
    printf '%s\n' "$comment_repo"
    return 0
  fi

  version_value="$(dev_kit_manifest_version_value "$manifest_path")"
  if [ -n "$version_value" ]; then
    version_repo="$(dev_kit_dep_version_repo_slug "$version_value" 2>/dev/null || true)"
    if [ -n "$version_repo" ]; then
      printf '%s\n' "$version_repo"
      return 0
    fi
  fi

  return 0
}

dev_kit_manifest_provenance_yaml() {
  local repo_root="$1"
  local manifest_rel="$2"
  local manifest_path="${repo_root}/${manifest_rel}"
  local repo_name=""
  local current_repo_slug=""
  local declared_as=""
  local source_repo=""
  local evidence_yaml=""
  local evidence_item=""
  local usage_paths=""
  local usage_path=""
  local comment_repo=""

  repo_name="$(dev_kit_repo_name "$repo_root")"
  current_repo_slug="$(dev_kit_repo_current_slug "$repo_root" "$repo_name" 2>/dev/null || true)"
  declared_as="$(dev_kit_manifest_version_value "$manifest_path")"
  source_repo="$(dev_kit_manifest_source_repo "$manifest_path")"
  [ -n "$current_repo_slug" ] && [ "$source_repo" = "$current_repo_slug" ] && source_repo=""
  usage_paths="$(dev_kit_manifest_usage_paths "$repo_root" "$manifest_rel" | awk '!seen[$0]++')"

  [ -n "$declared_as" ] && printf '    declared_as: %s\n' "$declared_as"
  [ -n "$source_repo" ] && printf '    source_repo: %s\n' "$source_repo"

  if [ -n "$usage_paths" ]; then
    printf '    used_by:\n'
    while IFS= read -r usage_path; do
      [ -n "$usage_path" ] || continue
      printf '      - %s\n' "$usage_path"
    done <<EOF
$usage_paths
EOF
  fi

  [ -n "$declared_as" ] && evidence_yaml="${evidence_yaml}      - version: ${declared_as}\n"

  while IFS= read -r comment_repo; do
    [ -n "$comment_repo" ] || continue
    evidence_yaml="${evidence_yaml}      - github reference: ${comment_repo}\n"
  done <<EOF
$(dev_kit_manifest_comment_repo_refs "$manifest_path")
EOF

  while IFS= read -r evidence_item; do
    [ -n "$evidence_item" ] || continue
    evidence_yaml="${evidence_yaml}      - path reference: ${evidence_item}\n"
  done <<EOF
$usage_paths
EOF

  if [ -n "$evidence_yaml" ]; then
    printf '    evidence:\n'
    printf '%b' "$evidence_yaml"
  fi
}

dev_kit_manifest_yaml_item() {
  local repo_root="$1"
  local manifest_rel="$2"
  local manifest_kind="${3:-}"
  local manifest_description="${4:-}"
  local manifest_meta=""

  if [ -z "$manifest_kind" ] || [ -z "$manifest_description" ]; then
    manifest_meta="$(dev_kit_manifest_metadata "${repo_root}/${manifest_rel}" 2>/dev/null || true)"
    [ -z "$manifest_kind" ] && manifest_kind="${manifest_meta%%|*}"
    if [ -z "$manifest_description" ]; then
      manifest_description="${manifest_meta#*|}"
      [ "$manifest_description" = "$manifest_meta" ] && manifest_description=""
    fi
  fi

  printf '  - path: %s\n' "$manifest_rel"
  [ -n "$manifest_kind" ] && printf '    kind: %s\n' "$manifest_kind"
  [ -n "$manifest_description" ] && printf '    description: %s\n' "$manifest_description"
  dev_kit_manifest_provenance_yaml "$repo_root" "$manifest_rel"
  dev_kit_manifest_backend_yaml "$repo_root" "$manifest_rel"
  return 0
}

dev_kit_version_uri() {
  printf '%s' 'udx.dev/dev.kit/v1'
}

dev_kit_tool_version() {
  awk -F'"' '/"version"/{print $4; exit}' "$REPO_DIR/package.json" 2>/dev/null
}

dev_kit_context_section_comment_block() {
  local section_id="$1"
  local title=""
  local summary=""
  local note=""
  local emitted=0

  title="$(dev_kit_context_section_field "$section_id" "title" 2>/dev/null || true)"
  summary="$(dev_kit_context_section_field "$section_id" "summary" 2>/dev/null || true)"

  if [ -n "$title" ] || [ -n "$summary" ]; then
    if [ -n "$title" ] && [ -n "$summary" ]; then
      printf '# %s — %s\n' "$title" "$summary"
    elif [ -n "$title" ]; then
      printf '# %s\n' "$title"
    else
      printf '# %s\n' "$summary"
    fi
    emitted=1
  fi

  while IFS= read -r note; do
    [ -n "$note" ] || continue
    printf '# Note: %s\n' "$note"
    emitted=1
  done <<EOF
$(dev_kit_context_section_notes "$section_id")
EOF

  [ "$emitted" -eq 1 ] && printf '\n'
}

dev_kit_dep_version_repo_slug() {
  local version_value="$1"
  local domain=""
  local repo_name=""
  local org_name=""

  domain="$(printf '%s' "$version_value" | cut -d/ -f1)"
  repo_name="$(printf '%s' "$version_value" | cut -d/ -f2)"

  [ -n "$domain" ] || return 1
  [ -n "$repo_name" ] || return 1

  org_name="${domain%%.*}"
  repo_name="$(printf '%s' "$repo_name" | sed -E 's/-v[0-9]+([._-][A-Za-z0-9._-]+)?$//')"

  if [ -n "$org_name" ] && [ "$org_name" != "$domain" ]; then
    printf '%s/%s' "$org_name" "$repo_name"
    return 0
  fi

  printf '%s' "$repo_name"
}

dev_kit_context_factor_ids() {
  local factor_ids=""

  factor_ids="$(dev_kit_context_section_list "gaps" "factor_ids" 2>/dev/null || true)"
  if [ -n "$factor_ids" ]; then
    printf '%s' "$factor_ids"
    return 0
  fi

  printf '%s\n' documentation dependencies config pipeline
}

# Path of the canonical context file
dev_kit_context_yaml_path() {
  local repo_root="$1"
  printf '%s/.rabbit/context.yaml\n' "$repo_root"
}

# Report gaps as JSON array [{factor, status, message}]
# Reads from existing factor analysis — no new detection here
dev_kit_scaffold_gaps_json() {
  local repo_root="$1"
  local factor=""
  local status=""
  local first=1

  printf '[\n'
  while IFS= read -r factor; do
    [ -n "$factor" ] || continue
    status="$(dev_kit_repo_factor_status "$repo_root" "$factor")"
    [ "$status" = "missing" ] || [ "$status" = "partial" ] || continue
    local message repair_target reference
    message="$(dev_kit_repo_factor_message "$repo_root" "$factor" "$status" 2>/dev/null || true)"
    repair_target="$(dev_kit_repo_factor_repair_target "$repo_root" "$factor" "$status" 2>/dev/null || true)"
    reference="$(dev_kit_repo_factor_reference "$repo_root" "$factor" "$status" 2>/dev/null || true)"
    [ "$first" -eq 0 ] && printf ',\n'
    printf '  { "factor": "%s", "status": "%s", "message": "%s"' \
      "$factor" \
      "$status" \
      "$(dev_kit_json_escape "$message")"
    [ -n "$repair_target" ] && printf ', "repair_target": "%s"' "$(dev_kit_json_escape "$repair_target")"
    [ -n "$reference" ] && printf ', "reference": "%s"' "$(dev_kit_json_escape "$reference")"
    printf ' }'
    first=0
  done <<EOF
$(dev_kit_context_factor_ids)
EOF
  printf '\n]\n'
}

# ── Dependency resolution utilities ────────────────────────────────────────────

# Extract GitHub org from git remote origin URL.
# Returns empty string if not a github.com remote.
dev_kit_repo_org_from_remote() {
  local repo_root="$1"
  local url
  url="$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)"
  if [[ "$url" =~ github\.com[:/]([^/]+)/ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

dev_kit_repo_slug_from_remote() {
  local repo_root="$1"
  local url=""
  local slug=""

  url="$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)"
  [ -n "$url" ] || return 0

  slug="$url"
  case "$slug" in
    *github.com:*) slug="${slug#*github.com:}" ;;
    *github.com/*) slug="${slug#*github.com/}" ;;
    *) return 0 ;;
  esac
  slug="${slug%.git}"
  printf '%s' "$slug"
}

# Check if a dependency identifier belongs to the same GitHub org.
# dep_id: "org/repo" or bare name like "node". current_org: e.g. "udx".
dev_kit_dep_is_same_org() {
  local dep_id="$1" current_org="$2"
  [ -n "$current_org" ] || return 1
  case "$dep_id" in
    "${current_org}/"*) return 0 ;;
    *)                  return 1 ;;
  esac
}

# Try to match a Docker image name to a same-org GitHub repo.
# For images like "usabilitydynamics/udx-worker-tooling:0.19.0",
# the Docker Hub org differs from the GitHub org. Extract the image name
# and check if a matching repo exists in the current GitHub org.
# Returns org/repo if found, empty string otherwise.
dev_kit_dep_match_image_to_org() {
  local dep_id="$1" current_org="$2" repo_root="$3" gh_auth="$4"
  [ -n "$current_org" ] || return 0

  # Extract image name: strip org prefix, tag, and digest
  local img_name="${dep_id##*/}"
  img_name="${img_name%%:*}"
  img_name="${img_name%%@*}"
  [ -n "$img_name" ] || return 0

  local parent_dir
  parent_dir="$(dirname "$repo_root")"

  # Try exact match: org/image-name
  if [ -d "${parent_dir}/${img_name}/.git" ]; then
    printf '%s/%s' "$current_org" "$img_name"
    return 0
  fi

  # Try stripping org prefix: "udx-worker-tooling" → "worker-tooling"
  local stripped="${img_name#"${current_org}-"}"
  if [ "$stripped" != "$img_name" ] && [ -d "${parent_dir}/${stripped}/.git" ]; then
    printf '%s/%s' "$current_org" "$stripped"
    return 0
  fi

  # Try via gh api if available
  if [ "$gh_auth" = "available" ]; then
    if gh api "repos/${current_org}/${img_name}" --silent 2>/dev/null; then
      printf '%s/%s' "$current_org" "$img_name"
      return 0
    fi
    if [ "$stripped" != "$img_name" ]; then
      if gh api "repos/${current_org}/${stripped}" --silent 2>/dev/null; then
        printf '%s/%s' "$current_org" "$stripped"
        return 0
      fi
    fi
  fi
  return 0
}

# Resolve a same-org dependency repo.
# Outputs tab-delimited: resolved\tarchetype\tdescription
# Strategy: gh api (primary when available) + sibling directory for local context.
dev_kit_dep_resolve() {
  local dep_repo="$1" repo_root="$2" gh_auth="$3" force="$4"
  local dep_name="${dep_repo##*/}"
  local resolved="false" archetype="" description=""

  # Strategy 1: gh api for metadata (description)
  if [ "$gh_auth" = "available" ]; then
    local api_json
    api_json="$(gh api "repos/${dep_repo}" 2>/dev/null || true)"
    if [ -n "$api_json" ] && printf '%s' "$api_json" | jq -e '.id' >/dev/null 2>&1; then
      resolved="true"
      # Sanitize description: strip newlines/tabs/backslashes for safe YAML embedding
      description="$(printf '%s' "$api_json" | jq -r '(.description // empty) | gsub("[\\n\\r\\t]"; " ") | gsub("\\\\"; "") | gsub("\""; "")' 2>/dev/null)"
    fi
  fi

  # Strategy 2: sibling directory for local context
  local sibling_dir
  sibling_dir="$(dirname "$repo_root")/${dep_name}"
  if [ -d "$sibling_dir" ] && [ -d "${sibling_dir}/.git" ]; then
    resolved="true"
    local dep_context="${sibling_dir}/.rabbit/context.yaml"
    if [ -f "$dep_context" ] && [ "$force" != "1" ]; then
      [ -z "$archetype" ] && archetype="$(awk '/^repo:/{f=1} f && /^  archetype:/{sub(/.*archetype:[[:space:]]*/,""); print; exit}' "$dep_context")"
    fi
    # Live detection fallback
    [ -z "$archetype" ] && archetype="$(dev_kit_repo_primary_archetype "$sibling_dir" 2>/dev/null || true)"
  fi

  printf '%s\t%s\t%s' "$resolved" "$archetype" "$description"
}

# Read structured dependencies from context.yaml and emit JSON array.
# Used by repo.json template rendering.
dev_kit_deps_json() {
  local repo_dir="$1"
  local context_yaml="${repo_dir}/.rabbit/context.yaml"
  [ -f "$context_yaml" ] || { printf '[]'; return; }

  awk '
    function json_esc(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); gsub(/\t/, " ", s); return s }
    function flush_ub() {
      if (ub_count > 0) {
        printf ", \"used_by\": ["
        for (i = 1; i <= ub_count; i++) {
          if (i > 1) printf ", "
          printf "\"%s\"", json_esc(ub[i])
        }
        printf "]"
      }
    }
    BEGIN { printf "["; open = 0; ub_count = 0; in_ub = 0 }
    /^dependencies:/ { in_d=1; next }
    in_d && /^[a-zA-Z#]/ { if (open) { flush_ub(); printf "}"; open = 0 }; in_d=0 }
    !in_d { next }
    /^  - repo:/ {
      if (open) { flush_ub(); printf "}," }
      sub(/.*repo:[[:space:]]*/, "")
      printf "\n    {\"repo\": \"%s\"", json_esc($0)
      open = 1; ub_count = 0; in_ub = 0
      next
    }
    /^    kind:/        { sub(/.*kind:[[:space:]]*/, "");        printf ", \"kind\": \"%s\"", json_esc($0);        in_ub=0; next }
    /^    resolved:/    { sub(/.*resolved:[[:space:]]*/, "");    printf ", \"resolved\": %s", $0;                  in_ub=0; next }
    /^    archetype:/   { sub(/.*archetype:[[:space:]]*/, "");   printf ", \"archetype\": \"%s\"", json_esc($0);   in_ub=0; next }
    /^    declared_as:/ { sub(/.*declared_as:[[:space:]]*/, ""); printf ", \"declared_as\": \"%s\"", json_esc($0); in_ub=0; next }
    /^    source_repo:/ { sub(/.*source_repo:[[:space:]]*/, ""); printf ", \"source_repo\": \"%s\"", json_esc($0); in_ub=0; next }
    /^    description:/ { sub(/.*description:[[:space:]]*/, ""); printf ", \"description\": \"%s\"", json_esc($0); in_ub=0; next }
    /^    used_by:/     { in_ub = 1; next }
    in_ub && /^      - / { ub_count++; sub(/^[[:space:]]*- /, ""); ub[ub_count] = $0; next }
    in_ub && !/^      /  { in_ub = 0 }
    END { if (open) { flush_ub(); printf "}" }; printf "\n  ]" }
  ' "$context_yaml"
}

# Write .rabbit/context.yaml — single canonical artifact for repo + agent context.
# Computes everything directly from analysis functions; no intermediate JSON file.
# force: when "1", re-resolve dependency repos even if their context.yaml exists.
dev_kit_context_yaml_write() {
  local repo_root="$1"
  local force="${2:-0}"
  local context_path="${repo_root}/.rabbit/context.yaml"
  dev_kit_repo_ensure_default_structure "$repo_root"

  local _repo _arch _arch_desc
  _repo="$(dev_kit_repo_name "$repo_root")"
  _arch="$(dev_kit_repo_primary_archetype "$repo_root")"
  _arch_desc="$(dev_kit_archetype_description "$_arch")"

  {
    printf '# Generated by dev.kit repo — do not edit manually.\n'
    printf '# Run `dev.kit repo` to refresh.\n'
    printf 'kind: repoContext\n'
    printf 'version: %s\n' "$(dev_kit_version_uri)"
    printf 'generator:\n'
    printf '  tool: dev.kit\n'
    printf '  repo: https://github.com/udx/dev.kit\n'
    printf '  version: %s\n' "$(dev_kit_tool_version)"
    printf '  generated_at: %s\n\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    printf 'repo:\n'
    printf '  name: %s\n'      "$_repo"
    printf '  archetype: %s\n' "$_arch"
    printf '\n'

    local _refs
    _refs="$(dev_kit_repo_priority_refs "$repo_root")"
    if [ -n "$_refs" ]; then
      dev_kit_context_section_comment_block "refs"
      printf 'refs:\n'
      printf '%s\n' "$_refs" | while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        printf '  - %s\n' "$ref"
      done
      printf '\n'
    fi

    local _ep_json _verify _build _run _verify_source _build_source _run_source _command_kind
    _ep_json="$(dev_kit_repo_entrypoints_json "$repo_root")"
    _verify="$(printf '%s' "$_ep_json" | jq -r '.verify // empty' 2>/dev/null)"
    _build="$(printf '%s' "$_ep_json" | jq -r '.build  // empty' 2>/dev/null)"
    _run="$(printf '%s' "$_ep_json"   | jq -r '.run    // empty' 2>/dev/null)"
    _verify_source="$(dev_kit_repo_entrypoint_source "$repo_root" "verification" 2>/dev/null || true)"
    _build_source="$(dev_kit_repo_entrypoint_source "$repo_root" "build_release_run" 2>/dev/null || true)"
    _run_source="$(dev_kit_repo_entrypoint_source "$repo_root" "runtime" 2>/dev/null || true)"
    if [ -n "$_verify" ] || [ -n "$_build" ] || [ -n "$_run" ]; then
      dev_kit_context_section_comment_block "commands"
      printf 'commands:\n'
      while IFS= read -r _command_kind; do
        [ -n "$_command_kind" ] || continue
        case "$_command_kind" in
          verify)
            if [ -n "$_verify" ]; then
              printf '  verify:\n'
              printf '    run: %s\n' "$_verify"
              [ -n "$_verify_source" ] && printf '    source: %s\n' "$_verify_source"
            fi
            ;;
          build)
            if [ -n "$_build" ]; then
              printf '  build:\n'
              printf '    run: %s\n' "$_build"
              [ -n "$_build_source" ] && printf '    source: %s\n' "$_build_source"
            fi
            ;;
          run)
            if [ -n "$_run" ]; then
              printf '  run:\n'
              printf '    run: %s\n' "$_run"
              [ -n "$_run_source" ] && printf '    source: %s\n' "$_run_source"
            fi
            ;;
        esac
      done <<EOF
$(dev_kit_context_section_list "commands" "command_kinds")
EOF
      printf '\n'
    fi

    local _gaps_yaml
    _gaps_yaml="$(dev_kit_repo_factor_summary_json "$repo_root" | jq -r '
      to_entries[] |
      select(.value.status == "missing" or .value.status == "partial") |
      [
        "  - factor: " + .key,
        "    status: " + .value.status,
        (if (.value.message // "") != "" then "    message: " + .value.message else empty end),
        (if (.value.repair_target // "") != "" then "    repair_target: " + .value.repair_target else empty end),
        (if (.value.reference // "") != "" then "    reference: " + .value.reference else empty end),
        (if ((.value.evidence // []) | length) > 0 then "    evidence:" else empty end),
        ((.value.evidence // [])[]? | "      - " + .)
      ] | .[]
    ' 2>/dev/null)"
    if [ -n "$_gaps_yaml" ]; then
      dev_kit_context_section_comment_block "gaps"
      printf 'gaps:\n'
      printf '%s\n\n' "$_gaps_yaml"
    fi

    local _current_org=""
    local _current_repo_slug=""
    if dev_kit_sync_has_git_repo "$repo_root"; then
      _current_org="$(dev_kit_repo_org_from_remote "$repo_root")"
    fi
    _current_repo_slug="$(dev_kit_repo_current_slug "$repo_root" "$_repo" 2>/dev/null || true)"
    local _gh_auth_state=""
    _gh_auth_state="$(dev_kit_sync_gh_auth_state 2>/dev/null || printf 'missing')"

    local _dep_triples_file
    _dep_triples_file="$(mktemp)" || return 1

    # Source 1: Workflow references — keep only execution-shaping external
    # contracts such as reusable workflows and docker:// actions.
    # Also scans image: fields in workflow files for container job images.
    local _dep_dir
    while IFS= read -r _dep_dir; do
      [ -n "$_dep_dir" ] && [ -d "${repo_root}/${_dep_dir}" ] || continue
      # 1a: uses: references
      while IFS= read -r _match; do
        [ -n "$_match" ] || continue
        local _src_file="${_match%%:*}"
        local _src_rel="${_src_file#"${repo_root}/"}"
        local _content="${_match#*:}"
        case "$_content" in
          *uses:*/*/.github/workflows/*)
            # Reusable workflow: uses: org/repo/.github/workflows/file@ref
            local _dep_repo
            _dep_repo="$(printf '%s' "$_content" | awk '{
              sub(/.*uses:[[:space:]]*/, ""); gsub(/"/, ""); sub(/@.*/, "")
              n = split($0, a, "/")
              if (n >= 2 && a[1] != "" && a[2] != "") printf "%s/%s", a[1], a[2]
            }')"
            [ -n "$_dep_repo" ] && printf '%s|reusable workflow|%s\n' "$_dep_repo" "$_src_rel" >> "$_dep_triples_file"
            ;;
          *uses:*docker://*|*uses:*Docker://*)
            # Docker action: uses: docker://image
            local _dep_img
            _dep_img="$(printf '%s' "$_content" | awk '{sub(/.*uses:[[:space:]]*[Dd]ocker:\/\//, ""); gsub(/["'"'"']/, ""); sub(/@.*/, ""); print}')"
            [ -n "$_dep_img" ] && printf '%s|docker action|%s\n' "$_dep_img" "$_src_rel" >> "$_dep_triples_file"
            ;;
          *uses:*/*/*@*|*uses:*./*|*uses:*/*@*) ;;
        esac
      done <<EOF
$(grep -r 'uses:' "${repo_root}/${_dep_dir}/" 2>/dev/null || true)
EOF
      # 1b: image: fields in workflow files (container job images)
      while IFS= read -r _wf; do
        [ -f "$_wf" ] || continue
        local _wf_rel="${_wf#"${repo_root}/"}"
        awk -v src="$_wf_rel" '
          /^[[:space:]]*image:[[:space:]]/{
            img=$2; gsub(/["'"'"']/, "", img)
            if (img != "" && img !~ /\$/ && img !~ /\{/)
              printf "%s|workflow image|%s\n", img, src
          }
        ' "$_wf" >> "$_dep_triples_file"
      done <<EOF
$(find "${repo_root}/${_dep_dir}" -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null)
EOF
    done <<EOF
$(dev_kit_context_section_detection_list_values "dependencies" "workflow_dirs")
EOF

    # Source 2: Docker base images — FROM in Dockerfiles
    local _dep_file
    while IFS= read -r _dep_file; do
      [ -n "$_dep_file" ] && [ -f "${repo_root}/${_dep_file}" ] || continue
      awk -v src="$_dep_file" '
        /^FROM[[:space:]]/{
          img=$2; sub(/ [Aa][Ss] .*/, "", img)
          if (img !~ /^\$/ && img != "scratch")
            printf "%s|base image|%s\n", img, src
        }
      ' "${repo_root}/${_dep_file}" >> "$_dep_triples_file"
    done <<EOF
$(dev_kit_context_section_detection_list_values "dependencies" "container_files")
EOF

    # Source 3: Docker Compose images — image: fields
    while IFS= read -r _dep_file; do
      [ -n "$_dep_file" ] && [ -f "${repo_root}/${_dep_file}" ] || continue
      awk -v src="$_dep_file" '
        /^[[:space:]]*image:[[:space:]]/{
          img=$2; gsub(/["'"'"']/, "", img)
          if (img != "" && img !~ /^\$/)
            printf "%s|compose image|%s\n", img, src
        }
      ' "${repo_root}/${_dep_file}" >> "$_dep_triples_file"
    done <<EOF
$(dev_kit_context_section_detection_list_values "dependencies" "compose_files")
EOF

    # Source 4: Versioned YAML configs — version: domain/repo/module/v1
    while IFS= read -r _dep_dir; do
      [ -n "$_dep_dir" ] && [ -d "${repo_root}/${_dep_dir}" ] || continue
      while IFS= read -r _vf; do
        [ -f "$_vf" ] || continue
        case "$_vf" in */context.yaml) continue ;; esac
        local _vf_rel="${_vf#"${repo_root}/"}"
        local _vf_version _vf_module
        _vf_version="$(dev_kit_manifest_version_value "$_vf")"
        if [ -n "$_vf_version" ]; then
          _vf_module="$(printf '%s' "$_vf_version" | cut -d/ -f3)"
          if [ -n "$_vf_module" ] && [ "$_vf_module" != "$_vf_version" ]; then
            printf '%s|versioned config (%s)|%s\n' "$_vf_version" "$_vf_module" "$_vf_rel" >> "$_dep_triples_file"
          else
            printf '%s|versioned config|%s\n' "$_vf_version" "$_vf_rel" >> "$_dep_triples_file"
          fi
        fi
      done <<EOF
$(find "${repo_root}/${_dep_dir}" -type f \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null)
EOF
    done <<EOF
$(dev_kit_context_section_detection_list_values "dependencies" "versioned_dirs")
EOF

    # Source 4b: Versioned manifests declared by repo contract sections
    while IFS= read -r _manifest_dir; do
      [ -n "$_manifest_dir" ] && [ -d "${repo_root}/${_manifest_dir}" ] || continue
      while IFS= read -r _vf; do
        [ -f "$_vf" ] || continue
        case "$_vf" in */context.yaml) continue ;; esac
        local _vf_rel="${_vf#"${repo_root}/"}"
        local _vf_version _vf_module
        _vf_version="$(dev_kit_manifest_version_value "$_vf")"
        if [ -n "$_vf_version" ]; then
          _vf_module="$(printf '%s' "$_vf_version" | cut -d/ -f3)"
          if [ -n "$_vf_module" ] && [ "$_vf_module" != "$_vf_version" ]; then
            printf '%s|manifest contract (%s)|%s\n' "$_vf_version" "$_vf_module" "$_vf_rel" >> "$_dep_triples_file"
          else
            printf '%s|manifest contract|%s\n' "$_vf_version" "$_vf_rel" >> "$_dep_triples_file"
          fi
        fi
      done <<EOF
$(find "${repo_root}/${_manifest_dir}" -maxdepth 1 \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null | sort)
EOF
    done <<EOF
$(dev_kit_context_section_detection_list_values "manifests" "config_dirs")
EOF

    while IFS= read -r _vf_rel; do
      [ -n "$_vf_rel" ] && [ -f "${repo_root}/${_vf_rel}" ] || continue
      local _vf_path="${repo_root}/${_vf_rel}"
      local _vf_version _vf_module
      _vf_version="$(dev_kit_manifest_version_value "$_vf_path")"
      if [ -n "$_vf_version" ]; then
        _vf_module="$(printf '%s' "$_vf_version" | cut -d/ -f3)"
        if [ -n "$_vf_module" ] && [ "$_vf_module" != "$_vf_version" ]; then
          printf '%s|manifest contract (%s)|%s\n' "$_vf_version" "$_vf_module" "$_vf_rel" >> "$_dep_triples_file"
        else
          printf '%s|manifest contract|%s\n' "$_vf_version" "$_vf_rel" >> "$_dep_triples_file"
        fi
      fi
    done <<EOF
$(dev_kit_context_section_detection_list_values "manifests" "root_files")
EOF

    # Normalize dependency identifiers so multiple evidence types can collapse
    # into a single repo-level dependency entry.
    local _dep_norm_file
    _dep_norm_file="$(mktemp "${TMPDIR:-/tmp}/dev-kit-deps-norm.XXXXXX")"

    while IFS='|' read -r _dep_id _dep_kind _dep_src; do
      [ -n "${_dep_id:-}" ] || continue

      local _dep_key="$_dep_id"
      local _dep_declared_as=""

      case "$_dep_kind" in
        versioned\ config*|manifest\ contract*)
          _dep_declared_as="$_dep_id"
          _dep_key="$(dev_kit_dep_version_repo_slug "$_dep_id" 2>/dev/null || true)"
          [ -n "$_dep_key" ] || _dep_key="$_dep_id"
          ;;
      esac

      # Keep repo-owned manifests in the manifests section, but do not emit
      # them as external dependency contracts pointing back to the current repo.
      if [ -n "$_current_repo_slug" ] && [ "$_dep_key" = "$_current_repo_slug" ]; then
        continue
      fi
      if [ -n "$_current_org" ] && [ "$_dep_key" = "${_current_org}/${_repo}" ]; then
        continue
      fi

      printf '%s|%s|%s|%s\n' "$_dep_key" "$_dep_kind" "$_dep_src" "$_dep_declared_as" >> "$_dep_norm_file"
    done < "$_dep_triples_file"

    # ── Group triples by dep, resolve same-org, emit structured YAML ─────
    if [ -s "$_dep_norm_file" ]; then
      dev_kit_context_section_comment_block "dependencies"
      printf 'dependencies:\n'

      # Get unique dep identifiers in discovery order
      awk -F'|' '!seen[$1]++ {print $1}' "$_dep_norm_file" | while IFS= read -r _udep; do
        [ -n "$_udep" ] || continue

        # Primary type (first seen)
        local _dep_type
        _dep_type="$(awk -F'|' -v k="$_udep" '$1 == k {print $2; exit}' "$_dep_norm_file")"

        # Unique used_by files
        local _used_by
        _used_by="$(awk -F'|' -v k="$_udep" '$1 == k {print $3}' "$_dep_norm_file" | sort -u)"

        local _declared_as=""
        _declared_as="$(awk -F'|' -v k="$_udep" '$1 == k && $4 != "" {print $4; exit}' "$_dep_norm_file")"

        local _display_repo="$_udep"

        printf '  - repo: %s\n' "$_display_repo"
        printf '    kind: %s\n' "$_dep_type"

        # Resolve same-org dependencies
        local _resolve_target=""
        if dev_kit_dep_is_same_org "$_display_repo" "$_current_org"; then
          _resolve_target="$_display_repo"
        else
          # For Docker images: try matching image name to a same-org repo
          case "$_dep_type" in
            *image*|*docker*)
              _resolve_target="$(dev_kit_dep_match_image_to_org "$_display_repo" "$_current_org" "$repo_root" "$_gh_auth_state")"
              ;;
          esac
        fi

        if [ -n "$_resolve_target" ]; then
          local _resolve_out _r_resolved _r_arch _r_desc
          _resolve_out="$(dev_kit_dep_resolve "$_resolve_target" "$repo_root" "$_gh_auth_state" "$force")"
          IFS=$'\t' read -r _r_resolved _r_arch _r_desc <<< "$_resolve_out"
          printf '    resolved: %s\n' "$_r_resolved"
          [ -n "$_declared_as" ] && printf '    declared_as: %s\n' "$_declared_as"
          [ -n "$_resolve_target" ] && [ "$_resolve_target" != "$_display_repo" ] && printf '    source_repo: %s\n' "$_resolve_target"
          [ -n "$_r_arch" ]    && printf '    archetype: %s\n' "$_r_arch"
          [ -n "$_r_desc" ]    && printf '    description: %s\n' "$_r_desc"
        else
          printf '    resolved: false\n'
          [ -n "$_declared_as" ] && printf '    declared_as: %s\n' "$_declared_as"
        fi

        # Emit used_by
        if [ -n "$_used_by" ]; then
          printf '    used_by:\n'
          printf '%s\n' "$_used_by" | while IFS= read -r _ub; do
            [ -n "$_ub" ] || continue
            printf '      - %s\n' "$_ub"
          done
        fi
      done
      printf '\n'
    fi

    rm -f "$_dep_triples_file"
    rm -f "$_dep_norm_file"

    local _manifests_yaml=""
    local _yaml_rel _yaml_kind _yaml_desc _manifest_meta _manifest_dir
    while IFS= read -r _yaml_rel; do
      [ -n "$_yaml_rel" ] || continue
      _manifests_yaml="${_manifests_yaml}$(dev_kit_manifest_yaml_item "$repo_root" "$_yaml_rel" "githubWorkflow")\n"
    done <<EOF
$(dev_kit_repo_reusable_workflow_contract_files "$repo_root")
EOF
    while IFS= read -r _yaml_rel; do
      [ -n "$_yaml_rel" ] || continue
      _manifests_yaml="${_manifests_yaml}$(dev_kit_manifest_yaml_item "$repo_root" "$_yaml_rel")\n"
    done <<EOF
$(dev_kit_repo_contract_manifest_files "$repo_root")
EOF
    if [ -n "$_manifests_yaml" ]; then
      dev_kit_context_section_comment_block "manifests"
      printf 'manifests:\n'
      printf '%b\n' "$_manifests_yaml"
    fi

  } > "$context_path"

  printf "%s" "$context_path"
}
