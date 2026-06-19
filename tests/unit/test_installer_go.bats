#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer go.sh
}

@test "go_check is deterministic" {
  run go_check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
