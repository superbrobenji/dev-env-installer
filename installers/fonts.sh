# shellcheck shell=bash
# Installer: FiraCode + NerdFont symbols.

NERDFONT_DIR_LINUX="$HOME/.local/share/fonts"
NERDFONT_DIR_MACOS="$HOME/Library/Fonts"

fonts_check() {
  local dir
  if [[ "$OS" == "macos" ]]; then dir="$NERDFONT_DIR_MACOS"; else dir="$NERDFONT_DIR_LINUX"; fi
  # Accept the ls-grep idiom here for terseness; compgen/find alternatives are more verbose.
  # shellcheck disable=SC2010
  [[ -d "$dir" ]] && ls "$dir" 2>/dev/null | grep -qiE 'fira.*code'
}

fonts_install() {
  log "Installing fonts: FiraCode + NerdFont symbols"
  if [[ "$OS" == "macos" ]]; then
    pkg_install_cask "$(name_for fira-code)"
  else
    pkg_install_system "$(name_for fira-code)"
  fi
  _fonts_install_nerdfont
  if command -v fc-cache >/dev/null 2>&1; then fc-cache -fv >/dev/null; fi
  success "fonts installed"
}

_fonts_install_nerdfont() {
  local url tmp dest
  url="$(github_latest_release_url "ryanoasis/nerd-fonts" "NerdFontsSymbolsOnly.zip")" || return 1
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/nf.zip"
  if [[ "$OS" == "macos" ]]; then dest="$NERDFONT_DIR_MACOS"; else dest="$NERDFONT_DIR_LINUX"; fi
  mkdir -p "$dest"
  unzip -oq "$tmp/nf.zip" -d "$dest"
  rm -rf "$tmp"
}
