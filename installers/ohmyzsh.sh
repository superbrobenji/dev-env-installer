# shellcheck shell=bash
# Installer: oh-my-zsh.

ohmyzsh_check() {
  [[ -d "$HOME/.oh-my-zsh" ]]
}

ohmyzsh_install() {
  log "Installing oh-my-zsh"
  local script
  script="$(mktemp)"
  curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$script"
  RUNZSH=no KEEP_ZSHRC=yes bash "$script" --unattended
  rm -f "$script"
  success "oh-my-zsh installed"
}
