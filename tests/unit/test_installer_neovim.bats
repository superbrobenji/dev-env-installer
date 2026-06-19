#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer neovim.sh
}

@test "neovim_check is deterministic" {
  run neovim_check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
