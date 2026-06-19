# shellcheck shell=bash
# Hybrid sudo handling. Sets SUDO_MODE=full|userlocal.

: "${SUDO_MODE:=}"
_SUDO_KEEPALIVE_PID=""

needs_sudo() {
  [[ "$SUDO_MODE" == "full" ]]
}

sudo_run() {
  if [[ "$SUDO_MODE" == "full" ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

# Probe sudo: prefer NOPASSWD; otherwise prompt once with `sudo -v`.
# On macOS we force userlocal (Homebrew refuses sudo).
probe_sudo() {
  if [[ "${OS:-}" == "macos" ]]; then
    SUDO_MODE=userlocal
    info "Sudo not required (macOS)"
    return 0
  fi

  if sudo -n true 2>/dev/null; then
    SUDO_MODE=full
    success "Sudo available (NOPASSWD)"
    _start_keepalive
    return 0
  fi

  if [[ "${NO_SUDO:-false}" == "true" ]]; then
    SUDO_MODE=userlocal
    warn "Forced user-local mode (--no-sudo); skipping system packages"
    return 0
  fi

  info "Sudo required for system packages — you may be prompted"
  if sudo -v; then
    SUDO_MODE=full
    _start_keepalive
    return 0
  fi

  warn "Sudo refused; falling back to user-local mode"
  SUDO_MODE=userlocal
  return 0
}

_start_keepalive() {
  ( while true; do sudo -n true 2>/dev/null || exit; sleep 60; kill -0 $$ 2>/dev/null || exit; done ) &
  _SUDO_KEEPALIVE_PID=$!
  trap _stop_keepalive EXIT
}

_stop_keepalive() {
  [[ -n "$_SUDO_KEEPALIVE_PID" ]] && kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
