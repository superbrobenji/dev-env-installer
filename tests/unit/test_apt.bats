#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_lib sudo.sh
  SUDO_MODE=full
  source "${PROJECT_ROOT}/lib/pkg/apt.sh"

  # Mock sudo_run to capture the command.
  CAPTURED="$(mktemp)"
  sudo_run() { printf '%s\n' "$*" >> "$CAPTURED"; }
  export -f sudo_run
}

teardown() {
  rm -f "$CAPTURED"
}

@test "pkg_install_system runs apt-get install with packages" {
  pkg_install_system curl wget
  run cat "$CAPTURED"
  assert_output --partial "apt-get install -y --no-install-recommends curl wget"
}

@test "pkg_update_index runs apt-get update" {
  pkg_update_index
  run cat "$CAPTURED"
  assert_output --partial "apt-get update"
}
