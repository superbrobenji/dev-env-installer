# SSH GitHub Namespace — Design Spec

**Date:** 2026-06-19  
**Scope:** `dotfiles.sh` in `dev-env-installer`; `~/.dotfiles` SSH config and gitconfig templates  
**Related:** git-identity-prompting spec, ssh-config-placement spec

---

## Problem

The previous SSH config defaulted `github.com` to the work key, requiring an explicit `GitHub-personal` host alias for personal repos. This is backwards — personal should be the default, work should be opt-in via the `~/projects/work/` gitconfig `includeIf`.

SSH key selection was also entirely controlled by SSH config, meaning repos outside `~/projects/work/` had no way to automatically use the correct key without manual remote URL changes.

---

## Goal

- `github.com` resolves to personal key by default
- Repos under `~/projects/work/` automatically use the work SSH key — no remote URL changes required
- Repos under `~/projects/personal/` explicitly use the personal SSH key
- A `github-work` host alias exists for explicit use if ever needed
- No references to employer name in any committed file

---

## Design

### 1. `.ssh/config`

```
Host github.com
  HostName github.com
  AddKeysToAgent yes
  IdentitiesOnly yes
  User git
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519_personal

Host github-work
  HostName github.com
  AddKeysToAgent yes
  IdentitiesOnly yes
  User git
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519_work
```

`GitHub-personal` alias removed. Personal is now the SSH default for all `github.com` connections.

### 2. `.gitconfig-personal.template`

```ini
[user]
    email = 49689582+superbrobenji@users.noreply.github.com
    signingkey = ~/.ssh/id_ed25519_personal
[core]
    sshCommand = ssh -i ~/.ssh/id_ed25519_personal -o IdentitiesOnly=yes
```

Explicit even though it matches the SSH default — makes the intent clear and overrides any base gitconfig `sshCommand`.

### 3. `.gitconfig-work.template`

```ini
[user]
    email = [WORK EMAIL]
    signingkey = ~/.ssh/id_ed25519_work
[core]
    sshCommand = ssh -i ~/.ssh/id_ed25519_work -o IdentitiesOnly=yes
```

`core.sshCommand` overrides SSH config for all git operations in `~/projects/work/` repos. Remote URLs stay as `github.com` — no changes to existing repos needed.

### 4. How it composes with `includeIf`

```
~/.gitconfig
  └── includeIf "gitdir:~/projects/work/"  → ~/.gitconfig-work
        sets core.sshCommand → work key
  └── includeIf "gitdir:~/projects/personal/" → ~/.gitconfig-personal
        sets core.sshCommand → personal key
  └── (everywhere else) github.com SSH default → personal key
```

### 5. dev-env-installer changes

`setup_gitconfig_overrides` (from git-identity spec) already copies the templates.
`core.sshCommand` is included in the templates themselves — no additional installer logic needed.

The SSH config is placed by `checkout_dotfiles` + `fix_ssh_permissions` (from ssh-config-placement spec) — no additional step needed here either.

---

## Files changed

| File | Change |
|------|--------|
| `.ssh/config` | Flip default: `github.com` → personal key; rename `GitHub-personal` → `github-work` for work |
| `.gitconfig-personal.template` | Add `core.sshCommand` for personal key |
| `.gitconfig-work.template` | Add `core.sshCommand` for work key |

No `dotfiles.sh` changes required beyond what the prior two specs already cover.

---

## Out of scope

- SSH key generation
- Handling GitHub Enterprise hosts
- Multi-account same-org scenarios

---

## Testing

- `ssh -T git@github.com` should authenticate as personal account
- `ssh -T git@github-work` should authenticate as work account
- Push from `~/projects/personal/` repo: uses personal key (verify with `GIT_SSH_COMMAND` trace)
- Push from `~/projects/work/` repo: uses work key (verify with `GIT_SSH_COMMAND` trace)
