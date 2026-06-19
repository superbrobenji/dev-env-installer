#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_lib sudo.sh
  SUDO_MODE=full
  source "${PROJECT_ROOT}/lib/pkg/pacman.sh"
  CAPTURED="$(mktemp)"
  sudo_run() { printf '%s\n' "$*" >> "$CAPTURED"; }
  export -f sudo_run
}

teardown() { rm -f "$CAPTURED"; }

@test "pkg_install_system uses pacman -S --noconfirm --needed" {
  pkg_install_system git
  run cat "$CAPTURED"
  assert_output --partial "pacman -S --noconfirm --needed git"
}

@test "pkg_update_index uses pacman -Sy" {
  pkg_update_index
  run cat "$CAPTURED"
  assert_output --partial "pacman -Sy"
}
