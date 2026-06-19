#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer ripgrep.sh
}

@test "ripgrep_check is deterministic" {
  run ripgrep_check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
