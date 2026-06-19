# shellcheck shell=bash
# Installer: Rust toolchain via rustup. User-local install to $HOME/.cargo.

rust_check() {
  command -v cargo >/dev/null 2>&1 || [[ -x "$HOME/.cargo/bin/cargo" ]]
}

rust_install() {
  log "Installing Rust via rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path
  # shellcheck disable=SC1091
  [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
  success "rust installed"
}
