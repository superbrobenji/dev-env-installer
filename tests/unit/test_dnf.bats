#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_lib sudo.sh
  SUDO_MODE=full
  source "${PROJECT_ROOT}/lib/pkg/dnf.sh"
  CAPTURED="$(mktemp)"
  sudo_run() { printf '%s\n' "$*" >> "$CAPTURED"; }
  export -f sudo_run
}

teardown() { rm -f "$CAPTURED"; }

@test "pkg_install_system uses dnf install -y" {
  pkg_install_system git
  run cat "$CAPTURED"
  assert_output --partial "dnf install -y git"
}

@test "pkg_update_index uses dnf check-update and tolerates exit 100" {
  # Simulate dnf returning 100 (updates available — normal)
  sudo_run() { return 100; }
  export -f sudo_run
  run pkg_update_index
  assert_success
}
