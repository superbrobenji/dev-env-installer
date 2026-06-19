#!/usr/bin/env bats

load helpers

@test "bats harness works" {
  run echo "ok"
  assert_success
  assert_output "ok"
}
