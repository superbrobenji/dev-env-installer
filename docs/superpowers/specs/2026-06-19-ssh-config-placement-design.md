# SSH Config Placement — Design Spec

**Date:** 2026-06-19  
**Scope:** `dotfiles.sh` in `dev-env-installer`  
**Related:** `~/.dotfiles` repo (ships `.ssh/config`)

---

## Problem

`checkout_dotfiles` copies all tracked files from the dotfiles repo to `$HOME`, but `.ssh/` requires specific directory and file permissions (`700` / `600`) that `cp -a` may not set correctly on a fresh machine. There is also no guarantee that `~/.ssh/` exists before the copy runs.

---

## Goal

After `run_dotfiles` completes on a fresh machine:

- `~/.ssh/` exists with permissions `700`
- `~/.ssh/config` is in place with permissions `600`
- Existing `~/.ssh/config` is backed up, not overwritten silently
- Private keys (`id_*`, `known_hosts`) are never touched

---

## Design

### 1. SSH config is tracked in the dotfiles repo

`.ssh/config` is committed. `checkout_dotfiles` will copy it as part of normal file sync. No separate step needed for the copy itself.

### 2. Add `setup_ssh_dir` function

Run before `checkout_dotfiles` to ensure the directory exists with correct permissions:

```bash
setup_ssh_dir() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
}
```

### 3. Fix permissions after checkout

`cp -a` preserves source permissions. Since `.ssh/config` in the dotfiles repo is `600`, it should copy correctly. Add an explicit `chmod` after `checkout_dotfiles` as a safety net:

```bash
fix_ssh_permissions() {
  [[ -f "$HOME/.ssh/config" ]] && chmod 600 "$HOME/.ssh/config"
}
```

### 4. Protect private keys in `_is_local_override`

`.ssh/id_*` and `.ssh/known_hosts` must never be overwritten by `checkout_dotfiles`. Add them to `_is_local_override`:

```bash
_is_local_override() {
  case "$1" in
    .zshrc.local|.gitconfig-work|.gitconfig-personal) return 0 ;;
    .ssh/id_*|.ssh/known_hosts) return 0 ;;
    *) return 1 ;;
  esac
}
```

Note: also updates `.gitconfig.work` → `.gitconfig-work` and `.gitconfig.personal` → `.gitconfig-personal` to match the dash-notation rename from the git identity spec.

### 5. Update `run_dotfiles` call order

```bash
run_dotfiles() {
  verify_dotfiles_ownership
  clone_or_update_repo "$DOTFILES_REPO" "$DOTFILES_DIR"
  setup_ssh_dir                      # ensure ~/.ssh exists with 700
  checkout_dotfiles                  # copies .ssh/config from repo
  fix_ssh_permissions                # enforce 600 on .ssh/config
  setup_gitconfig_overrides          # from git-identity spec
  ensure_zshrc_local_stub
  mkdir -p "$HOME/projects/work" "$HOME/projects/personal"
  clone_or_update_repo "$NVIM_REPO" "$NVIM_DIR"
  success "dotfiles + nvim config in place"
}
```

---

## Files changed

| File | Change |
|------|--------|
| `dotfiles.sh` | Add `setup_ssh_dir`, `fix_ssh_permissions`; update `_is_local_override` to protect key files and use dash-notation gitconfig names; update `run_dotfiles` call order |

---

## Out of scope

- SSH key generation (user must add their own `id_*` keys manually)
- `known_hosts` management
- SSH agent setup

---

## Testing

- Run on clean `$HOME` mock: confirm `~/.ssh/` created with `700`, config copied with `600`
- Run with existing `~/.ssh/config`: confirm backup made, not silently overwritten
- Confirm `~/.ssh/id_*` and `~/.ssh/known_hosts` untouched if present
- Existing docker smoke tests should continue to pass
