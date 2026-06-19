#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer claude.sh
}

@test "claude_check returns 0 when claude is on PATH" {
  FAKE_BIN="$(mktemp -d)"
  touch "$FAKE_BIN/claude" && chmod +x "$FAKE_BIN/claude"
  PATH="$FAKE_BIN:$PATH" run claude_check
  assert_success
  rm -rf "$FAKE_BIN"
}

@test "claude_check returns 1 when claude not on PATH" {
  PATH=/tmp/empty_nonexistent run claude_check
  assert_failure
}
