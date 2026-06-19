# shellcheck shell=bash
# Installer: nvm. User-local install to $HOME/.nvm.

nvm_check() {
  [[ -s "$HOME/.nvm/nvm.sh" ]]
}

nvm_install() {
  log "Installing nvm"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
  ensure_nvm_loaded
  success "nvm installed"
}

# Loads nvm into the current shell. Idempotent. Source before any nvm-dependent step.
ensure_nvm_loaded() {
  export NVM_DIR="$HOME/.nvm"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
  fi
}
