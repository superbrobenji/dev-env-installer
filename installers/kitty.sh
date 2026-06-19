# shellcheck shell=bash
# Installer: kitty. macOS = brew cask. Linux = official installer + desktop integration.

kitty_check() {
  command -v kitty >/dev/null 2>&1 \
    || [[ -x "/Applications/kitty.app/Contents/MacOS/kitty" ]] \
    || [[ -x "$HOME/.local/kitty.app/bin/kitty" ]]
}

kitty_install() {
  log "Installing kitty"
  if [[ "$OS" == "macos" ]]; then
    pkg_install_cask kitty
  else
    _kitty_install_linux
  fi
  success "kitty installed"
}

_kitty_install_linux() {
  curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n
  mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
  ln -sf "$HOME/.local/kitty.app/bin/kitty"  "$HOME/.local/bin/kitty"
  ln -sf "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/kitten"
  cp -f "$HOME/.local/kitty.app/share/applications/kitty.desktop"      "$HOME/.local/share/applications/" 2>/dev/null || true
  cp -f "$HOME/.local/kitty.app/share/applications/kitty-open.desktop" "$HOME/.local/share/applications/" 2>/dev/null || true
  sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" \
    "$HOME/.local/share/applications/"kitty*.desktop 2>/dev/null || true
  sed -i "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|g" \
    "$HOME/.local/share/applications/"kitty*.desktop 2>/dev/null || true
}
