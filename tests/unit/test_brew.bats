#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_lib sudo.sh
  SUDO_MODE=userlocal
  source "${PROJECT_ROOT}/lib/pkg/brew.sh"
  CAPTURED="$(mktemp)"
  brew() { printf 'brew %s\n' "$*" >> "$CAPTURED"; }
  export -f brew
}

teardown() { rm -f "$CAPTURED"; }

@test "pkg_install_system uses brew install" {
  pkg_install_system git
  run cat "$CAPTURED"
  assert_output --partial "brew install git"
}

@test "pkg_install_cask uses brew install --cask" {
  pkg_install_cask kitty
  run cat "$CAPTURED"
  assert_output --partial "brew install --cask kitty"
}

@test "pkg_update_index is a no-op" {
  run pkg_update_index
  assert_success
}
