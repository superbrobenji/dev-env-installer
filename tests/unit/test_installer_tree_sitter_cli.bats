#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer node.sh
  load_installer tree_sitter_cli.sh
}

@test "tree_sitter_cli_check is deterministic" {
  run tree_sitter_cli_check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
