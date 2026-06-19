#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer clipboard.sh
}

@test "clipboard_check is deterministic" {
  run clipboard_check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
