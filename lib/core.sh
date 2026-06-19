# shellcheck shell=bash
# Shared logging, strict mode, dry-run flag.
# Sourced by every other lib/installer file.

# Strict mode for any script that sources us.
set -Eeuo pipefail

# Log file. Override via CORE_LOG_FILE env. Default: ~/.dev-env-installer.log
: "${CORE_LOG_FILE:=${HOME}/.dev-env-installer.log}"
: "${DRY_RUN:=false}"

# Ensure log file exists. Sets _CORE_LOG_READY=1 on success, =stderr_only on failure.
# Idempotent — only does work the first time.
_core_init_log() {
  [[ -n "${_CORE_LOG_READY:-}" ]] && return 0
  local dir
  dir="$(dirname "${CORE_LOG_FILE}")"
  if mkdir -p "$dir" 2>/dev/null && { [[ -f "$CORE_LOG_FILE" ]] || : > "$CORE_LOG_FILE" 2>/dev/null; }; then
    _CORE_LOG_READY=1
  else
    _CORE_LOG_READY=stderr_only
  fi
}

_core_emit() {
  local prefix="$1"; shift
  local msg="$*"
  _core_init_log
  if [[ "$_CORE_LOG_READY" == "1" ]]; then
    printf '%s %s\n' "$prefix" "$msg" | tee -a "$CORE_LOG_FILE"
  else
    printf '%s %s\n' "$prefix" "$msg"
  fi
}

_core_emit_log() {
  local prefix="$1"; shift
  local msg="$*"
  _core_init_log
  if [[ "${VERBOSE:-false}" == "true" ]]; then
    _core_emit "$prefix" "$msg"
  elif [[ "$_CORE_LOG_READY" == "1" ]]; then
    printf '%s %s\n' "$prefix" "$msg" >> "$CORE_LOG_FILE"
  fi
}

log()     { _core_emit_log "🔹" "$*"; }
info()    { _core_emit "ℹ️ " "$*"; }
success() { _core_emit "✅" "$*"; }
warn()    { _core_emit "⚠️ " "$*"; }
error()   { _core_emit "❌" "$*" >&2; }

is_dry_run() {
  [[ "${DRY_RUN}" == "true" ]]
}

# Trap unexpected errors with line number and exit code.
_core_on_err() {
  local exit_code=$?
  local line=$1
  error "Aborted at line ${line} (exit ${exit_code})"
  exit "$exit_code"
}
trap '_core_on_err $LINENO' ERR
