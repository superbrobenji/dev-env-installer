# Dotfiles SSH + Git Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement SSH dir setup, SSH permission enforcement, personal + work git identity prompting, and project directory creation in `dotfiles.sh`.

**Architecture:** Four independent, focused changes to `dotfiles.sh` — each adding or replacing a single responsibility. Tests live in `tests/unit/test_dotfiles.bats` and follow the existing bats pattern (mock `HOME` to a tmpdir per test). TDD throughout.

**Tech Stack:** Bash 3.2+, bats-core, bats-assert, bats-support

## Global Constraints

- Bash 3.2 compatible (macOS ships bash 3.2 — no `declare -A`, no `mapfile`, no `${var,,}`)
- `shellcheck -x` must pass on all `.sh` files
- `tests/lib/bats/bin/bats tests/unit/` must pass after every task
- No new dependencies
- Functions are idempotent — never overwrite files that already exist
- `YES=1` skips all interactive prompts

---

### Task 1: Update `_is_local_override`

**Files:**
- Modify: `dotfiles.sh` (function `_is_local_override`, lines 79–84)
- Modify: `tests/unit/test_dotfiles.bats`

**Interfaces:**
- Produces: `_is_local_override(path)` returns 0 for `.gitconfig-work`, `.gitconfig-personal`, `.ssh/id_*`, `.ssh/known_hosts`; returns 1 for everything else

- [ ] **Step 1: Write failing tests**

Append to `tests/unit/test_dotfiles.bats`:

```bash
@test "_is_local_override returns 0 for .gitconfig-work" {
  run _is_local_override ".gitconfig-work"
  assert_success
}

@test "_is_local_override returns 0 for .gitconfig-personal" {
  run _is_local_override ".gitconfig-personal"
  assert_success
}

@test "_is_local_override returns 0 for .ssh/id_rsa" {
  run _is_local_override ".ssh/id_rsa"
  assert_success
}

@test "_is_local_override returns 0 for .ssh/id_ed25519" {
  run _is_local_override ".ssh/id_ed25519"
  assert_success
}

@test "_is_local_override returns 0 for .ssh/known_hosts" {
  run _is_local_override ".ssh/known_hosts"
  assert_success
}

@test "_is_local_override returns 1 for .zshrc" {
  run _is_local_override ".zshrc"
  assert_failure
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
tests/lib/bats/bin/bats tests/unit/test_dotfiles.bats
```

Expected: first two new tests fail (`_is_local_override` returns 1 for dash-notation names). `.ssh/id_*` tests fail. `.zshrc` test passes.

- [ ] **Step 3: Update `_is_local_override` in `dotfiles.sh`**

Replace:

```bash
_is_local_override() {
  case "$1" in
    .zshrc.local|.gitconfig.work|.gitconfig.personal) return 0 ;;
    *) return 1 ;;
  esac
}
```

With:

```bash
_is_local_override() {
  case "$1" in
    .zshrc.local|.gitconfig-work|.gitconfig-personal) return 0 ;;
    .ssh/id_*|.ssh/known_hosts) return 0 ;;
    *) return 1 ;;
  esac
}
```

- [ ] **Step 4: Run tests to confirm all pass**

```bash
tests/lib/bats/bin/bats tests/unit/test_dotfiles.bats
```

Expected: all 9 tests pass.

- [ ] **Step 5: Run shellcheck**

```bash
shellcheck -x dotfiles.sh
```

Expected: no output (exit 0).

- [ ] **Step 6: Commit**

```bash
git add dotfiles.sh tests/unit/test_dotfiles.bats
git commit -m "feat: update _is_local_override for dash-notation and ssh key protection"
```

---

### Task 2: Add `setup_ssh_dir` and `fix_ssh_permissions`

**Files:**
- Modify: `dotfiles.sh` (add two functions after `_is_local_override`)
- Modify: `tests/unit/test_dotfiles.bats`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `setup_ssh_dir()` — ensures `~/.ssh` exists with perms `700`
  - `fix_ssh_permissions()` — ensures `~/.ssh/config` has perms `600` if present; no-op if absent

- [ ] **Step 1: Write failing tests**

Append to `tests/unit/test_dotfiles.bats`:

```bash
@test "setup_ssh_dir creates ~/.ssh with perms 700" {
  HOME="$(mktemp -d)"
  setup_ssh_dir
  [ -d "$HOME/.ssh" ]
  local perms
  perms="$(stat -f "%Lp" "$HOME/.ssh" 2>/dev/null || stat -c "%a" "$HOME/.ssh")"
  [ "$perms" = "700" ]
  rm -rf "$HOME"
}

@test "setup_ssh_dir is idempotent when dir exists" {
  HOME="$(mktemp -d)"
  mkdir -p "$HOME/.ssh"
  chmod 755 "$HOME/.ssh"
  setup_ssh_dir
  local perms
  perms="$(stat -f "%Lp" "$HOME/.ssh" 2>/dev/null || stat -c "%a" "$HOME/.ssh")"
  [ "$perms" = "700" ]
  rm -rf "$HOME"
}

@test "fix_ssh_permissions sets 600 on ~/.ssh/config if present" {
  HOME="$(mktemp -d)"
  mkdir -p "$HOME/.ssh"
  touch "$HOME/.ssh/config"
  chmod 644 "$HOME/.ssh/config"
  fix_ssh_permissions
  local perms
  perms="$(stat -f "%Lp" "$HOME/.ssh/config" 2>/dev/null || stat -c "%a" "$HOME/.ssh/config")"
  [ "$perms" = "600" ]
  rm -rf "$HOME"
}

@test "fix_ssh_permissions is no-op when config absent" {
  HOME="$(mktemp -d)"
  mkdir -p "$HOME/.ssh"
  run fix_ssh_permissions
  assert_success
  rm -rf "$HOME"
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
tests/lib/bats/bin/bats tests/unit/test_dotfiles.bats
```

Expected: four new tests fail with `setup_ssh_dir: command not found` / `fix_ssh_permissions: command not found`.

- [ ] **Step 3: Add functions to `dotfiles.sh`**

Add after `_is_local_override`:

```bash
setup_ssh_dir() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
}

fix_ssh_permissions() {
  [[ -f "$HOME/.ssh/config" ]] && chmod 600 "$HOME/.ssh/config"
}
```

- [ ] **Step 4: Run tests to confirm all pass**

```bash
tests/lib/bats/bin/bats tests/unit/test_dotfiles.bats
```

Expected: all 13 tests pass.

- [ ] **Step 5: Run shellcheck**

```bash
shellcheck -x dotfiles.sh
```

Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add dotfiles.sh tests/unit/test_dotfiles.bats
git commit -m "feat: add setup_ssh_dir and fix_ssh_permissions"
```

---

### Task 3: Replace `ensure_local_override_stubs` with `setup_gitconfig_overrides` + `ensure_zshrc_local_stub`

**Files:**
- Modify: `dotfiles.sh` (remove `ensure_local_override_stubs`; add `setup_gitconfig_overrides`, `ensure_zshrc_local_stub`)
- Modify: `tests/unit/test_dotfiles.bats` (remove old tests; add new tests)

**Interfaces:**
- Consumes: `$DOTFILES_DIR/.gitconfig-personal.template`, `$DOTFILES_DIR/.gitconfig-work.template` (must exist before calling)
- Produces:
  - `setup_gitconfig_overrides()` — writes `~/.gitconfig-personal` and `~/.gitconfig-work` from templates; prompts for emails interactively; skips if files already exist
  - `ensure_zshrc_local_stub()` — creates `~/.zshrc.local` stub if missing

- [ ] **Step 1: Write failing tests for new functions**

Append to `tests/unit/test_dotfiles.bats`:

```bash
@test "setup_gitconfig_overrides writes both config files from templates" {
  HOME="$(mktemp -d)"
  DOTFILES_DIR="$(mktemp -d)"
  printf '[user]\n\temail = [PERSONAL EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-personal.template"
  printf '[user]\n\temail = [WORK EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-work.template"
  YES=1 setup_gitconfig_overrides
  [ -f "$HOME/.gitconfig-personal" ]
  [ -f "$HOME/.gitconfig-work" ]
  rm -rf "$HOME" "$DOTFILES_DIR"
}

@test "setup_gitconfig_overrides leaves placeholders when YES=1" {
  HOME="$(mktemp -d)"
  DOTFILES_DIR="$(mktemp -d)"
  printf '[user]\n\temail = [PERSONAL EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-personal.template"
  printf '[user]\n\temail = [WORK EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-work.template"
  YES=1 setup_gitconfig_overrides
  run grep '\[PERSONAL EMAIL\]' "$HOME/.gitconfig-personal"
  assert_success
  run grep '\[WORK EMAIL\]' "$HOME/.gitconfig-work"
  assert_success
  rm -rf "$HOME" "$DOTFILES_DIR"
}

@test "setup_gitconfig_overrides substitutes emails interactively" {
  HOME="$(mktemp -d)"
  DOTFILES_DIR="$(mktemp -d)"
  printf '[user]\n\temail = [PERSONAL EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-personal.template"
  printf '[user]\n\temail = [WORK EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-work.template"
  printf 'personal@example.com\nwork@corp.com\n' | setup_gitconfig_overrides
  run grep 'personal@example.com' "$HOME/.gitconfig-personal"
  assert_success
  run grep 'work@corp.com' "$HOME/.gitconfig-work"
  assert_success
  rm -rf "$HOME" "$DOTFILES_DIR"
}

@test "setup_gitconfig_overrides is idempotent when files exist" {
  HOME="$(mktemp -d)"
  DOTFILES_DIR="$(mktemp -d)"
  printf '[user]\n\temail = [PERSONAL EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-personal.template"
  printf '[user]\n\temail = [WORK EMAIL]\n' > "$DOTFILES_DIR/.gitconfig-work.template"
  echo "existing personal" > "$HOME/.gitconfig-personal"
  echo "existing work" > "$HOME/.gitconfig-work"
  YES=1 setup_gitconfig_overrides
  run cat "$HOME/.gitconfig-personal"
  assert_output "existing personal"
  run cat "$HOME/.gitconfig-work"
  assert_output "existing work"
  rm -rf "$HOME" "$DOTFILES_DIR"
}

@test "ensure_zshrc_local_stub creates .zshrc.local if missing" {
  HOME="$(mktemp -d)"
  ensure_zshrc_local_stub
  [ -f "$HOME/.zshrc.local" ]
  rm -rf "$HOME"
}

@test "ensure_zshrc_local_stub does not overwrite existing .zshrc.local" {
  HOME="$(mktemp -d)"
  echo "existing" > "$HOME/.zshrc.local"
  ensure_zshrc_local_stub
  run cat "$HOME/.zshrc.local"
  assert_output "existing"
  rm -rf "$HOME"
}
```

- [ ] **Step 2: Run tests to confirm new tests fail**

```bash
tests/lib/bats/bin/bats tests/unit/test_dotfiles.bats
```

Expected: six new tests fail (`setup_gitconfig_overrides: command not found`, `ensure_zshrc_local_stub: command not found`). All existing tests still pass.

- [ ] **Step 3: Add new functions to `dotfiles.sh`**

Add after `fix_ssh_permissions`, keeping `ensure_local_override_stubs` in place for now:

```bash
setup_gitconfig_overrides() {
  local personal_email="" work_email="" content

  if [[ ! -f "$HOME/.gitconfig-personal" ]]; then
    if [[ "${YES:-0}" != "1" ]]; then
      printf "Personal email for git commits: "
      read -r personal_email
    fi
    content="$(cat "$DOTFILES_DIR/.gitconfig-personal.template")"
    [[ -n "$personal_email" ]] && content="${content//\[PERSONAL EMAIL\]/$personal_email}"
    printf '%s\n' "$content" > "$HOME/.gitconfig-personal"
    log "Written ~/.gitconfig-personal"
  fi

  if [[ ! -f "$HOME/.gitconfig-work" ]]; then
    if [[ "${YES:-0}" != "1" ]]; then
      printf "Work email for git commits: "
      read -r work_email
    fi
    content="$(cat "$DOTFILES_DIR/.gitconfig-work.template")"
    [[ -n "$work_email" ]] && content="${content//\[WORK EMAIL\]/$work_email}"
    printf '%s\n' "$content" > "$HOME/.gitconfig-work"
    log "Written ~/.gitconfig-work"
  fi
}

ensure_zshrc_local_stub() {
  if [[ ! -f "$HOME/.zshrc.local" ]]; then
    cat > "$HOME/.zshrc.local" <<'EOF'
# Machine-specific zsh overrides. Not tracked in dotfiles repo.
# Example exports:
# export AWS_PROFILE=...
# export AVANTE_ANTHROPIC_API_KEY=...
# command -v typo >/dev/null 2>&1 && eval "$(typo init zsh)"
EOF
  fi
}
```

- [ ] **Step 4: Run tests to confirm all pass**

```bash
tests/lib/bats/bin/bats tests/unit/test_dotfiles.bats
```

Expected: all 19 tests pass (old `ensure_local_override_stubs` tests still pass — function still exists).

- [ ] **Step 5: Remove `ensure_local_override_stubs` from `dotfiles.sh`**

Delete the entire `ensure_local_override_stubs` function block:

```bash
ensure_local_override_stubs() {
  if [[ ! -f "$HOME/.zshrc.local" ]]; then
    cat > "$HOME/.zshrc.local" <<'EOF'
# Machine-specific zsh overrides. Not tracked in dotfiles repo.
# Example exports:
# export AWS_PROFILE=...
# export AVANTE_ANTHROPIC_API_KEY=...
# command -v typo >/dev/null 2>&1 && eval "$(typo init zsh)"
EOF
  fi
  if [[ ! -f "$HOME/.gitconfig.work" ]]; then
    cat > "$HOME/.gitconfig.work" <<'EOF'
# Work git identity. Included from .gitconfig when gitdir matches ~/work/.
# [user]
#   name = Your Work Name
#   email = work@example.com
EOF
  fi
  if [[ ! -f "$HOME/.gitconfig.personal" ]]; then
    cat > "$HOME/.gitconfig.personal" <<'EOF'
# Personal git identity. Included from .gitconfig when gitdir matches ~/projects/.
# [user]
#   name = Your Name
#   email = you@example.com
EOF
  fi
}
```

- [ ] **Step 6: Remove old tests from `tests/unit/test_dotfiles.bats`**

Delete these two test blocks:

```bash
@test "ensure_local_override_stubs creates files if missing" {
  HOME="$(mktemp -d)"
  ensure_local_override_stubs
  [ -f "$HOME/.zshrc.local" ]
  [ -f "$HOME/.gitconfig.work" ]
  [ -f "$HOME/.gitconfig.personal" ]
  rm -rf "$HOME"
}

@test "ensure_local_override_stubs does not overwrite existing files" {
  HOME="$(mktemp -d)"
  echo "existing" > "$HOME/.zshrc.local"
  ensure_local_override_stubs
  run cat "$HOME/.zshrc.local"
  assert_output "existing"
  rm -rf "$HOME"
}
```

- [ ] **Step 7: Run tests to confirm all pass**

```bash
tests/lib/bats/bin/bats tests/unit/test_dotfiles.bats
```

Expected: all 17 tests pass.

- [ ] **Step 8: Run shellcheck**

```bash
shellcheck -x dotfiles.sh
```

Expected: no output.

- [ ] **Step 9: Commit**

```bash
git add dotfiles.sh tests/unit/test_dotfiles.bats
git commit -m "feat: replace ensure_local_override_stubs with setup_gitconfig_overrides and ensure_zshrc_local_stub"
```

---

### Task 4: Update `run_dotfiles` and run full suite

**Files:**
- Modify: `dotfiles.sh` (`run_dotfiles` function)

**Interfaces:**
- Consumes: `setup_ssh_dir`, `fix_ssh_permissions`, `setup_gitconfig_overrides`, `ensure_zshrc_local_stub` (all defined in prior tasks)

- [ ] **Step 1: Update `run_dotfiles` in `dotfiles.sh`**

Replace:

```bash
run_dotfiles() {
  verify_dotfiles_ownership
  clone_or_update_repo "$DOTFILES_REPO" "$DOTFILES_DIR"
  checkout_dotfiles
  ensure_local_override_stubs
  clone_or_update_repo "$NVIM_REPO" "$NVIM_DIR"
  success "dotfiles + nvim config in place"
}
```

With:

```bash
run_dotfiles() {
  verify_dotfiles_ownership
  clone_or_update_repo "$DOTFILES_REPO" "$DOTFILES_DIR"
  setup_ssh_dir
  checkout_dotfiles
  fix_ssh_permissions
  setup_gitconfig_overrides
  ensure_zshrc_local_stub
  mkdir -p "$HOME/projects/work" "$HOME/projects/personal"
  clone_or_update_repo "$NVIM_REPO" "$NVIM_DIR"
  success "dotfiles + nvim config in place"
}
```

- [ ] **Step 2: Run full test suite**

```bash
make test
```

Expected: shellcheck passes, all 17 bats tests pass.

- [ ] **Step 3: Commit**

```bash
git add dotfiles.sh
git commit -m "feat: update run_dotfiles with ssh setup, gitconfig overrides, and project dirs"
```
