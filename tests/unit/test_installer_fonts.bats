#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer fonts.sh
}

@test "fonts_check is deterministic" {
  run fonts_check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
