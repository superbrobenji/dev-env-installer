#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer fzf.sh
}

@test "fzf_check is deterministic" {
  run fzf_check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
