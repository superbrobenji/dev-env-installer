# shellcheck shell=bash
# Installer: gcc, make, pkg-config (or platform equivalent).

build_toolchain_check() {
  command -v cc >/dev/null 2>&1 && command -v make >/dev/null 2>&1
}

build_toolchain_install() {
  log "Installing build toolchain"
  if [[ "$OS" == "macos" ]]; then
    if ! xcode-select -p >/dev/null 2>&1; then
      info "Triggering Xcode Command Line Tools install — complete the GUI prompt"
      xcode-select --install || true
      until xcode-select -p >/dev/null 2>&1; do sleep 5; done
    fi
  else
    # shellcheck disable=SC2046
    pkg_install_system $(name_for build-toolchain)
  fi
  success "build toolchain installed"
}
