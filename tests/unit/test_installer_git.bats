#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer git.sh
}

@test "git_check returns 0 when git is on PATH" {
  run git_check
  assert_success
}

@test "git_check returns 1 when git not on PATH" {
  PATH=/tmp/empty run git_check
  assert_failure
}
