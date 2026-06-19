# shellcheck shell=bash
# Installer: Node (LTS, via nvm).

node_check() {
  ensure_nvm_loaded 2>/dev/null || true
  command -v node >/dev/null 2>&1
}

node_install() {
  log "Installing Node.js (LTS)"
  ensure_nvm_loaded
  nvm install --lts
  nvm alias default 'lts/*'
  nvm use default
  success "node installed"
}
