# Dotfiles SSH + Git Identity Setup — Design Spec

**Date:** 2026-06-19
**Scope:** `dotfiles.sh`, `tests/unit/test_dotfiles.bats`
**Implements:** git-identity-prompting, ssh-config-placement, ssh-github-namespace specs
**Strategy:** Single atomic pass — specs are interdependent and land together

---

## Problem

`dotfiles.sh` has three gaps on a fresh machine:

1. SSH dir may not exist; `cp -a` may not enforce required permissions on `~/.ssh/config`
2. `.gitconfig.work` / `.gitconfig.personal` use wrong notation (dot vs dash) and are written as commented stubs — user must edit manually
3. No `~/projects/work/` and `~/projects/personal/` directories, so `includeIf` blocks in `.gitconfig` never activate

---

## Design

### 1. `_is_local_override` updates

```bash
_is_local_override() {
  case "$1" in
    .zshrc.local|.gitconfig-work|.gitconfig-personal) return 0 ;;
    .ssh/id_*|.ssh/known_hosts) return 0 ;;
    *) return 1 ;;
  esac
}
```

Changes:
- `.gitconfig.work` / `.gitconfig.personal` → `.gitconfig-work` / `.gitconfig-personal` (dot→dash)
- Add `.ssh/id_*` and `.ssh/known_hosts` — never overwrite private keys or known hosts

### 2. `setup_ssh_dir` (new)

```bash
setup_ssh_dir() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
}
```

Run before `checkout_dotfiles` so `~/.ssh/` exists with correct perms before any file copy.

### 3. `fix_ssh_permissions` (new)

```bash
fix_ssh_permissions() {
  [[ -f "$HOME/.ssh/config" ]] && chmod 600 "$HOME/.ssh/config"
}
```

Run after `checkout_dotfiles` as a safety net — `cp -a` preserves source perms but this enforces 600 explicitly.

### 4. `setup_gitconfig_overrides` (replaces `ensure_local_override_stubs` gitconfig logic)

```bash
setup_gitconfig_overrides() {
  if [[ ! -f "$HOME/.gitconfig-personal" ]]; then
    local personal_email=""
    if [[ "${YES:-0}" != "1" ]]; then
      printf "Personal email for git commits: "
      read -r personal_email
    fi
    local content
    content="$(cat "$DOTFILES_DIR/.gitconfig-personal.template")"
    if [[ -n "$personal_email" ]]; then
      content="${content//\[PERSONAL EMAIL\]/$personal_email}"
    fi
    printf '%s\n' "$content" > "$HOME/.gitconfig-personal"
    log "Written ~/.gitconfig-personal"
  fi

  if [[ ! -f "$HOME/.gitconfig-work" ]]; then
    local work_email=""
    if [[ "${YES:-0}" != "1" ]]; then
      printf "Work email for git commits: "
      read -r work_email
    fi
    local content
    content="$(cat "$DOTFILES_DIR/.gitconfig-work.template")"
    if [[ -n "$work_email" ]]; then
      content="${content//\[WORK EMAIL\]/$work_email}"
    fi
    printf '%s\n' "$content" > "$HOME/.gitconfig-work"
    log "Written ~/.gitconfig-work"
  fi
}
```

Behaviour:
- Idempotent: skips each file independently if it already exists
- `YES=1`: copies templates as-is, placeholders remain
- Interactive: prompts for personal email then work email, substitutes both

### 5. `ensure_zshrc_local_stub` (split from `ensure_local_override_stubs`)

Exact same logic as before, `.zshrc.local` only. Function renamed for clarity.

```bash
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

### 6. `run_dotfiles` call order

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

`ensure_local_override_stubs` removed entirely.

---

## Files changed

| File | Change |
|------|--------|
| `dotfiles.sh` | `_is_local_override` updated; `ensure_local_override_stubs` removed; `setup_ssh_dir`, `fix_ssh_permissions`, `setup_gitconfig_overrides`, `ensure_zshrc_local_stub` added; `run_dotfiles` updated |
| `tests/unit/test_dotfiles.bats` | Old `ensure_local_override_stubs` tests replaced; new tests for all four new/updated functions |

---

## Test design

`setup()` seeds a tmpdir for `HOME` and a tmpdir for `DOTFILES_DIR` with stub template files. `teardown()` removes both.

| Function | Cases |
|----------|-------|
| `_is_local_override` | `.gitconfig-work` → 0; `.gitconfig-personal` → 0; `.ssh/id_rsa` → 0; `.ssh/known_hosts` → 0; `.zshrc` → 1 |
| `ensure_zshrc_local_stub` | Creates `.zshrc.local` if missing; does not overwrite existing |
| `setup_gitconfig_overrides` | Both files written from templates on clean HOME; `YES=1` leaves `[PERSONAL EMAIL]` and `[WORK EMAIL]` placeholders; interactive (stdin) substitutes both emails; idempotent on second run |
| `setup_ssh_dir` | Creates `~/.ssh` with perms `700`; no error if dir exists |
| `fix_ssh_permissions` | Sets `600` on `~/.ssh/config` if present; no error if absent |

---

## Out of scope

- SSH key generation
- `known_hosts` management
- SSH agent setup
- nvim config
- Dotfiles repo content (`.ssh/config`, `.gitconfig-*.template` already committed to `~/.dotfiles`; `.gitconfig-personal.template` updated to use `[PERSONAL EMAIL]` placeholder)
