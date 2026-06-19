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

@test "ensure_local_override_stubs creates files if missing" {
  HOME="$(mktemp -d)"
  ensure_local_override_stubs
  [ -f "$HOME/.zshrc.local" ]
  [ -f "$HOME/.gitconfig.work" ]
  [ -f "$HOME/.gitconfig.personal" ]
  rm -rf "$HOME"
}

@test "ensure_local_override_stubs does not overwrite existing files" {
  HOME="$(mktemp -d)"
  echo "existing" > "$HOME/.zshrc.local"
  ensure_local_override_stubs
  run cat "$HOME/.zshrc.local"
  assert_output "existing"
  rm -rf "$HOME"
}
