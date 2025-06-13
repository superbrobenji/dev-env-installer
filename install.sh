#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------
# Constants
# ----------------------------------------

LOG_FILE="$HOME/.dev-env-installer.log"
DEPENDENCY_SCRIPT_URL="https://raw.githubusercontent.com/superbrobenji/dev-env-installer/main/dep-installer.sh"
DOTFILES_SCRIPT_URL="https://raw.githubusercontent.com/superbrobenji/dev-env-installer/main/fetch-dotfiles.sh"

# ----------------------------------------
# Variables
# ----------------------------------------

DRY_RUN=false

# ----------------------------------------
# Logging Functions
# ----------------------------------------

log()    { echo -e "🔹 $1" | tee -a "$LOG_FILE"; }
info()   { echo -e "ℹ️  $1" | tee -a "$LOG_FILE"; }
success(){ echo -e "✅ $1" | tee -a "$LOG_FILE"; }
error()  { echo -e "❌ $1" | tee -a "$LOG_FILE" >&2; }

# ----------------------------------------
# Parse Arguments
# ----------------------------------------

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run)
        DRY_RUN=true
        shift
        ;;
      *)
        error "Unknown argument: $1"
        exit 1
        ;;
    esac
  done
}

# ----------------------------------------
# Network Check
# ----------------------------------------

check_network_connectivity() {
  local test_urls=(
    "https://www.google.com"
    "https://github.com"
    "https://raw.githubusercontent.com"
  )

  info "Checking internet connectivity..."

  for url in "${test_urls[@]}"; do
    if curl -s --head --connect-timeout 5 "$url" | grep -q "HTTP/2 200"; then
      success "Network check passed via $url"
      return 0
    fi
  done

  error "Internet connectivity test failed. Cannot proceed with install."
  exit 1
}

# ----------------------------------------
# Run Remote Script
# ----------------------------------------

run_remote_script() {
  local script_url="$1"
  local script_name="$2"

  if [[ "$DRY_RUN" == true ]]; then
    info "[Dry Run] Would run: $script_name from $script_url"
    return 0
  fi

  info "Running: $script_name"

  if curl -fsSL "$script_url" | bash >> "$LOG_FILE" 2>&1; then
    success "$script_name completed successfully."
  else
    error "$script_name failed. Check log at $LOG_FILE"
    exit 1
  fi
}

# ----------------------------------------
# Main
# ----------------------------------------

main() {
  echo "🔧 Starting Dev Env Installer"
  echo "📝 Logging to: $LOG_FILE"
  echo "----------------------------------------" > "$LOG_FILE"
  echo "Dev Environment Installer Log - $(date)" >> "$LOG_FILE"
  echo "----------------------------------------" >> "$LOG_FILE"

  parse_args "$@"
  check_network_connectivity

  run_remote_script "$DEPENDENCY_SCRIPT_URL" "Dependency Installer"
  run_remote_script "$DOTFILES_SCRIPT_URL" "Dotfiles + Neovim Config Setup"

  success "🎉 All done! Your environment is ready."
  if [[ "$DRY_RUN" == true ]]; then
    info "Dry run completed — no changes were made."
  fi
}

main "$@"
