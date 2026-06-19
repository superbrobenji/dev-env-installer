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

@test "_claude_merge_settings creates settings.json on fresh machine" {
  HOME="$(mktemp -d)"
  run _claude_merge_settings
  assert_success
  [ -f "$HOME/.claude/settings.json" ]
  run grep '"model"' "$HOME/.claude/settings.json"
  assert_success
  run grep 'claude-opus-4-7' "$HOME/.claude/settings.json"
  assert_success
  run grep 'caveman@caveman' "$HOME/.claude/settings.json"
  assert_success
  run grep 'superpowers-marketplace' "$HOME/.claude/settings.json"
  assert_success
  rm -rf "$HOME"
}

@test "_claude_merge_settings preserves existing keys like statusLine" {
  HOME="$(mktemp -d)"
  mkdir -p "$HOME/.claude"
  printf '{"statusLine":{"type":"command","command":"/some/path"},"model":"old-model"}\n' \
    > "$HOME/.claude/settings.json"
  run _claude_merge_settings
  assert_success
  run grep 'statusLine' "$HOME/.claude/settings.json"
  assert_success
  run grep '/some/path' "$HOME/.claude/settings.json"
  assert_success
  run grep 'claude-opus-4-7' "$HOME/.claude/settings.json"
  assert_success
  rm -rf "$HOME"
}

@test "_claude_merge_settings merges existing enabledPlugins" {
  HOME="$(mktemp -d)"
  mkdir -p "$HOME/.claude"
  printf '{"enabledPlugins":{"my-custom-plugin@my-marketplace":true}}\n' \
    > "$HOME/.claude/settings.json"
  run _claude_merge_settings
  assert_success
  run grep 'my-custom-plugin' "$HOME/.claude/settings.json"
  assert_success
  run grep 'caveman@caveman' "$HOME/.claude/settings.json"
  assert_success
  rm -rf "$HOME"
}

@test "_claude_merge_settings is idempotent" {
  HOME="$(mktemp -d)"
  _claude_merge_settings
  local first_content
  first_content="$(cat "$HOME/.claude/settings.json")"
  run _claude_merge_settings
  assert_success
  [ "$(cat "$HOME/.claude/settings.json")" = "$first_content" ]
  rm -rf "$HOME"
}
