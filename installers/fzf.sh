# shellcheck shell=bash
# Installer: fzf.

fzf_check() {
  command -v fzf >/dev/null 2>&1 || [[ -x "$HOME/.fzf/bin/fzf" ]]
}

fzf_install() {
  log "Installing fzf"
  if [[ "$OS" == "macos" ]] || needs_sudo; then
    pkg_install_system "$(name_for fzf)" || _fzf_install_userlocal
  else
    _fzf_install_userlocal
  fi
  success "fzf installed"
}

_fzf_install_userlocal() {
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --all --no-bash --no-fish
}
