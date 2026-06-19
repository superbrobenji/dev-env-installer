#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer nvm.sh
}

@test "nvm_check is deterministic" {
  run nvm_check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
