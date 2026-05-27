#!/usr/bin/env bash

DEV_KIT_OUTPUT_LABEL_WIDTH="${DEV_KIT_OUTPUT_LABEL_WIDTH:-18}"
DEV_KIT_PROGRESS_SOFT_TIMEOUT="${DEV_KIT_PROGRESS_SOFT_TIMEOUT:-8}"
DEV_KIT_PROGRESS_HARD_TIMEOUT="${DEV_KIT_PROGRESS_HARD_TIMEOUT:-90}"

dev_kit_output_title() {
  printf '%s\n' "$1"
}

dev_kit_output_section() {
  printf '\n[%s]\n' "$1"
}

dev_kit_output_row() {
  local label="$1"
  local value="${2:-}"

  printf '  %-*s %s\n' "$DEV_KIT_OUTPUT_LABEL_WIDTH" "${label}:" "$value"
}

dev_kit_output_summary() {
  local value="${1:-}"
  printf '\n> %s\n' "$value"
}

dev_kit_output_list_item() {
  printf '  - %s\n' "$1"
}

dev_kit_output_list_from_lines() {
  local item=""

  while IFS= read -r item; do
    [ -n "$item" ] || continue
    dev_kit_output_list_item "$item"
  done
}

dev_kit_output_kv_list_from_pipe() {
  local line=""
  local key=""
  local value=""

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key="${line%%|*}"
    value="${line#*|}"
    dev_kit_output_row "$key" "$value"
  done
}

dev_kit_output_first_lines() {
  local max_items="${1:-3}"
  local line=""
  local count=0

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s\n' "$line"
    count=$((count + 1))
    if [ "$count" -ge "$max_items" ]; then
      break
    fi
  done
}

# ── Spinner ───────────────────────────────────────────────────────────────────
# Background Braille spinner for long-running operations.
# Writes to stderr so it works even when stdout is redirected to a file.
# Skipped in non-interactive environments (CI, no TTY).

_DEV_KIT_SPINNER_PID=""
_DEV_KIT_SPINNER_MSG=""

dev_kit_spinner_enabled() {
  [ -t 2 ] || return 1
  [ "${DEV_KIT_SPINNER_DISABLE:-0}" != "1" ] || return 1
}

dev_kit_spinner_start() {
  local msg="${1:-}"
  dev_kit_spinner_enabled || return 0
  _DEV_KIT_SPINNER_MSG="$msg"
  printf '  ⠋ %s' "$msg" >&2
  (
    set +e
    trap 'exit 0' TERM INT HUP
    while :; do
      for c in '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'; do
        printf '\r  %s %s' "$c" "$msg" >&2
        sleep 0.1 2>/dev/null || sleep 1
      done
    done
  ) &
  _DEV_KIT_SPINNER_PID=$!
}

dev_kit_spinner_stop() {
  local result="${1:-}"
  if [ -n "${_DEV_KIT_SPINNER_PID:-}" ]; then
    kill "$_DEV_KIT_SPINNER_PID" 2>/dev/null
    wait "$_DEV_KIT_SPINNER_PID" 2>/dev/null || true
    _DEV_KIT_SPINNER_PID=""
  fi
  _DEV_KIT_SPINNER_MSG=""
  dev_kit_spinner_enabled || return 0
  if [ -n "$result" ]; then
    printf '\r  ✓ %-40s\n' "$result" >&2
  else
    printf '\r%-50s\r' '' >&2
  fi
}

dev_kit_spinner_notice() {
  local message="${1:-}"
  [ -n "$message" ] || return 0
  if dev_kit_spinner_enabled && [ -n "${_DEV_KIT_SPINNER_PID:-}" ]; then
    kill "$_DEV_KIT_SPINNER_PID" 2>/dev/null
    wait "$_DEV_KIT_SPINNER_PID" 2>/dev/null || true
    _DEV_KIT_SPINNER_PID=""
    printf '\r  ◦ %s\n' "$message" >&2
    return 0
  fi
  printf '  - %s\n' "$message" >&2
}

dev_kit_process_descendants() {
  local root_pid="$1"

  ps -eo pid=,ppid= | awk -v root="$root_pid" '
    {
      pid = $1
      ppid = $2
      children[ppid] = children[ppid] " " pid
    }

    function walk(node, list, count, idx) {
      count = split(children[node], list, " ")
      for (idx = 1; idx <= count; idx++) {
        if (list[idx] == "") {
          continue
        }
        walk(list[idx])
        print list[idx]
      }
    }

    END {
      walk(root)
    }
  '
}

dev_kit_process_signal_tree() {
  local signal="$1"
  local root_pid="$2"
  local child_pid=""

  while IFS= read -r child_pid; do
    [ -n "$child_pid" ] || continue
    kill "-${signal}" "$child_pid" 2>/dev/null || true
  done <<EOF
$(dev_kit_process_descendants "$root_pid")
EOF

  kill "-${signal}" "$root_pid" 2>/dev/null || true
}

dev_kit_process_signal_list() {
  local signal="$1"
  local pid_list="$2"
  local target_pid=""

  while IFS= read -r target_pid; do
    [ -n "$target_pid" ] || continue
    kill "-${signal}" "$target_pid" 2>/dev/null || true
  done <<EOF
$pid_list
EOF
}

dev_kit_run_guarded() {
  local label="$1"
  local soft_timeout="${2:-$DEV_KIT_PROGRESS_SOFT_TIMEOUT}"
  local hard_timeout="${3:-$DEV_KIT_PROGRESS_HARD_TIMEOUT}"
  local soft_message="${4:-${label} is taking longer than usual}"
  shift 4

  local stdout_file=""
  local stderr_file=""
  local pgid_file=""
  local pid=""
  local guarded_pgid=""
  local started_at=""
  local now=""
  local elapsed=0
  local soft_announced=0
  local status=0
  local timeout_pids=""

  stdout_file="$(mktemp "${TMPDIR:-/tmp}/dev-kit-guard-out.XXXXXX")" || return 1
  stderr_file="$(mktemp "${TMPDIR:-/tmp}/dev-kit-guard-err.XXXXXX")" || {
    rm -f "$stdout_file"
    return 1
  }
  pgid_file="$(mktemp "${TMPDIR:-/tmp}/dev-kit-guard-pgid.XXXXXX")" || {
    rm -f "$stdout_file" "$stderr_file"
    return 1
  }

  (
    set -m 2>/dev/null || true
    "$@" &
    printf '%s\n' "$!" > "$pgid_file"
    wait "$!"
  ) >"$stdout_file" 2>"$stderr_file" &
  pid=$!
  started_at="$(date +%s)"

  dev_kit_spinner_start "$label"

  while kill -0 "$pid" 2>/dev/null; do
    sleep 1
    now="$(date +%s)"
    elapsed=$((now - started_at))

    if [ "$soft_timeout" -gt 0 ] && [ "$elapsed" -ge "$soft_timeout" ] && [ "$soft_announced" -eq 0 ]; then
      dev_kit_spinner_notice "$soft_message"
      soft_announced=1
    fi

    if [ "$hard_timeout" -gt 0 ] && [ "$elapsed" -ge "$hard_timeout" ]; then
      guarded_pgid="$(cat "$pgid_file" 2>/dev/null || true)"
      timeout_pids="$(dev_kit_process_descendants "$pid")
$pid"
      if [ -n "$guarded_pgid" ]; then
        kill -TERM "-${guarded_pgid}" 2>/dev/null || true
      fi
      dev_kit_process_signal_list TERM "$timeout_pids"
      sleep 1
      if [ -n "$guarded_pgid" ]; then
        kill -KILL "-${guarded_pgid}" 2>/dev/null || true
      fi
      dev_kit_process_signal_list KILL "$timeout_pids"
      wait "$pid" 2>/dev/null || true
      dev_kit_spinner_stop ""
      [ -s "$stdout_file" ] && cat "$stdout_file"
      [ -s "$stderr_file" ] && cat "$stderr_file" >&2
      printf 'dev.kit timeout: %s exceeded %ss and was stopped to prevent an endless run.\n' \
        "$label" "$hard_timeout" >&2
      rm -f "$stdout_file" "$stderr_file" "$pgid_file"
      return 124
    fi
  done

  wait "$pid"
  status=$?
  dev_kit_spinner_stop ""

  [ -s "$stdout_file" ] && cat "$stdout_file"
  [ -s "$stderr_file" ] && cat "$stderr_file" >&2
  rm -f "$stdout_file" "$stderr_file" "$pgid_file"
  return "$status"
}

# ── Status-aware factor row ───────────────────────────────────────────────────

dev_kit_output_status_row() {
  local label="$1"
  local status="$2"
  local icon=""
  case "$status" in
    present)        icon="✓" ;;
    partial)        icon="◦" ;;
    missing)        icon="✗" ;;
    not_applicable) icon="·" ; status="n/a" ;;
    *)              icon=" " ;;
  esac
  printf '  %-*s %s %s\n' "$DEV_KIT_OUTPUT_LABEL_WIDTH" "${label}:" "$icon" "$status"
}
