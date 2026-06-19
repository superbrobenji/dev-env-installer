#!/usr/bin/env bash
# Entry point. Orchestrates platform detection, sudo probe, and per-tool install.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/core.sh
source "$SCRIPT_DIR/lib/core.sh"
# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/network.sh
source "$SCRIPT_DIR/lib/network.sh"
# shellcheck source=lib/sudo.sh
source "$SCRIPT_DIR/lib/sudo.sh"
# shellcheck source=lib/github.sh
source "$SCRIPT_DIR/lib/github.sh"
# shellcheck source=lib/pkg/names.sh
source "$SCRIPT_DIR/lib/pkg/names.sh"

# Defaults
DRY_RUN=false
NO_SUDO=false
SKIP_FONTS=false
SKIP_CHSH=false
SKIP_DOTFILES=false
ONLY=""
SKIP=""
VERBOSE=false
YES=0

usage() {
  cat <<'EOF'
Usage: install.sh [FLAGS]

  -n, --dry-run         Show what would happen, change nothing
      --no-sudo         Force user-local mode; skip pkgs needing sudo
      --skip-fonts      Skip font install
      --skip-chsh       Don't change default shell to zsh
      --skip-dotfiles   Install deps only; don't touch dotfiles
      --only TOOL[,...] Install only listed tools
      --skip TOOL[,...] Skip listed tools
      --verbose         Tee all log output to stdout (default: high-level only)
      --yes             Accept all defaults; no interactive prompts
  -h, --help            Show help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run)     DRY_RUN=true ;;
      --no-sudo)        NO_SUDO=true ;;
      --skip-fonts)     SKIP_FONTS=true ;;
      --skip-chsh)      SKIP_CHSH=true ;;
      --skip-dotfiles)  SKIP_DOTFILES=true ;;
      --only)
        [[ $# -ge 2 ]] || { error "--only requires a value"; exit 1; }
        ONLY="$2"; shift ;;
      --skip)
        [[ $# -ge 2 ]] || { error "--skip requires a value"; exit 1; }
        SKIP="$2"; shift ;;
      --verbose)        VERBOSE=true ;;
      --yes)            YES=1 ;;
      -h|--help)        usage; exit 0 ;;
      *)                error "Unknown arg: $1"; usage; exit 1 ;;
    esac
    shift
  done
  export DRY_RUN NO_SUDO SKIP_FONTS SKIP_CHSH SKIP_DOTFILES ONLY SKIP VERBOSE YES
}

TOOL_ORDER=(
  basics
  git
  build_toolchain
  python3
  zsh
  ohmyzsh
  tmux
  fzf
  ripgrep
  nvm
  node
  tree_sitter_cli
  go
  rust
  kitty
  neovim
  clipboard
  fonts
)

FATAL_TOOLS=(basics git build_toolchain)

INSTALLED=()
SKIPPED=()
FAILED=()

load_installers() {
  for f in "$SCRIPT_DIR/installers/"*.sh; do
    # shellcheck source=/dev/null
    source "$f"
  done
}

load_adapter() {
  case "$DISTRO_FAMILY" in
    debian)
      # shellcheck source=lib/pkg/apt.sh
      source "$SCRIPT_DIR/lib/pkg/apt.sh"
      ;;
    rhel)
      # shellcheck source=lib/pkg/dnf.sh
      source "$SCRIPT_DIR/lib/pkg/dnf.sh"
      ;;
    arch)
      # shellcheck source=lib/pkg/pacman.sh
      source "$SCRIPT_DIR/lib/pkg/pacman.sh"
      ;;
    macos)
      # shellcheck source=lib/pkg/brew.sh
      source "$SCRIPT_DIR/lib/pkg/brew.sh"
      ensure_brew
      ;;
    *)
      error "Unsupported distro family: $DISTRO_FAMILY"
      exit 1
      ;;
  esac
}

should_skip() {
  local tool="$1"
  if [[ -n "$ONLY" ]] && [[ ",$ONLY," != *",$tool,"* ]]; then return 0; fi
  if [[ -n "$SKIP" ]] && [[ ",$SKIP," == *",$tool,"* ]]; then return 0; fi
  if [[ "$SKIP_FONTS" == "true" && "$tool" == "fonts" ]]; then return 0; fi
  return 1
}

run_tool() {
  local tool="$1"
  local check_fn="${tool}_check"
  local install_fn="${tool}_install"
  if should_skip "$tool"; then
    info "Skipping $tool (filtered)"
    SKIPPED+=("$tool")
    return 0
  fi
  if "$check_fn" 2>/dev/null; then
    success "$tool already installed"
    SKIPPED+=("$tool")
    return 0
  fi
  if is_dry_run; then
    info "[dry-run] would install $tool"
    return 0
  fi
  if "$install_fn"; then
    INSTALLED+=("$tool")
  else
    error "$tool install failed"
    FAILED+=("$tool")
    if printf '%s\n' "${FATAL_TOOLS[@]}" | grep -qxF "$tool"; then
      error "Fatal tool failed; aborting"
      exit 1
    fi
  fi
}

run_chsh() {
  if [[ "$SKIP_CHSH" == "true" ]]; then return 0; fi
  local zsh_path=""
  zsh_path="$(command -v zsh || true)"
  if [[ -z "$zsh_path" ]]; then
    warn "zsh not found; skipping chsh"
    return 0
  fi
  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    info "Default shell already zsh"
    return 0
  fi
  log "Changing default shell to $zsh_path"
  chsh -s "$zsh_path" || warn "chsh failed; change manually"
}

post_install() {
  run_chsh
}

print_summary() {
  local n_installed="${#INSTALLED[@]}"
  local n_skipped="${#SKIPPED[@]}"
  local n_failed="${#FAILED[@]}"
  printf '\n─────────────────────────────────────────\n'
  printf '✅ %d installed, %d skipped, %d failed\n' \
    "$n_installed" "$n_skipped" "$n_failed"
  if [[ "$n_failed" -gt 0 ]]; then
    printf '   Failed: %s\n' "${FAILED[*]}"
  fi
  printf '📋 Next steps:\n'
  # shellcheck disable=SC2016  # literal backticks are intentional here
  printf '   • Restart shell or `exec zsh`\n'
  printf '   • Edit ~/.zshrc.local for work-specific exports\n'
  printf '   • Open nvim — Mason auto-installs LSPs on first launch\n'
}

main() {
  parse_args "$@"
  : > "$CORE_LOG_FILE" 2>/dev/null || true
  info "🔧 Dev Env Installer starting"
  info "📝 Log: $CORE_LOG_FILE"
  detect_platform
  info "🔍 Detected: $OS $ARCH / $DISTRO ($DISTRO_FAMILY) / display=$DISPLAY_SRV"
  load_adapter
  load_installers
  check_network
  probe_sudo
  pkg_update_index || warn "Package index refresh failed; continuing"
  info "Beginning install"
  local i=0
  local total="${#TOOL_ORDER[@]}"
  for tool in "${TOOL_ORDER[@]}"; do
    i=$((i+1))
    log "[$i/$total] $tool"
    run_tool "$tool"
  done
  if [[ "$SKIP_DOTFILES" != "true" ]]; then
    if is_dry_run; then
      info "[dry-run] would clone+checkout dotfiles + nvim config"
    else
      # shellcheck source=dotfiles.sh
      source "$SCRIPT_DIR/dotfiles.sh"
      run_dotfiles
    fi
  fi
  post_install
  print_summary
  if [[ "${#FAILED[@]}" -gt 0 ]]; then exit 2; fi
}

main "$@"
