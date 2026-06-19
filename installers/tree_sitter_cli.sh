# shellcheck shell=bash
# Installer: tree-sitter CLI (global npm package).

tree_sitter_cli_check() {
  command -v tree-sitter >/dev/null 2>&1
}

tree_sitter_cli_install() {
  command -v npm >/dev/null 2>&1 || { warn "npm not found; skipping tree-sitter-cli"; return 1; }
  log "Installing tree-sitter-cli (global npm)"
  npm install -g tree-sitter-cli || { warn "tree-sitter-cli install failed"; return 1; }
  success "tree-sitter-cli installed"
}
