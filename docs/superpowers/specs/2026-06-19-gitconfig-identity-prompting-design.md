# Git Identity Prompting — Design Spec

**Date:** 2026-06-19  
**Scope:** `dotfiles.sh` in `dev-env-installer`  
**Related:** `~/.dotfiles` repo (ships `.gitconfig-work.template` and `.gitconfig-personal.template`)

---

## Problem

`dotfiles.sh` currently writes commented stub files for `.gitconfig.work` and `.gitconfig.personal`. The user must manually open and edit them. There is no prompting, no substitution, and the naming uses dot notation (`.gitconfig.work`) which doesn't match the `includeIf` paths in `.gitconfig` (which use dash notation: `.gitconfig-work`).

---

## Goal

After `run_dotfiles` completes on a fresh machine:

- `~/.gitconfig-work` exists with the user's real work email substituted in
- `~/.gitconfig-personal` exists with the GitHub privacy email (no substitution needed)
- `~/projects/work/` and `~/projects/personal/` directories exist
- Git identity works correctly for repos under each directory immediately, no manual editing required

---

## Design

### 1. Template source

The dotfiles repo ships two template files (already committed):

```
~/.dotfiles/.gitconfig-work.template
~/.dotfiles/.gitconfig-personal.template
```

`dotfiles.sh` reads these from `$DOTFILES_DIR` after cloning/updating.

### 2. Rename: dot → dash notation

Everywhere `.gitconfig.work` and `.gitconfig.personal` appear, rename to `.gitconfig-work` and `.gitconfig-personal`:

- `_is_local_override()` case statement
- `ensure_local_override_stubs()` (replaced entirely — see below)
- Any comments/docs

### 3. Replace `ensure_local_override_stubs` with `setup_gitconfig_overrides`

New function: `setup_gitconfig_overrides`

```
setup_gitconfig_overrides() {
  # .gitconfig-personal — copy template, no substitution
  if [[ ! -f "$HOME/.gitconfig-personal" ]]; then
    cp "$DOTFILES_DIR/.gitconfig-personal.template" "$HOME/.gitconfig-personal"
    log "Written ~/.gitconfig-personal"
  fi

  # .gitconfig-work — copy template, substitute [WORK EMAIL] if possible
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

**Behaviour:**
- If `~/.gitconfig-work` already exists → skip entirely (idempotent, matches existing pattern)
- If `--yes` / `YES=1` → copies template as-is, `[WORK EMAIL]` placeholder remains (user fills in later)
- If interactive → prompts once, substitutes, writes

### 4. Create project directories

In `run_dotfiles`, after `setup_gitconfig_overrides`:

```bash
mkdir -p "$HOME/projects/work" "$HOME/projects/personal"
```

These are the directories the `.gitconfig` `includeIf` blocks target.

### 5. `.zshrc.local` stub

Keep existing `.zshrc.local` stub logic unchanged. No prompting needed for it.

### 6. Update `run_dotfiles` call order

```bash
run_dotfiles() {
  verify_dotfiles_ownership
  clone_or_update_repo "$DOTFILES_REPO" "$DOTFILES_DIR"
  checkout_dotfiles
  setup_gitconfig_overrides          # replaces ensure_local_override_stubs
  ensure_zshrc_local_stub            # renamed from ensure_local_override_stubs remainder
  mkdir -p "$HOME/projects/work" "$HOME/projects/personal"
  clone_or_update_repo "$NVIM_REPO" "$NVIM_DIR"
  success "dotfiles + nvim config in place"
}
```

Split `ensure_local_override_stubs` into two focused functions:
- `setup_gitconfig_overrides` — handles both gitconfig files
- `ensure_zshrc_local_stub` — handles `.zshrc.local` only

---

## Files changed

| File | Change |
|------|--------|
| `dotfiles.sh` | Replace `ensure_local_override_stubs` with `setup_gitconfig_overrides` + `ensure_zshrc_local_stub`; rename dot→dash throughout; add `mkdir -p` for project dirs in `run_dotfiles` |

---

## Out of scope

- Prompting for user name (already in `.gitconfig` as a static value)
- SSH key generation (separate concern)
- nvim config (unchanged)

---

## Testing

- Run `dotfiles.sh` in isolation on a clean `$HOME` mock dir: confirm both gitconfig files written, placeholder substituted, project dirs created
- Run with `YES=1`: confirm no prompt, `[WORK EMAIL]` left as-is
- Run twice: confirm idempotent (existing files not overwritten)
- Existing docker smoke tests in `tests/docker/` should continue to pass
