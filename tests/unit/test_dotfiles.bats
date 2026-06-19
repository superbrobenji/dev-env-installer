#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  source "${PROJECT_ROOT}/dotfiles.sh"
}

@test "default_branch resolves origin/HEAD" {
  local tmp
  tmp="$(mktemp -d)"
  ( cd "$tmp" && git init -q --bare remote.git )
  ( cd "$tmp" && git clone -q remote.git work )
  ( cd "$tmp/work" \
    && git config user.email t@t \
    && git config user.name t \
    && git commit --allow-empty -qm init \
    && git push -q origin master 2>/dev/null || git push -q origin main 2>/dev/null )
  ( cd "$tmp/work" && git remote set-head origin -a >/dev/null )
  run default_branch "$tmp/work"
  assert_success
  [[ "$output" =~ ^(main|master)$ ]]
  rm -rf "$tmp"
}

@test "_is_local_override returns 0 for .gitconfig-work" {
  run _is_local_override ".gitconfig-work"
  assert_success
}

@test "_is_local_override returns 0 for .gitconfig-personal" {
  run _is_local_override ".gitconfig-personal"
  assert_success
}

@test "_is_local_override returns 0 for .ssh/id_rsa" {
  run _is_local_override ".ssh/id_rsa"
  assert_success
}

@test "_is_local_override returns 0 for .ssh/id_ed25519" {
  run _is_local_override ".ssh/id_ed25519"
  assert_success
}

@test "_is_local_override returns 0 for .ssh/known_hosts" {
  run _is_local_override ".ssh/known_hosts"
  assert_success
}

@test "_is_local_override returns 1 for .zshrc" {
  run _is_local_override ".zshrc"
  assert_failure
}

@test "setup_ssh_dir creates ~/.ssh with perms 700" {
  HOME="$(mktemp -d)"
  setup_ssh_dir
  [ -d "$HOME/.ssh" ]
  local perms
  perms="$(stat -f "%Lp" "$HOME/.ssh" 2>/dev/null || stat -c "%a" "$HOME/.ssh")"
  [ "$perms" = "700" ]
  rm -rf "$HOME"
}

@test "setup_ssh_dir is idempotent when dir exists" {
  HOME="$(mktemp -d)"
  mkdir -p "$HOME/.ssh"
  chmod 755 "$HOME/.ssh"
  setup_ssh_dir
  local perms
  perms="$(stat -f "%Lp" "$HOME/.ssh" 2>/dev/null || stat -c "%a" "$HOME/.ssh")"
  [ "$perms" = "700" ]
  rm -rf "$HOME"
}

@test "fix_ssh_permissions sets 600 on ~/.ssh/config if present" {
  HOME="$(mktemp -d)"
  mkdir -p "$HOME/.ssh"
  touch "$HOME/.ssh/config"
  chmod 644 "$HOME/.ssh/config"
  fix_ssh_permissions
  local perms
  perms="$(stat -f "%Lp" "$HOME/.ssh/config" 2>/dev/null || stat -c "%a" "$HOME/.ssh/config")"
  [ "$perms" = "600" ]
  rm -rf "$HOME"
}

@test "fix_ssh_permissions is no-op when config absent" {
  HOME="$(mktemp -d)"
  mkdir -p "$HOME/.ssh"
  run fix_ssh_permissions
  assert_success
  rm -rf "$HOME"
}

@test "setup_gitconfig_overrides writes both config files from templates" {
  HOME="$(mktemp -d)"
  DOTFILES_DIR="$(mktemp -d)"
  printf '[user]\n\temail = [PERSONAL EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-personal.template"
  printf '[user]\n\temail = [WORK EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-work.template"
  YES=1 setup_gitconfig_overrides
  [ -f "$HOME/.gitconfig-personal" ]
  [ -f "$HOME/.gitconfig-work" ]
  rm -rf "$HOME" "$DOTFILES_DIR"
}

@test "setup_gitconfig_overrides leaves placeholders when YES=1" {
  HOME="$(mktemp -d)"
  DOTFILES_DIR="$(mktemp -d)"
  printf '[user]\n\temail = [PERSONAL EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-personal.template"
  printf '[user]\n\temail = [WORK EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-work.template"
  YES=1 setup_gitconfig_overrides
  run grep '\[PERSONAL EMAIL\]' "$HOME/.gitconfig-personal"
  assert_success
  run grep '\[WORK EMAIL\]' "$HOME/.gitconfig-work"
  assert_success
  rm -rf "$HOME" "$DOTFILES_DIR"
}

@test "setup_gitconfig_overrides substitutes emails interactively" {
  HOME="$(mktemp -d)"
  DOTFILES_DIR="$(mktemp -d)"
  printf '[user]\n\temail = [PERSONAL EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-personal.template"
  printf '[user]\n\temail = [WORK EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-work.template"
  printf 'personal@example.com\nwork@corp.com\n' | setup_gitconfig_overrides
  run grep 'personal@example.com' "$HOME/.gitconfig-personal"
  assert_success
  run grep 'work@corp.com' "$HOME/.gitconfig-work"
  assert_success
  rm -rf "$HOME" "$DOTFILES_DIR"
}

@test "setup_gitconfig_overrides is idempotent when files exist" {
  HOME="$(mktemp -d)"
  DOTFILES_DIR="$(mktemp -d)"
  printf '[user]\n\temail = [PERSONAL EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-personal.template"
  printf '[user]\n\temail = [WORK EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-work.template"
  echo "existing personal" > "$HOME/.gitconfig-personal"
  echo "existing work" > "$HOME/.gitconfig-work"
  YES=1 setup_gitconfig_overrides
  run cat "$HOME/.gitconfig-personal"
  assert_output "existing personal"
  run cat "$HOME/.gitconfig-work"
  assert_output "existing work"
  rm -rf "$HOME" "$DOTFILES_DIR"
}

@test "ensure_zshrc_local_stub creates .zshrc.local if missing" {
  HOME="$(mktemp -d)"
  ensure_zshrc_local_stub
  [ -f "$HOME/.zshrc.local" ]
  rm -rf "$HOME"
}

@test "ensure_zshrc_local_stub does not overwrite existing .zshrc.local" {
  HOME="$(mktemp -d)"
  echo "existing" > "$HOME/.zshrc.local"
  ensure_zshrc_local_stub
  run cat "$HOME/.zshrc.local"
  assert_output "existing"
  rm -rf "$HOME"
}
