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

_make_fake_claude_marketplace() {
  local list_output="$1"
  local call_log="$FAKE_BIN/marketplace_calls.log"
  cat > "$FAKE_BIN/claude" << SCRIPT
#!/usr/bin/env bash
case "\$*" in
  "plugin marketplace list") printf '%s\n' '$list_output' ;;
  plugin\ marketplace\ add\ *) echo "\$*" >> '$call_log' ;;
  *) true ;;
esac
SCRIPT
  chmod +x "$FAKE_BIN/claude"
}

@test "_claude_add_marketplaces adds both when neither present" {
  FAKE_BIN="$(mktemp -d)"
  _make_fake_claude_marketplace "claude-plugins-official"
  PATH="$FAKE_BIN:$PATH"
  run _claude_add_marketplaces
  assert_success
  run grep "superpowers-marketplace" "$FAKE_BIN/marketplace_calls.log"
  assert_success
  run grep "caveman" "$FAKE_BIN/marketplace_calls.log"
  assert_success
  rm -rf "$FAKE_BIN"
}

@test "_claude_add_marketplaces skips when both already present" {
  FAKE_BIN="$(mktemp -d)"
  _make_fake_claude_marketplace "superpowers-marketplace
caveman"
  PATH="$FAKE_BIN:$PATH"
  run _claude_add_marketplaces
  assert_success
  [ ! -f "$FAKE_BIN/marketplace_calls.log" ]
  rm -rf "$FAKE_BIN"
}

@test "_claude_add_marketplaces adds only missing marketplace" {
  FAKE_BIN="$(mktemp -d)"
  _make_fake_claude_marketplace "superpowers-marketplace"
  PATH="$FAKE_BIN:$PATH"
  run _claude_add_marketplaces
  assert_success
  run grep "caveman" "$FAKE_BIN/marketplace_calls.log"
  assert_success
  run grep "superpowers-marketplace" "$FAKE_BIN/marketplace_calls.log"
  assert_failure
  rm -rf "$FAKE_BIN"
}

_make_fake_claude_plugins() {
  local list_output="$1"
  local call_log="$FAKE_BIN/plugin_install_calls.log"
  cat > "$FAKE_BIN/claude" << SCRIPT
#!/usr/bin/env bash
case "\$*" in
  "plugin list") printf '%s\n' '$list_output' ;;
  plugin\ install\ *) echo "\$*" >> '$call_log' ;;
  *) true ;;
esac
SCRIPT
  chmod +x "$FAKE_BIN/claude"
}

@test "_claude_install_plugins installs all when none present" {
  FAKE_BIN="$(mktemp -d)"
  _make_fake_claude_plugins ""
  PATH="$FAKE_BIN:$PATH"
  run _claude_install_plugins
  assert_success
  run grep "typescript-lsp@claude-plugins-official" "$FAKE_BIN/plugin_install_calls.log"
  assert_success
  run grep "superpowers@claude-plugins-official" "$FAKE_BIN/plugin_install_calls.log"
  assert_success
  run grep "superpowers@superpowers-marketplace" "$FAKE_BIN/plugin_install_calls.log"
  assert_success
  run grep "caveman@caveman" "$FAKE_BIN/plugin_install_calls.log"
  assert_success
  run grep "lua-lsp@claude-plugins-official" "$FAKE_BIN/plugin_install_calls.log"
  assert_success
  run grep "pyright-lsp@claude-plugins-official" "$FAKE_BIN/plugin_install_calls.log"
  assert_success
  rm -rf "$FAKE_BIN"
}

@test "_claude_install_plugins skips already-installed plugins" {
  FAKE_BIN="$(mktemp -d)"
  _make_fake_claude_plugins "  ❯ typescript-lsp@claude-plugins-official
  ❯ superpowers@claude-plugins-official
  ❯ superpowers@superpowers-marketplace
  ❯ caveman@caveman
  ❯ lua-lsp@claude-plugins-official
  ❯ pyright-lsp@claude-plugins-official"
  PATH="$FAKE_BIN:$PATH"
  run _claude_install_plugins
  assert_success
  [ ! -f "$FAKE_BIN/plugin_install_calls.log" ]
  rm -rf "$FAKE_BIN"
}

@test "_claude_install_plugins installs only missing plugins" {
  FAKE_BIN="$(mktemp -d)"
  _make_fake_claude_plugins "  ❯ typescript-lsp@claude-plugins-official
  ❯ caveman@caveman"
  PATH="$FAKE_BIN:$PATH"
  run _claude_install_plugins
  assert_success
  run grep "typescript-lsp@claude-plugins-official" "$FAKE_BIN/plugin_install_calls.log"
  assert_failure
  run grep "caveman@caveman" "$FAKE_BIN/plugin_install_calls.log"
  assert_failure
  run grep "superpowers@claude-plugins-official" "$FAKE_BIN/plugin_install_calls.log"
  assert_success
  rm -rf "$FAKE_BIN"
}
