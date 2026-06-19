#!/usr/bin/env bash
# Bootstrap entry: `curl -fsSL <url> | bash`. Clones repo and executes install.sh.

set -Eeuo pipefail

REPO_URL="${BOOTSTRAP_REPO_URL:-https://github.com/superbrobenji/dev-env-installer.git}"
DEST_DIR="${BOOTSTRAP_DEST_DIR:-$HOME/.dev-env-installer}"
BRANCH="${BOOTSTRAP_BRANCH:-main}"

err() { printf '❌ %s\n' "$*" >&2; }
log() { printf '🔹 %s\n' "$*"; }

require() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing $1 — please install it first"; exit 1; }
}

require git
require curl

if [[ -d "$DEST_DIR/.git" ]]; then
  log "Updating $DEST_DIR"
  git -C "$DEST_DIR" fetch --quiet origin
  git -C "$DEST_DIR" reset --hard "origin/$BRANCH"
else
  log "Cloning $REPO_URL → $DEST_DIR"
  rm -rf "$DEST_DIR"
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$DEST_DIR"
fi

exec bash "$DEST_DIR/install.sh" "$@"
