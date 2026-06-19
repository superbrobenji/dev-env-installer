# shellcheck shell=bash
# Installer: python3 + pip.

python3_check() {
  command -v python3 >/dev/null 2>&1 \
    && (command -v pip3 >/dev/null 2>&1 || python3 -m pip --version >/dev/null 2>&1)
}

python3_install() {
  log "Installing python3 + pip"
  # shellcheck disable=SC2046
  pkg_install_system $(name_for python3)
  success "python3 installed"
}
