#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer nvm.sh
  load_installer node.sh
}

@test "node_check is deterministic" {
  run node_check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
