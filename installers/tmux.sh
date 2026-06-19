# shellcheck shell=bash
# Installer: tmux.

tmux_check() {
  command -v tmux >/dev/null 2>&1
}

tmux_install() {
  log "Installing tmux"
  pkg_install_system "$(name_for tmux)"
  success "tmux installed"
}
