# shellcheck shell=bash
# Installer: zsh.

zsh_check() {
  command -v zsh >/dev/null 2>&1
}

zsh_install() {
  log "Installing zsh"
  pkg_install_system "$(name_for zsh)"
  # Ensure zsh is in /etc/shells so chsh accepts it.
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ -n "$zsh_path" ]] && ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    if needs_sudo; then
      echo "$zsh_path" | sudo_run tee -a /etc/shells >/dev/null
    fi
  fi
  success "zsh installed"
}
