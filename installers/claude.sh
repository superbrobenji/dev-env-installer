# shellcheck shell=bash
# Installer: claude.

claude_check() {
  command -v claude >/dev/null 2>&1
}

_claude_merge_settings() {
  mkdir -p "$HOME/.claude"
  python3 - <<'PYEOF'
import json, os

settings_path = os.path.join(os.environ['HOME'], '.claude', 'settings.json')

base = {
    'model': 'claude-opus-4-7',
    'enabledPlugins': {
        'typescript-lsp@claude-plugins-official': True,
        'superpowers@claude-plugins-official': True,
        'superpowers@superpowers-marketplace': True,
        'caveman@caveman': True,
        'lua-lsp@claude-plugins-official': True,
        'pyright-lsp@claude-plugins-official': True,
    },
    'extraKnownMarketplaces': {
        'superpowers-marketplace': {
            'source': {'source': 'github', 'repo': 'obra/superpowers-marketplace'}
        },
        'caveman': {
            'source': {'source': 'github', 'repo': 'JuliusBrussee/caveman'}
        },
    },
}

existing = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        try:
            existing = json.load(f)
        except (json.JSONDecodeError, ValueError):
            existing = {}

merged = {**existing, **base}
for nested_key in ('enabledPlugins', 'extraKnownMarketplaces'):
    if nested_key in existing:
        merged[nested_key] = {**existing[nested_key], **base[nested_key]}

with open(settings_path, 'w') as f:
    json.dump(merged, f, indent=2)
    f.write('\n')
PYEOF
}

_claude_add_marketplaces() {
  local known
  known="$(claude plugin marketplace list 2>/dev/null || true)"

  if ! printf '%s' "$known" | grep -qF "superpowers-marketplace"; then
    claude plugin marketplace add obra/superpowers-marketplace \
      || warn "Failed to add superpowers-marketplace"
  fi

  if ! printf '%s' "$known" | grep -qF "caveman"; then
    claude plugin marketplace add JuliusBrussee/caveman \
      || warn "Failed to add caveman marketplace"
  fi
}

_claude_install_plugins() {
  local installed
  installed="$(claude plugin list 2>/dev/null || true)"

  local plugins=(
    "typescript-lsp@claude-plugins-official"
    "superpowers@claude-plugins-official"
    "superpowers@superpowers-marketplace"
    "caveman@caveman"
    "lua-lsp@claude-plugins-official"
    "pyright-lsp@claude-plugins-official"
  )

  local plugin
  for plugin in "${plugins[@]}"; do
    if ! printf '%s' "$installed" | grep -qF "$plugin"; then
      claude plugin install "$plugin" \
        || warn "Failed to install plugin $plugin"
    fi
  done
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
