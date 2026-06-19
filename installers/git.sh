# shellcheck shell=bash
# Installer: git.

git_check() {
  command -v git >/dev/null 2>&1
}

git_install() {
  log "Installing git"
  pkg_install_system "$(name_for git)"
  success "git installed"
}
