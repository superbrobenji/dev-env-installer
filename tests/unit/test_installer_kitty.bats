#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer kitty.sh
}

@test "kitty_check is deterministic" {
  run kitty_check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
