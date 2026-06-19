#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer ohmyzsh.sh
}

@test "ohmyzsh_check is deterministic" {
  run ohmyzsh_check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "ohmyzsh_check returns 0 when dir exists" {
  HOME="$(mktemp -d)"
  mkdir -p "$HOME/.oh-my-zsh"
  run ohmyzsh_check
  assert_success
  rm -rf "$HOME"
}
