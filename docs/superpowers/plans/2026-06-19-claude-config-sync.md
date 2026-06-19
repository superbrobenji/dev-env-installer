# Claude Config Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Claude Code config (skills, plugins, settings) to the dev-env-installer so a fresh machine gets the same Claude environment as the primary machine.

**Architecture:** Personal skills are committed to the dotfiles repo and copied to `~/.claude/skills/` by the existing `checkout_dotfiles` mechanism. A new `installers/claude.sh` installs the Claude CLI via npm, merges portable settings into `~/.claude/settings.json` via a Python inline script, adds custom plugin marketplaces, and installs all plugins — each step idempotent.

**Tech Stack:** Bash, bats (unit tests), Python 3 (settings merge), Claude Code CLI (`claude plugin` sub-commands)

## Global Constraints

- All shell functions follow the `<tool>_check` / `<tool>_install` pattern used by every other installer in `installers/`.
- `claude_check` must return 0 if `claude` is on PATH, 1 otherwise — same as `git_check`.
- `claude` is NOT a fatal tool — a failed plugin install must not abort the full run.
- Idempotency: every sub-step must be safe to re-run.
- Python inline script uses `os.path.expanduser('~')` so it respects the `HOME` env var set in bats tests.
- Tests live in `tests/unit/test_installer_claude.bats`, follow existing bats patterns, source `helpers.bash`.
- Run `make test` after each task to confirm no regressions.

---

### Task 1: Add personal skills to the dotfiles repo

**Files:**
- Modify (external repo): `~/.dotfiles/.claude/skills/find-skills/SKILL.md` (copy from `~/.claude/skills/`)
- Modify (external repo): `~/.dotfiles/.claude/skills/task-parallelism/SKILL.md`
- Modify (external repo): `~/.dotfiles/.claude/skills/technical-design-documentation/SKILL.md`
- Modify (external repo): `~/.dotfiles/.claude/skills/technical-design-documentation/references/tdd-guide.md`
- Modify (external repo): `~/.dotfiles/.claude/skills/technical-design-documentation/references/tdd-template.md`

**Interfaces:**
- Produces: `~/.dotfiles` tracks `.claude/skills/` paths that `checkout_dotfiles` will copy on install

- [ ] **Step 1: Copy skills into the dotfiles repo**

```bash
mkdir -p ~/.dotfiles/.claude/skills
cp -r ~/.claude/skills/find-skills ~/.dotfiles/.claude/skills/
cp -r ~/.claude/skills/task-parallelism ~/.dotfiles/.claude/skills/
cp -r ~/.claude/skills/technical-design-documentation ~/.dotfiles/.claude/skills/
```

- [ ] **Step 2: Verify no ClearScore content crept in**

```bash
grep -ri "clearscore" ~/.dotfiles/.claude/skills/
```

Expected: no output (zero matches).

- [ ] **Step 3: Verify files are present**

```bash
git -C ~/.dotfiles ls-files --others --exclude-standard .claude/
```

Expected output includes:
```
.claude/skills/find-skills/SKILL.md
.claude/skills/task-parallelism/SKILL.md
.claude/skills/technical-design-documentation/SKILL.md
.claude/skills/technical-design-documentation/references/tdd-guide.md
.claude/skills/technical-design-documentation/references/tdd-template.md
```

- [ ] **Step 4: Commit and push to the dotfiles repo**

```bash
git -C ~/.dotfiles add .claude/skills/
git -C ~/.dotfiles commit -m "feat: add personal Claude Code skills"
git -C ~/.dotfiles push
```

---

### Task 2: claude_check function + test

**Files:**
- Create: `installers/claude.sh`
- Create: `tests/unit/test_installer_claude.bats`

**Interfaces:**
- Produces: `claude_check()` — returns 0 if `claude` is on PATH, 1 otherwise

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_installer_claude.bats`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
tests/lib/bats/bin/bats tests/unit/test_installer_claude.bats
```

Expected: FAIL — `installers/claude.sh` does not exist yet.

- [ ] **Step 3: Create installers/claude.sh with claude_check**

Create `installers/claude.sh`:

```bash
# shellcheck shell=bash
# Installer: claude.

claude_check() {
  command -v claude >/dev/null 2>&1
}

claude_install() {
  log "Installing Claude Code CLI"
  npm install -g @anthropic-ai/claude-code

  log "Merging Claude settings"
  _claude_merge_settings

  log "Adding Claude plugin marketplaces"
  _claude_add_marketplaces

  log "Installing Claude plugins"
  _claude_install_plugins

  success "claude installed"
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
tests/lib/bats/bin/bats tests/unit/test_installer_claude.bats
```

Expected: PASS (2 tests).

- [ ] **Step 5: Lint check**

```bash
make lint
```

Expected: no shellcheck warnings for `installers/claude.sh`.

- [ ] **Step 6: Commit**

```bash
git add installers/claude.sh tests/unit/test_installer_claude.bats
git commit -m "feat: add claude_check to claude installer"
```

---

### Task 3: _claude_merge_settings + tests

**Files:**
- Modify: `installers/claude.sh` — add `_claude_merge_settings`
- Modify: `tests/unit/test_installer_claude.bats` — add merge tests

**Interfaces:**
- Consumes: `HOME` env var (Python uses `os.environ['HOME']`)
- Produces: `_claude_merge_settings()` — writes/merges `~/.claude/settings.json` with portable keys, preserves all existing keys not in base

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_installer_claude.bats`:

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
tests/lib/bats/bin/bats tests/unit/test_installer_claude.bats
```

Expected: FAIL — `_claude_merge_settings` not defined yet.

- [ ] **Step 3: Implement _claude_merge_settings**

Add to `installers/claude.sh` before `claude_install`:

```bash
_claude_merge_settings() {
  mkdir -p "$HOME/.claude"
  python3 - <<'PYEOF'
import json, os

settings_path = os.path.join(os.environ['HOME'], '.claude', 'settings.json')

base = {
    'model': 'claude-opus-4-7',
    'enabledPlugins': {
        'typescript-lsp@claude-plugins-official': True,
        'superpowers@claude-plugins-official': True,
        'superpowers@superpowers-marketplace': True,
        'caveman@caveman': True,
        'lua-lsp@claude-plugins-official': True,
        'pyright-lsp@claude-plugins-official': True,
    },
    'extraKnownMarketplaces': {
        'superpowers-marketplace': {
            'source': {'source': 'github', 'repo': 'obra/superpowers-marketplace'}
        },
        'caveman': {
            'source': {'source': 'github', 'repo': 'JuliusBrussee/caveman'}
        },
    },
}

existing = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        try:
            existing = json.load(f)
        except (json.JSONDecodeError, ValueError):
            existing = {}

merged = {**existing, **base}
for nested_key in ('enabledPlugins', 'extraKnownMarketplaces'):
    if nested_key in existing:
        merged[nested_key] = {**existing[nested_key], **base[nested_key]}

with open(settings_path, 'w') as f:
    json.dump(merged, f, indent=2)
    f.write('\n')
PYEOF
}
```

Note: uses `os.environ['HOME']` instead of `os.path.expanduser('~')` so bats tests that override `HOME` are respected.

- [ ] **Step 4: Run tests to verify they pass**

```bash
tests/lib/bats/bin/bats tests/unit/test_installer_claude.bats
```

Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add installers/claude.sh tests/unit/test_installer_claude.bats
git commit -m "feat: add _claude_merge_settings to claude installer"
```

---

### Task 4: _claude_add_marketplaces + tests

**Files:**
- Modify: `installers/claude.sh` — add `_claude_add_marketplaces`
- Modify: `tests/unit/test_installer_claude.bats` — add marketplace tests

**Interfaces:**
- Consumes: `claude plugin marketplace list` output (grepped for marketplace name)
- Produces: `_claude_add_marketplaces()` — adds `superpowers-marketplace` and `caveman` if not already present

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_installer_claude.bats`:

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
tests/lib/bats/bin/bats tests/unit/test_installer_claude.bats
```

Expected: FAIL — `_claude_add_marketplaces` not defined.

- [ ] **Step 3: Implement _claude_add_marketplaces**

Add to `installers/claude.sh` before `claude_install`:

```bash
_claude_add_marketplaces() {
  local known
  known="$(claude plugin marketplace list 2>/dev/null || true)"

  if ! printf '%s' "$known" | grep -qF "superpowers-marketplace"; then
    claude plugin marketplace add obra/superpowers-marketplace \
      || warn "Failed to add superpowers-marketplace"
  fi

  if ! printf '%s' "$known" | grep -qF "caveman"; then
    claude plugin marketplace add JuliusBrussee/caveman \
      || warn "Failed to add caveman marketplace"
  fi
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
tests/lib/bats/bin/bats tests/unit/test_installer_claude.bats
```

Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add installers/claude.sh tests/unit/test_installer_claude.bats
git commit -m "feat: add _claude_add_marketplaces to claude installer"
```

---

### Task 5: _claude_install_plugins + tests

**Files:**
- Modify: `installers/claude.sh` — add `_claude_install_plugins`
- Modify: `tests/unit/test_installer_claude.bats` — add plugin install tests

**Interfaces:**
- Consumes: `claude plugin list` output (grepped for `plugin@marketplace` string)
- Produces: `_claude_install_plugins()` — installs each of the 6 plugins if not already installed

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_installer_claude.bats`:

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
tests/lib/bats/bin/bats tests/unit/test_installer_claude.bats
```

Expected: FAIL — `_claude_install_plugins` not defined.

- [ ] **Step 3: Implement _claude_install_plugins**

Add to `installers/claude.sh` before `claude_install`:

```bash
_claude_install_plugins() {
  local installed
  installed="$(claude plugin list 2>/dev/null || true)"

  local plugins=(
    "typescript-lsp@claude-plugins-official"
    "superpowers@claude-plugins-official"
    "superpowers@superpowers-marketplace"
    "caveman@caveman"
    "lua-lsp@claude-plugins-official"
    "pyright-lsp@claude-plugins-official"
  )

  local plugin
  for plugin in "${plugins[@]}"; do
    if ! printf '%s' "$installed" | grep -qF "$plugin"; then
      claude plugin install "$plugin" \
        || warn "Failed to install plugin $plugin"
    fi
  done
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
tests/lib/bats/bin/bats tests/unit/test_installer_claude.bats
```

Expected: PASS (12 tests).

- [ ] **Step 5: Commit**

```bash
git add installers/claude.sh tests/unit/test_installer_claude.bats
git commit -m "feat: add _claude_install_plugins to claude installer"
```

---

### Task 6: Wire claude into install.sh + full test run

**Files:**
- Modify: `install.sh:88` (the `TOOL_ORDER` array) — add `claude` after `node`

**Interfaces:**
- Consumes: `claude_check`, `claude_install` from `installers/claude.sh` (loaded by `load_installers`)
- Produces: `claude` included in orchestrated install run; skippable via `--skip claude`; targetable via `--only claude`

- [ ] **Step 1: Add claude to TOOL_ORDER**

In `install.sh`, locate the `TOOL_ORDER` array and add `claude` after `node`:

```bash
TOOL_ORDER=(
  basics
  git
  build_toolchain
  python3
  zsh
  ohmyzsh
  tmux
  fzf
  ripgrep
  nvm
  node
  claude
  tree_sitter_cli
  go
  rust
  kitty
  neovim
  clipboard
  fonts
)
```

- [ ] **Step 2: Verify claude appears in TOOL_ORDER**

```bash
grep -n "claude" install.sh
```

Expected output contains a line like `  claude` inside the TOOL_ORDER block, and no other unintended matches.

- [ ] **Step 3: Verify dry-run mentions claude**

```bash
bash install.sh --dry-run --only claude 2>&1 | grep -i claude
```

Expected output contains `[dry-run] would install claude`.

- [ ] **Step 4: Run full test suite**

```bash
make test
```

Expected: all tests pass, no shellcheck warnings.

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "feat: add claude to TOOL_ORDER in install.sh"
```
