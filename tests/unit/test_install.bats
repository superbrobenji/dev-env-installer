#!/usr/bin/env bats

load helpers

@test "install.sh --help exits 0" {
  run bash "${PROJECT_ROOT}/install.sh" --help
  assert_success
  assert_output --partial "Usage: install.sh"
}

@test "install.sh --bad-flag exits 1" {
  run bash "${PROJECT_ROOT}/install.sh" --bad-flag
  assert_failure
}
