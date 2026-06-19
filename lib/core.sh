# shellcheck shell=bash
# Shared logging, strict mode, dry-run flag.
# Sourced by every other lib/installer file.

# Strict mode for any script that sources us.
set -Eeuo pipefail

# Log file. Override via CORE_LOG_FILE env. Default: ~/.dev-env-installer.log
: "${CORE_LOG_FILE:=${HOME}/.dev-env-installer.log}"
: "${DRY_RUN:=false}"

# Ensure log file exists.
_core_init_log() {
  local dir
  dir="$(dirname "${CORE_LOG_FILE}")"
  [[ -d "$dir" ]] || mkdir -p "$dir"
  [[ -f "$CORE_LOG_FILE" ]] || : > "$CORE_LOG_FILE"
}

_core_emit() {
  local prefix="$1"; shift
  local msg="$*"
  _core_init_log
  printf '%s %s\n' "$prefix" "$msg" | tee -a "$CORE_LOG_FILE"
}

log()     { _core_emit "🔹" "$*"; }
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
