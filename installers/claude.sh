# shellcheck shell=bash
# Installer: claude.

claude_check() {
  command -v claude >/dev/null 2>&1
}

claude_install() {
  log "Installing Claude Code CLI"
  npm install -g @anthropic-ai/claude-code

  log "Merging Claude settings"
  _claude_merge_settings

  log "Adding Claude plugin marketplaces"
  _claude_add_marketplaces

  log "Installing Claude plugins"
  _claude_install_plugins

  success "claude installed"
}
