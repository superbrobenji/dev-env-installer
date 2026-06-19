# shellcheck shell=bash
# Installer: curl, wget, unzip, tar, jq, ca-certificates.

basics_check() {
  command -v curl >/dev/null 2>&1 \
    && command -v wget >/dev/null 2>&1 \
    && command -v unzip >/dev/null 2>&1 \
    && command -v tar >/dev/null 2>&1 \
    && command -v jq >/dev/null 2>&1
}

basics_install() {
  log "Installing basics (curl, wget, unzip, tar, jq)"
  # shellcheck disable=SC2046
  pkg_install_system $(name_for basics)
  success "basics installed"
}
