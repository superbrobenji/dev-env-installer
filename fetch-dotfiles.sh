#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="https://github.com/superbrobenji/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

NVIM_CONFIG_REPO="https://github.com/superbrobenji/nvim.git"
NVIM_CONFIG_DIR="$HOME/.config/nvim"

clone_or_update_dotfiles_repo() {
  if [[ ! -d "$DOTFILES_DIR" || ! -d "$DOTFILES_DIR/.git" ]]; then
    echo "🚀 Cloning dotfiles repo into $DOTFILES_DIR..."
    rm -rf "$DOTFILES_DIR"
    git clone --depth=1 "$DOTFILES_REPO" "$DOTFILES_DIR"
  else
    echo "🔄 Dotfiles repo exists. Pulling latest changes..."
    git -C "$DOTFILES_DIR" fetch --all
    git -C "$DOTFILES_DIR" reset --hard origin/main
  fi
}

checkout_dotfiles() {
  echo "🚧 Checking out dotfiles to home directory (overwriting conflicts)..."
  git --git-dir="$DOTFILES_DIR/.git" --work-tree="$HOME" checkout -f
  echo "✅ Dotfiles checked out."

  echo "🔧 Configuring git to ignore untracked files in dotfiles repo..."
  git --git-dir="$DOTFILES_DIR/.git" --work-tree="$HOME" config status.showUntrackedFiles no
}

clone_or_update_nvim_config() {
  if [[ ! -d "$NVIM_CONFIG_DIR" || ! -d "$NVIM_CONFIG_DIR/.git" ]]; then
    echo "🚀 Cloning Neovim config repo into $NVIM_CONFIG_DIR..."
    rm -rf "$NVIM_CONFIG_DIR"
    git clone --depth=1 "$NVIM_CONFIG_REPO" "$NVIM_CONFIG_DIR"
  else
    echo "🔄 Neovim config repo exists. Pulling latest changes..."
    git -C "$NVIM_CONFIG_DIR" fetch --all
    git -C "$NVIM_CONFIG_DIR" reset --hard origin/main
  fi
  echo "✅ Neovim config is up to date."
}

main() {
  clone_or_update_dotfiles_repo
  checkout_dotfiles
  clone_or_update_nvim_config
}

main "$@"
