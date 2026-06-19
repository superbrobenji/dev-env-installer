#!/usr/bin/env bash
# Dotfiles + nvim config sync. Source from install.sh.

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/superbrobenji/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
NVIM_REPO="${NVIM_REPO:-https://github.com/superbrobenji/nvim.git}"
NVIM_DIR="${NVIM_DIR:-$HOME/.config/nvim}"

default_branch() {
  local dir="$1"
  git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
    | sed 's|^origin/||'
}

# Refuse to operate if the existing .dotfiles dir isn't owned by $USER.
verify_dotfiles_ownership() {
  [[ -e "$DOTFILES_DIR" ]] || return 0
  local owner
  owner="$(stat -f '%Su' "$DOTFILES_DIR" 2>/dev/null || stat -c '%U' "$DOTFILES_DIR")"
  if [[ "$owner" != "$USER" ]]; then
    warn "$DOTFILES_DIR is owned by $owner, not $USER"
    if needs_sudo; then
      info "Fixing ownership"
      sudo_run chown -R "$USER:$(id -gn)" "$DOTFILES_DIR"
    else
      error "Run with sudo to fix, or remove $DOTFILES_DIR manually"
      return 1
    fi
  fi
}

clone_or_update_repo() {
  local repo="$1" dir="$2"
  if [[ ! -d "$dir/.git" ]]; then
    log "Cloning $repo → $dir"
    rm -rf "$dir"
    git clone --depth=1 "$repo" "$dir"
  else
    log "Updating $dir"
    git -C "$dir" fetch --all --quiet
    local branch
    branch="$(default_branch "$dir")"
    [[ -n "$branch" ]] || branch="main"
    git -C "$dir" reset --hard "origin/$branch"
  fi
}

# Bare-repo checkout helper: works with $DOTFILES_DIR as the git dir and $HOME as worktree.
# For now we keep the conventional clone-into-$HOME approach but back up conflicts first.
checkout_dotfiles() {
  local tracked file backup_dir _git_files
  backup_dir="$HOME/.dotfiles-backup-$(date +%s)"
  tracked=()
  _git_files="$(git -C "$DOTFILES_DIR" ls-tree -r HEAD --name-only 2>/dev/null)" \
    || { error "Failed to list files in $DOTFILES_DIR (is HEAD valid?)"; return 1; }
  if [[ -z "$_git_files" ]]; then
    warn "No files tracked in $DOTFILES_DIR — wrong branch or empty repo?"
    return 0
  fi
  while IFS= read -r _df_line; do [[ -n "$_df_line" ]] && tracked+=("$_df_line"); done <<< "$_git_files"
  for file in "${tracked[@]+"${tracked[@]}"}"; do
    if [[ -e "$HOME/$file" ]] && ! _is_local_override "$file"; then
      if ! cmp -s "$HOME/$file" "$DOTFILES_DIR/$file" 2>/dev/null; then
        mkdir -p "$(dirname "$backup_dir/$file")"
        mv "$HOME/$file" "$backup_dir/$file"
      fi
    fi
  done
  # Mirror tracked files from the repo into $HOME.
  for file in "${tracked[@]+"${tracked[@]}"}"; do
    mkdir -p "$HOME/$(dirname "$file")"
    cp -a "$DOTFILES_DIR/$file" "$HOME/$file"
  done
  if [[ -d "$backup_dir" ]]; then
    warn "Backed up conflicting files to $backup_dir"
  fi
}

_is_local_override() {
  case "$1" in
    .zshrc.local|.gitconfig-work|.gitconfig-personal) return 0 ;;
    .ssh/id_*|.ssh/known_hosts) return 0 ;;
    *) return 1 ;;
  esac
}

setup_ssh_dir() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
}

fix_ssh_permissions() {
  [[ -f "$HOME/.ssh/config" ]] && chmod 600 "$HOME/.ssh/config"
  return 0
}

setup_gitconfig_overrides() {
  local personal_email="" work_email="" content

  if [[ ! -f "$HOME/.gitconfig-personal" ]]; then
    if [[ "${YES:-0}" != "1" ]]; then
      printf "Personal email for git commits: "
      read -r personal_email
    fi
    content="$(cat "$DOTFILES_DIR/.gitconfig-personal.template")"
    [[ -n "$personal_email" ]] && content="${content//\[PERSONAL EMAIL\]/$personal_email}"
    printf '%s\n' "$content" > "$HOME/.gitconfig-personal"
    log "Written ~/.gitconfig-personal"
  fi

  if [[ ! -f "$HOME/.gitconfig-work" ]]; then
    if [[ "${YES:-0}" != "1" ]]; then
      printf "Work email for git commits: "
      read -r work_email
    fi
    content="$(cat "$DOTFILES_DIR/.gitconfig-work.template")"
    [[ -n "$work_email" ]] && content="${content//\[WORK EMAIL\]/$work_email}"
    printf '%s\n' "$content" > "$HOME/.gitconfig-work"
    log "Written ~/.gitconfig-work"
  fi
}

ensure_zshrc_local_stub() {
  if [[ ! -f "$HOME/.zshrc.local" ]]; then
    cat > "$HOME/.zshrc.local" <<'EOF'
# Machine-specific zsh overrides. Not tracked in dotfiles repo.
# Example exports:
# export AWS_PROFILE=...
# export AVANTE_ANTHROPIC_API_KEY=...
# command -v typo >/dev/null 2>&1 && eval "$(typo init zsh)"
EOF
  fi
}

run_dotfiles() {
  verify_dotfiles_ownership
  clone_or_update_repo "$DOTFILES_REPO" "$DOTFILES_DIR"
  setup_ssh_dir
  checkout_dotfiles
  fix_ssh_permissions
  setup_gitconfig_overrides
  ensure_zshrc_local_stub
  mkdir -p "$HOME/projects/work" "$HOME/projects/personal"
  clone_or_update_repo "$NVIM_REPO" "$NVIM_DIR"
  success "dotfiles + nvim config in place"
}
