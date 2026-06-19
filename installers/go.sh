# shellcheck shell=bash
# Installer: Go. User-local install to $HOME/.local/go.

GO_LOCAL_ROOT="$HOME/.local/go"

go_check() {
  command -v go >/dev/null 2>&1 || [[ -x "$GO_LOCAL_ROOT/bin/go" ]]
}

go_install() {
  log "Installing Go"
  local os_name arch_name latest url tmp
  case "$OS" in
    macos) os_name=darwin ;;
    linux) os_name=linux ;;
  esac
  case "$ARCH" in
    x86_64) arch_name=amd64 ;;
    arm64)  arch_name=arm64 ;;
  esac
  latest="$(curl -fsSL https://go.dev/VERSION?m=text | head -n1)"
  url="https://go.dev/dl/${latest}.${os_name}-${arch_name}.tar.gz"
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/go.tar.gz"
  rm -rf "$GO_LOCAL_ROOT"
  mkdir -p "$(dirname "$GO_LOCAL_ROOT")"
  tar -C "$(dirname "$GO_LOCAL_ROOT")" -xzf "$tmp/go.tar.gz"
  rm -rf "$tmp"
  success "go installed to $GO_LOCAL_ROOT"
}
