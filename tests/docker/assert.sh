#!/usr/bin/env bash
# Runs inside container after install.sh. Asserts post-conditions.

set -Eeuo pipefail

fail=0
check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "✓ $1"
  else
    echo "✗ $1 missing"
    fail=1
  fi
}

for c in git rg fzf zsh tmux node go cargo; do check_cmd "$c"; done

if [[ ! -x "$HOME/.local/bin/nvim" ]] && ! command -v nvim >/dev/null 2>&1; then
  echo "✗ nvim missing"
  fail=1
else
  echo "✓ nvim"
fi

if [[ ! -d "$HOME/.dotfiles/.git" ]]; then
  echo "✗ ~/.dotfiles missing"
  fail=1
else
  echo "✓ ~/.dotfiles"
fi

if [[ ! -f "$HOME/.config/nvim/init.lua" ]]; then
  echo "✗ nvim init.lua missing"
  fail=1
else
  echo "✓ nvim/init.lua"
fi

exit "$fail"
