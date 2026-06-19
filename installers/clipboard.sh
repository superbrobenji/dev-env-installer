# shellcheck shell=bash
# Installer: clipboard tools. Linux: xclip + wl-clipboard. macOS: pngpaste.

clipboard_check() {
  if [[ "$OS" == "macos" ]]; then
    command -v pngpaste >/dev/null 2>&1
  else
    command -v xclip >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1
  fi
}

clipboard_install() {
  log "Installing clipboard tools"
  if [[ "$OS" == "macos" ]]; then
    pkg_install_system "$(name_for pngpaste)"
  else
    if [[ "$DISPLAY_SRV" == "none" ]]; then
      warn "Headless system; skipping clipboard tools"
      return 0
    fi
    pkg_install_system "$(name_for clipboard-x11)" "$(name_for clipboard-wayland)"
  fi
  success "clipboard tools installed"
}
