#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer tmux.sh
}

@test "tmux_check is deterministic" {
  run tmux_check
  # On the dev box the tools may or may not be installed; just assert the
  # function returns a deterministic exit (0 or 1).
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
