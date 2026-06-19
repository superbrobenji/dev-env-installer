# shellcheck shell=bash
# Installer: ripgrep. Prefer pkg manager, fall back to GitHub release tarball.

ripgrep_check() {
  command -v rg >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/rg" ]]
}

ripgrep_install() {
  log "Installing ripgrep"
  if [[ "$OS" == "macos" ]] || needs_sudo; then
    if pkg_install_system "$(name_for ripgrep)"; then
      success "ripgrep installed"
      return 0
    fi
  fi
  _ripgrep_install_release
}

_ripgrep_install_release() {
  log "Falling back to ripgrep GitHub release"
  local pattern url tmp
  case "$ARCH" in
    x86_64) pattern="x86_64-unknown-linux-musl.tar.gz" ;;
    arm64)  pattern="aarch64-unknown-linux-gnu.tar.gz" ;;
    *)      error "Unsupported arch for ripgrep release: $ARCH"; return 1 ;;
  esac
  url="$(github_latest_release_url "BurntSushi/ripgrep" "$pattern")"
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/rg.tar.gz"
  tar -xzf "$tmp/rg.tar.gz" -C "$tmp"
  mkdir -p "$HOME/.local/bin"
  # shellcheck disable=SC2086,SC2046
  # Glob is intentional: release tarball extracts to a versioned subdir
  # like ripgrep-14.1.0-aarch64-unknown-linux-gnu/.
  install -m 0755 "$tmp"/*/rg "$HOME/.local/bin/rg"
  rm -rf "$tmp"
  success "ripgrep installed to ~/.local/bin/rg"
}
