#!/usr/bin/env bash
set -euo pipefail

DEV_KIT_BIN_DIR="${DEV_KIT_BIN_DIR:-$HOME/.local/bin}"
DEV_KIT_HOME="${DEV_KIT_HOME:-$HOME/.udx/dev.kit}"
DEV_KIT_INSTALL_REPO="${DEV_KIT_INSTALL_REPO:-udx/rabbit-repo}"
DEV_KIT_INSTALL_REF="${DEV_KIT_INSTALL_REF:-latest}"
DEV_KIT_INSTALL_ARCHIVE_URL="${DEV_KIT_INSTALL_ARCHIVE_URL:-https://codeload.github.com/${DEV_KIT_INSTALL_REPO}/tar.gz/refs/heads/${DEV_KIT_INSTALL_REF}}"

dev_kit_install_script_path() {
  if [ -n "${BASH_SOURCE[0]-}" ]; then
    printf '%s\n' "${BASH_SOURCE[0]}"
    return 0
  fi

  if [ "${0:-}" != "bash" ] && [ "${0:-}" != "-bash" ] && [ -n "${0:-}" ]; then
    printf '%s\n' "$0"
    return 0
  fi

  return 1
}

dev_kit_install_script_dir() {
  local script_path=""

  script_path="$(dev_kit_install_script_path)" || return 1
  cd "$(dirname "$script_path")" && pwd
}

DEV_KIT_INSTALL_SCRIPT_DIR="$(dev_kit_install_script_dir 2>/dev/null || true)"
DEV_KIT_INSTALL_REPO_DIR="$(cd "${DEV_KIT_INSTALL_SCRIPT_DIR}/../.." 2>/dev/null && pwd || true)"

if [ -f "$DEV_KIT_INSTALL_REPO_DIR/lib/modules/output.sh" ]; then
  # shellcheck disable=SC1090
  . "$DEV_KIT_INSTALL_REPO_DIR/lib/modules/output.sh"
fi

dev_kit_install_usage() {
  cat <<'EOF'
Usage: bash install.sh

This installer does not modify shell profiles.
EOF
}

dev_kit_install_repo_dir() {
  local script_dir=""
  local repo_dir=""

  script_dir="$(dev_kit_install_script_dir)" || return 1
  repo_dir="$(cd "${script_dir}/../.." 2>/dev/null && pwd || true)"

  if [ -n "$repo_dir" ] && [ -f "$repo_dir/bin/dev-kit" ] && [ -d "$repo_dir/lib" ] && [ -d "$repo_dir/src" ]; then
    printf '%s\n' "$repo_dir"
    return 0
  fi

  return 1
}

dev_kit_install_download() {
  local url="$1"
  local archive_file="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$archive_file"
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$archive_file" "$url"
    return 0
  fi

  echo "curl or wget is required to install dev.kit" >&2
  exit 1
}

dev_kit_install_remove_npm_install() {
  if ! command -v npm >/dev/null 2>&1; then
    return 0
  fi

  if ! npm list -g @udx/dev-kit --depth=0 >/dev/null 2>&1; then
    return 0
  fi

  echo ""
  echo "dev.kit: detected previous npm installation"
  echo "  package: @udx/dev-kit"

  if npm uninstall -g @udx/dev-kit >/dev/null 2>&1; then
    echo ""
    echo "  removed — curl version is now the single install"
    echo ""
    return 0
  fi

  echo ""
  echo "  warning: failed to remove npm installation automatically"
  echo ""
  return 0
}

dev_kit_install_extract_root() {
  local archive_file="$1"
  local extract_dir="$2"

  tar -xzf "$archive_file" -C "$extract_dir"
  find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1
}

dev_kit_install_source_dir() {
  local repo_dir=""
  local tmp_dir=""
  local archive_file=""
  local source_dir=""

  if repo_dir="$(dev_kit_install_repo_dir)"; then
    printf '%s\n' "$repo_dir"
    return 0
  fi

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/dev-kit-install.XXXXXX")"
  archive_file="${tmp_dir}/dev-kit.tar.gz"

  dev_kit_install_download "$DEV_KIT_INSTALL_ARCHIVE_URL" "$archive_file"
  source_dir="$(dev_kit_install_extract_root "$archive_file" "$tmp_dir")"

  if [ ! -f "$source_dir/bin/dev-kit" ] || [ ! -d "$source_dir/lib" ] || [ ! -d "$source_dir/src" ]; then
    echo "Downloaded archive does not contain a valid dev.kit source tree" >&2
    exit 1
  fi

  printf '%s\n' "$source_dir"
}

dev_kit_install_copy_tree() {
  local src="$1"
  local dst="$2"
  mkdir -p "$dst"
  cp -R "$src/." "$dst/"
}

dev_kit_install_path_contains_bin_dir() {
  case ":$PATH:" in
    *":${DEV_KIT_BIN_DIR}:"*) return 0 ;;
    *) return 1 ;;
  esac
}

main() {
  local source_dir=""
  local target=""

  if [ "$#" -gt 0 ]; then
    dev_kit_install_usage >&2
    exit 1
  fi

  dev_kit_install_remove_npm_install

  source_dir="$(dev_kit_install_source_dir)"
  target="${DEV_KIT_BIN_DIR}/dev.kit"

  mkdir -p "$DEV_KIT_HOME" "$DEV_KIT_BIN_DIR"
  rm -rf "$DEV_KIT_HOME/bin" "$DEV_KIT_HOME/lib" "$DEV_KIT_HOME/src" "$DEV_KIT_HOME/config" "$DEV_KIT_HOME/source" "$DEV_KIT_HOME/state"

  dev_kit_install_copy_tree "$source_dir/bin" "$DEV_KIT_HOME/bin"
  dev_kit_install_copy_tree "$source_dir/lib" "$DEV_KIT_HOME/lib"
  dev_kit_install_copy_tree "$source_dir/src" "$DEV_KIT_HOME/src"

  find "$DEV_KIT_HOME/bin" -type f -exec chmod +x {} \;
  ln -sfn "$DEV_KIT_HOME/bin/dev-kit" "$target"
  ln -sfn "$DEV_KIT_HOME/bin/dev-kit" "${DEV_KIT_BIN_DIR}/dev-kit"

  if command -v dev_kit_output_title >/dev/null 2>&1; then
    dev_kit_output_title "Installed dev.kit"
    dev_kit_output_summary "Human-first raw output, stable JSON for agents"
    dev_kit_output_section "install"
    dev_kit_output_row "binary" "$target"
    dev_kit_output_row "home" "$DEV_KIT_HOME"
  else
    echo "Installed dev.kit"
    echo "binary: $target"
    echo "home:   $DEV_KIT_HOME"
  fi
  if dev_kit_install_path_contains_bin_dir; then
    if command -v dev_kit_output_row >/dev/null 2>&1; then
      dev_kit_output_section "next"
      dev_kit_output_list_item "PATH already includes $DEV_KIT_BIN_DIR"
      dev_kit_output_list_item "run dev.kit"
    else
      echo "shell:  PATH already includes $DEV_KIT_BIN_DIR"
      echo "next:   run dev.kit"
    fi
  else
    if command -v dev_kit_output_row >/dev/null 2>&1; then
      dev_kit_output_section "next"
      dev_kit_output_list_item "shell profiles were left unchanged"
      dev_kit_output_list_item "export PATH=\"$DEV_KIT_BIN_DIR:\$PATH\""
      dev_kit_output_list_item "run dev.kit"
    else
      echo "shell:  unchanged"
      echo "next:   export PATH=\"$DEV_KIT_BIN_DIR:\$PATH\""
      echo "then:   dev.kit"
    fi
  fi
}

main "$@"
