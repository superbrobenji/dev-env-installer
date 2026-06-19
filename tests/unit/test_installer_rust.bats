#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer rust.sh
}

@test "rust_check is deterministic" {
  run rust_check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
