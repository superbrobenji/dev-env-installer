# shellcheck shell=bash
# Installer: Neovim. Prefer GitHub release tarball; build from source as fallback.

neovim_check() {
  command -v nvim >/dev/null 2>&1
}

neovim_install() {
  log "Installing Neovim"
  if _neovim_install_release; then
    success "neovim installed (prebuilt)"
    return 0
  fi
  warn "Prebuilt release unavailable; falling back to source build"
  _neovim_install_source
  success "neovim installed (from source)"
}

_neovim_install_release() {
  local asset
  case "${OS}-${ARCH}" in
    macos-arm64)  asset="nvim-macos-arm64.tar.gz" ;;
    macos-x86_64) asset="nvim-macos-x86_64.tar.gz" ;;
    linux-x86_64) asset="nvim-linux-x86_64.tar.gz" ;;
    linux-arm64)  asset="nvim-linux-arm64.tar.gz" ;;
    *) return 1 ;;
  esac
  local url tmp
  url="$(github_latest_release_url "neovim/neovim" "$asset")" || return 1
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/nvim.tar.gz" || { rm -rf "$tmp"; return 1; }
  mkdir -p "$HOME/.local"
  tar -xzf "$tmp/nvim.tar.gz" -C "$HOME/.local"
  rm -rf "$tmp"
  # Symlink binaries into ~/.local/bin so they're on PATH.
  mkdir -p "$HOME/.local/bin"
  local extracted
  extracted="$(find "$HOME/.local" -maxdepth 1 -type d -name 'nvim-*' | head -n1)"
  [[ -n "$extracted" ]] || return 1
  ln -sf "$extracted/bin/nvim" "$HOME/.local/bin/nvim"
}

_neovim_install_source() {
  local deps
  case "$DISTRO_FAMILY" in
    debian) deps="ninja-build gettext cmake unzip curl build-essential" ;;
    rhel)   deps="ninja-build gettext cmake unzip curl" ;;
    arch)   deps="ninja gettext cmake unzip curl base-devel" ;;
    macos)  brew install ninja libtool automake cmake pkg-config gettext curl; deps="" ;;
  esac
  # Intentional word-splitting so each package becomes a separate argument.
  # shellcheck disable=SC2086
  [[ -n "$deps" ]] && pkg_install_system $deps
  local src
  src="$(mktemp -d)/neovim"
  git clone --depth 1 --branch stable https://github.com/neovim/neovim.git "$src"
  (
    cd "$src" || exit 1
    make CMAKE_BUILD_TYPE=RelWithDebInfo
    sudo_run make install
  )
  rm -rf "$(dirname "$src")"
}
