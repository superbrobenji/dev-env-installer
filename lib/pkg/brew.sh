# shellcheck shell=bash
# Homebrew adapter (macOS). No sudo.

pkg_install_system() {
  brew install "$@"
}

pkg_install_cask() {
  brew install --cask "$@"
}

pkg_query() {
  brew list --formula --versions "$1" >/dev/null 2>&1 \
    || brew list --cask --versions "$1" >/dev/null 2>&1
}

pkg_update_index() {
  # Homebrew refreshes automatically on install; no-op here.
  return 0
}

ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi
  log "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Persist shellenv and load into current shell.
  local brew_bin
  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_bin=/opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_bin=/usr/local/bin/brew
  else
    error "Homebrew installed but brew binary not found"
    return 1
  fi
  eval "$("$brew_bin" shellenv)"
  if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
    # shellcheck disable=SC2016 # $(...) is literal; expanded by future shells
    printf '\neval "$(%s shellenv)"\n' "$brew_bin" >> "$HOME/.zprofile"
  fi
}
