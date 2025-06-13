#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------
# Configuration
# ----------------------------------------

DEPENDENCIES=(
  git
  nvm
  node
  kitty
  nvim
  grep
  rg
  zsh
  tmux
  fzf
  ohmyzsh
)

# Will be set during OS detection
OS=""
PKG_INSTALL=""
PKG_CHECK=""

# ----------------------------------------
# Utility Functions
# ----------------------------------------

log()    { echo -e "🔹 $1"; }
info()   { echo -e "ℹ️  $1"; }
success(){ echo -e "✅ $1"; }
error()  { echo -e "❌ $1" >&2; }

# ----------------------------------------
# OS Detection
# ----------------------------------------

detect_operating_system() {
  log "Detecting operating system..."

  case "$OSTYPE" in
    linux-gnu*)
      OS="linux"
      PKG_INSTALL="sudo apt-get install -y"
      PKG_CHECK="dpkg -s"
      ;;
    darwin*)
      OS="macos"
      PKG_INSTALL="brew install"
      PKG_CHECK="brew list"
      DEPENDENCIES=("brew" "${DEPENDENCIES[@]}")
      ;;
    *)
      error "Unsupported OS: $OSTYPE"
      exit 1
      ;;
  esac

  success "Detected OS: $OS"
}

# ----------------------------------------
# Dependency Checking
# ----------------------------------------

is_dependency_installed() {
  local dep="$1"

  case "$dep" in
    kitty)
      command -v kitty &>/dev/null ||
      [[ -x "/Applications/kitty.app/Contents/MacOS/kitty" ]] ||
      [[ -x "$HOME/.local/kitty.app/bin/kitty" ]] ||
      [[ -x "$HOME/.local/bin/kitty" ]]
      ;;

    nvm)
      command -v nvm &>/dev/null || [[ -s "$HOME/.nvm/nvm.sh" ]]
      ;;

    ohmyzsh)
      [[ -d "$HOME/.oh-my-zsh" ]]
      ;;

    fzf)
      command -v fzf &>/dev/null || [[ -d "$HOME/.fzf" ]]
      ;;

    *)
      if [[ "$OS" == "macos" ]]; then
        [[ "$dep" == "brew" ]] && command -v brew &>/dev/null && return 0
        brew list --formula | grep -qx "$dep" ||
        brew list --cask | grep -qx "$dep" ||
        command -v "$dep" &>/dev/null
      else
        $PKG_CHECK "$dep" &>/dev/null || command -v "$dep" &>/dev/null
      fi
      ;;
  esac
}

# ----------------------------------------
# Generic Install Fallback
# ----------------------------------------

install_with_package_manager() {
  local dep="$1"
  log "Installing $dep via package manager..."
  $PKG_INSTALL "$dep"
  success "$dep installed."
}

# ----------------------------------------
# Custom Install Functions
# ----------------------------------------

install_brew() {
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv || true)"
  success "Homebrew installed."
}

install_fzf() {
  log "Installing fzf..."
  if [[ "$OS" == "macos" ]]; then
    brew install fzf
  else
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all
  fi
  success "fzf installed."
}

install_rg() {
  log "Installing ripgrep..."
  if ! $PKG_INSTALL ripgrep; then
    info "ripgrep not found in package manager. Falling back to GitHub release..."
    local url tmpfile
    url=$(curl -s https://api.github.com/repos/BurntSushi/ripgrep/releases/latest |
      grep "browser_download_url.*amd64.deb" |
      cut -d '"' -f 4 | head -n 1)

    [[ -z "$url" ]] && error "Could not find ripgrep binary URL" && return 1

    tmpfile=$(mktemp)
    curl -L "$url" -o "$tmpfile"
    sudo dpkg -i "$tmpfile"
    rm -f "$tmpfile"
  fi
  success "ripgrep installed."
}

install_nvm() {
  log "Installing nvm..."
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
  success "nvm installed."
}

install_node() {
  log "Installing Node.js..."
  export NVM_DIR="$HOME/.nvm"
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
  nvm install --lts
  success "Node.js installed."
}

install_kitty() {
  log "Installing kitty..."
  curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n
  export PATH="$HOME/.local/kitty.app/bin:$HOME/.local/bin:$PATH"
  success "kitty installed."
}

install_nvim() {
  log "Building and installing Neovim from source..."
  if [[ "$OS" == "macos" ]]; then
    brew install ninja libtool automake cmake pkg-config gettext curl
  else
    $PKG_INSTALL ninja-build gettext cmake unzip curl build-essential
  fi

  git clone https://github.com/neovim/neovim.git /tmp/neovim-src
  cd /tmp/neovim-src
  git checkout stable
  make CMAKE_BUILD_TYPE=RelWithDebInfo
  sudo make install
  cd -
  rm -rf /tmp/neovim-src
  success "Neovim installed."
}

install_ohmyzsh() {
  log "Installing oh-my-zsh..."
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "oh-my-zsh installed."
}

# ----------------------------------------
# Install Dispatcher
# ----------------------------------------

install_dependency() {
  local dep="$1"
  local install_fn="install_${dep}"

  if declare -f "$install_fn" &>/dev/null; then
    $install_fn
  else
    install_with_package_manager "$dep"
  fi
}

# ----------------------------------------
# Dependency Check + Install
# ----------------------------------------

process_dependencies() {
  local missing=()

  for dep in "${DEPENDENCIES[@]}"; do
    if is_dependency_installed "$dep"; then
      success "$dep is already installed."
    else
      error "$dep is missing."
      missing+=("$dep")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    success "All dependencies are already installed."
  else
    log "Installing missing dependencies..."
    for dep in "${missing[@]}"; do
      install_dependency "$dep"
    done
    success "All missing dependencies have been installed."
  fi
}

# ----------------------------------------
# Main Entry
# ----------------------------------------

main() {
  detect_operating_system
  process_dependencies
}

main "$@"
