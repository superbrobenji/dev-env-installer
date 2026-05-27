# Dev Env Installer — Rewrite Design

**Date:** 2026-05-27
**Status:** Approved (pending user spec review)
**Author:** Benjamin Swanepoel

## 1. Purpose

Rewrite the three existing shell scripts (`install.sh`, `dep-installer.sh`, `fetch-dotfiles.sh`) so a single command provisions a complete dev environment on macOS and on the three most-used Linux distro families (Debian/Ubuntu, Fedora/RHEL, Arch). The current implementation hardcodes `apt-get`, breaks on non-Debian Linux, conflates terminal install paths, masks errors via `curl | bash` pipes, and silently clobbers local dotfiles. The rewrite must be cross-platform, idempotent, partially sudo-free, and never lose user data.

## 2. Goals

- One command provisions everything from a clean macOS or Linux machine.
- Works on macOS (Apple Silicon + Intel), Debian/Ubuntu, Fedora/RHEL, Arch and derivatives.
- Idempotent: re-running on a partial install only installs what's missing.
- Hybrid sudo: prompts once for system packages that genuinely need it; everything else installs to `$HOME`.
- Never overwrites user dotfile customisations; supports a local-overrides pattern.
- Surfaces failures clearly without aborting the entire run on one bad tool.

## 3. Non-Goals

- openSUSE, Alpine, NixOS, or BSD support.
- Windows / WSL support (out of scope; user does not target it).
- Auto-upgrading installed tools to latest versions (idempotent skip is enough).
- Declarative state reconciliation (no Nix, no Ansible).
- Interactive per-package prompting (must support unattended runs).

## 4. Repository Layout

```
dev-env-installer/
├── bootstrap.sh                # curl|bash entry: clones repo → exec install.sh
├── install.sh                  # local entry point
├── lib/
│   ├── core.sh                 # logging, set -euo, traps, dry-run, flag parsing
│   ├── detect.sh               # OS, distro (via /etc/os-release), arch, display server
│   ├── network.sh              # connectivity probe
│   ├── sudo.sh                 # probe + keepalive + sudo_run wrapper
│   ├── github.sh               # latest-release URL resolver (jq + grep fallback)
│   └── pkg/
│       ├── names.sh            # logical → distro-specific name map
│       ├── apt.sh
│       ├── dnf.sh
│       ├── pacman.sh
│       └── brew.sh
├── installers/                 # one file per tool, each exports <tool>_check + <tool>_install
│   ├── git.sh
│   ├── basics.sh               # curl, wget, unzip, tar, jq
│   ├── build-toolchain.sh
│   ├── python3.sh
│   ├── zsh.sh
│   ├── ohmyzsh.sh
│   ├── tmux.sh
│   ├── fzf.sh
│   ├── ripgrep.sh
│   ├── nvm.sh
│   ├── node.sh                 # depends on nvm
│   ├── go.sh                   # tarball to ~/.local/go
│   ├── rust.sh                 # rustup-init to ~/.cargo
│   ├── kitty.sh
│   ├── neovim.sh               # prebuilt release preferred, source build fallback
│   ├── clipboard.sh            # Linux: xclip + wl-clipboard; macOS: pngpaste
│   └── fonts.sh                # FiraCode + NerdFont symbols
├── dotfiles.sh                 # clone/update dotfiles + nvim config, safe checkout
├── docs/
│   └── superpowers/specs/      # this document and follow-ups
└── tests/
    └── docker/
        ├── ubuntu-22.04.Dockerfile
        ├── ubuntu-24.04.Dockerfile
        ├── debian-12.Dockerfile
        ├── fedora-40.Dockerfile
        ├── arch.Dockerfile
        └── run.sh
```

## 5. Architecture

### 5.1 Module responsibilities

Each unit has one purpose and a small public interface.

- **`lib/core.sh`** — shared logging (`log`, `info`, `success`, `error`, `warn`), strict-mode bootstrap (`set -Eeuo pipefail`), error trap that prints failing line + exit code, `DRY_RUN` global. No side effects on source.
- **`lib/detect.sh`** — populates globals `OS` (`linux`|`macos`), `DISTRO` (`debian`|`ubuntu`|`fedora`|`rhel`|`arch`|`manjaro`|`endeavouros`), `DISTRO_FAMILY` (`debian`|`rhel`|`arch`|`macos`), `ARCH` (`x86_64`|`arm64`|`aarch64`), `DISPLAY_SRV` (`x11`|`wayland`|`none`).
- **`lib/network.sh`** — probes connectivity by hitting GitHub and the package mirror; uses exit code, not response body, so HTTP/2 vs HTTP/1.1 doesn't matter.
- **`lib/sudo.sh`** — `probe_sudo` tries `sudo -n true`, then `sudo -v` once; sets `SUDO_MODE=full|userlocal`. `sudo_run` wraps a command with `sudo` if `SUDO_MODE=full`, errors out otherwise. Keepalive uses `trap EXIT` to kill its background PID; polls `kill -0 $$`.
- **`lib/github.sh`** — `github_latest_release_url <owner/repo> <asset-pattern>` resolves the latest release asset URL, prefers `jq` if present, falls back to `grep -oE`.
- **`lib/pkg/*.sh`** — adapter interface (see §5.2).
- **`installers/*.sh`** — each exports `<tool>_check` (returns 0 if installed) and `<tool>_install` (idempotent install). Files are self-contained: an installer is the single place that knows where its tool lives and how to verify it.
- **`dotfiles.sh`** — clones/updates `superbrobenji/dotfiles` and `superbrobenji/nvim`, performs safe checkout with backup of conflicts, creates `.local` override stubs.

### 5.2 Package-manager adapter interface

Every `lib/pkg/<mgr>.sh` exports the same four functions so installers stay distro-agnostic.

| Function | Behaviour |
|---|---|
| `pkg_install_system <pkg>...` | Install one or more system packages. Uses `sudo_run` if `SUDO_MODE=full`; returns non-zero in user-local mode so caller can fall back. |
| `pkg_query <pkg>` | Returns 0 if the package is *installed* (not merely available). |
| `pkg_update_index` | Refreshes the package index. Called once near the start of `install.sh`. No-op on `brew`. |
| `pkg_name_for <logical>` | Maps a logical name (e.g. `build-toolchain`, `clipboard-x11`, `fira-code`) to the distro-specific package name. Source of truth in `lib/pkg/names.sh`. |

`brew.sh` additionally exports `pkg_install_cask <name>` for `kitty`, `pngpaste`, and font formulae.

### 5.3 Logical name mapping (excerpt)

| Logical | apt | dnf | pacman | brew |
|---|---|---|---|---|
| `build-toolchain` | `build-essential` | `@development-tools` | `base-devel` | (Xcode CLT) |
| `clipboard-x11` | `xclip` | `xclip` | `xclip` | n/a |
| `clipboard-wayland` | `wl-clipboard` | `wl-clipboard` | `wl-clipboard` | n/a |
| `fira-code` | `fonts-firacode` | `fira-code-fonts` | `ttf-fira-code` | `font-fira-code` (cask) |
| `python3` | `python3 python3-pip python3-venv` | `python3 python3-pip` | `python python-pip` | `python@3` |
| `ripgrep` | `ripgrep` | `ripgrep` | `ripgrep` | `ripgrep` |
| `pngpaste` | n/a | n/a | n/a | `pngpaste` |

## 6. Install Flow

```
install.sh
├── parse_args                  # see §9
├── source lib/*                # core, detect, network, sudo, github
├── detect_platform             # populates OS / DISTRO / ARCH / DISPLAY_SRV
├── source lib/pkg/<adapter>    # picked by DISTRO_FAMILY
├── check_network               # abort if offline
├── probe_sudo                  # decides SUDO_MODE
├── pkg_update_index            # once
├── for tool in TOOL_ORDER:
│     if <tool>_check then skip, log "already installed"
│     else <tool>_install; on failure append to FAILED_TOOLS, continue
├── dotfiles.sh                 # see §7
├── post_install:
│     ├── chsh to zsh (if not skipped, zsh in /etc/shells)
│     ├── fc-cache -fv (if fonts installed)
│     ├── (cd ~/.config/nvim && npm install) for tree-sitter-cli
│     └── print summary, set exit code
```

### 6.1 Tool order

Order is governed by dependency direction.

1. basics (`curl wget unzip tar jq`) — needed by every download step. On macOS, `curl` ships with the OS; running `git` for the first time triggers the Xcode Command Line Tools installer prompt, which transitively provides `make`, `gcc/clang`, etc. The installer detects this with `xcode-select -p` and, if absent, runs `xcode-select --install` then waits for the user to complete the GUI prompt before continuing.
2. `git` — needed by clones
3. build-toolchain — needed by treesitter parsers, fzf-native, source builds
4. `python3` + `pip` — needed by Mason for many LSPs
5. `zsh` — needed before oh-my-zsh
6. `oh-my-zsh`
7. `tmux`
8. `fzf`
9. `ripgrep`
10. `nvm` → `node` (LTS) — nvm first, then `nvm install --lts`
11. `go` — tarball to `~/.local/go`
12. `rust` — rustup-init to `~/.cargo`, needed by avante.nvim and blink.cmp
13. `kitty` — brew cask on macOS; official installer on Linux + desktop integration
14. `neovim` — prebuilt release tarball preferred; build from source as fallback
15. `clipboard` — Linux only when `DISPLAY_SRV != none`; macOS adds `pngpaste`
16. `fonts` — FiraCode (pkg manager) + NerdFont symbols (release zip → `~/.local/share/fonts`)
17. dotfiles + nvim config (`dotfiles.sh`)

### 6.2 Failure policy

- A failure in basics, `git`, or build-toolchain is **fatal** — nothing else can proceed.
- Failures elsewhere are **recorded** and the run continues. Final summary lists failures; exit code is `2`.
- The full failing-tool log is in `~/.dev-env-installer.log`; stdout shows a one-liner per tool.

### 6.3 Sudo strategy (hybrid)

`SUDO_MODE=full` is the default on Linux when `sudo -v` succeeds. In this mode `sudo_run` prepends `sudo`. `SUDO_MODE=userlocal` is forced by `--no-sudo` or when sudo is refused. In user-local mode, installers that need sudo print a warning and skip (treesitter parsers, clipboard, system fonts may not work).

macOS is **always** `userlocal` for packages — Homebrew refuses sudo. `chsh` on macOS uses `dscl` which prompts via GUI; on Linux it edits `/etc/passwd` via `chsh` and may need sudo.

## 7. Dotfiles Handling

The dotfiles repo currently contains personal config; the machine has work overrides. Plain checkout would clobber work config.

### 7.1 Required upstream changes

These changes go to `superbrobenji/dotfiles`, not this installer, but the installer assumes they are present.

**`.zshrc`** — remove the `eval $(thefuck --alias)` line. Append:
```bash
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
```

**`.gitconfig`** — replace the `[user]`, `[gpg]`, `[commit]` blocks with `includeIf` directives:
```ini
[includeIf "gitdir:~/work/"]
  path = ~/.gitconfig.work
[includeIf "gitdir:~/projects/"]
  path = ~/.gitconfig.personal
```

### 7.2 Installer behaviour

1. **Ownership check** — if `~/.dotfiles` exists but is not owned by `$USER`, prompt to `chown -R $USER:$(id -gn) ~/.dotfiles` via sudo, or abort with a clear error. The current implementation has left this directory root-owned because the previous installer ran the bare-repo clone under sudo at some point.
2. **Clone or update** — bare-repo style: `git --git-dir="$HOME/.dotfiles" --work-tree="$HOME"`. If absent, clone with `--bare`. If present, `fetch` and `reset --hard origin/$DEFAULT_BRANCH` where `$DEFAULT_BRANCH` is resolved from `refs/remotes/origin/HEAD` (no hardcoded `main`).
3. **Safe checkout** — list files in the repo (`git ls-tree -r HEAD --name-only`). For each path that already exists in `$HOME`, differs from the repo version, and is *not* in the local-overrides whitelist, move it to `~/.dotfiles-backup-<unix-ts>/`. Then `git checkout -f`.
4. **Local override stubs** — create three files if missing, never overwrite:
   - `~/.zshrc.local` — placeholder comments suggesting `AWS_PROFILE`, `AVANTE_ANTHROPIC_API_KEY`, `command -v typo &>/dev/null && eval "$(typo init zsh)"`.
   - `~/.gitconfig.work` — placeholder for work identity.
   - `~/.gitconfig.personal` — placeholder for personal identity.
5. **Untracked-file config** — `git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config status.showUntrackedFiles no` (unchanged from current behaviour).
6. **Neovim config repo** — separate clone of `superbrobenji/nvim` into `~/.config/nvim`; same default-branch detection; backup-then-reset on update.

### 7.3 `typo` handling

`typo` is a manually-placed binary on the user's macOS machine with no package source identified. The installer **does not install it**. The local override stub guards the `typo init zsh` invocation with `command -v typo` so a missing `typo` does not break the shell.

## 8. Critical Bug Fixes

Defects in the current scripts that the rewrite must address.

| # | Bug | Fix |
|---|---|---|
| 1 | `OSTYPE` matching collapses every Linux distro into `apt-get` | Parse `/etc/os-release` for `ID` and `ID_LIKE`; select adapter by family |
| 2 | `curl ... \| bash >> log` masks the remote script's exit code | Download to a `mktemp` file, verify, `bash <file>`, propagate exit |
| 3 | `brew shellenv` evaluated in install function only — never persisted | Append shellenv stanza to `~/.zprofile` (macOS) or `~/.bashrc` (Linux/Homebrew); source in current process |
| 4 | `nvm` sourced once, lost on next installer | `ensure_nvm_loaded` helper sourced at the top of every nvm-dependent install function |
| 5 | Sudo keepalive subshell can outlive parent | `trap EXIT` kills the keepalive PID; loop checks `kill -0 $$` |
| 6 | ripgrep fallback assumes `.deb`/`dpkg -i` | GitHub release: download platform tarball, extract to `~/.local/bin/rg` — works everywhere |
| 7 | Network check requires literal `HTTP/2 200` | `curl -fsI --max-time 5 <url>` — rely on exit code |
| 8 | Kitty install conflates cask vs binary path | macOS: `brew install --cask kitty`. Linux: official installer + desktop-integration steps from nvim readme |
| 9 | Neovim built from source every run | Prefer GitHub release tarball; source build only if release missing for `$ARCH` |
| 10 | `git checkout -f` clobbers local dotfile edits | Backup-then-checkout, see §7.2 step 3 |
| 11 | Hardcoded `origin/main` | Resolve default branch via `git symbolic-ref refs/remotes/origin/HEAD` |
| 12 | `oh-my-zsh` install uses `KEEP_ZSHRC=yes` but dotfile checkout overrides anyway | Install omz **before** dotfiles checkout; let dotfiles `.zshrc` win |
| 13 | `cd -` prints path to stdout under strict mode | Use `pushd`/`popd` or `(cd dir && cmd)` subshells |
| 14 | `/tmp/neovim-src` collides on parallel runs | `mktemp -d` |
| 15 | Empty errors when sudo refused | Probe upfront, switch to `userlocal`, warn explicitly |

## 9. CLI

```
Usage: install.sh [FLAGS]

  -n, --dry-run         Show what would happen, change nothing
      --no-sudo         Force user-local mode; skip pkgs needing sudo
      --skip-fonts      Skip font install
      --skip-chsh       Don't change default shell to zsh
      --skip-dotfiles   Install deps only; don't touch dotfiles
      --only TOOL[,...] Install only listed tools
      --skip TOOL[,...] Skip listed tools
      --verbose         Tee full log to stdout (default: high-level only)
      --update          Force re-pull of dotfiles + nvim config repos
      --yes             Assume yes to all prompts (unattended)
  -h, --help            Show help
```

Exit codes:

| Code | Meaning |
|---|---|
| 0 | All deps installed or already present |
| 1 | Hard failure (network, missing critical prereq, sudo refused when required) |
| 2 | Partial: at least one non-critical tool failed (listed in summary) |

Output (default):

```
🔧 Dev Env Installer
📝 Log: ~/.dev-env-installer.log
🔍 Detected: macos arm64 / brew
🌐 Network: ok
🔐 Sudo: not required (macos)
─────────────────────────────────────────
[01/17] git              ✓ already installed
[02/17] basics           ✓ already installed
[03/17] build-toolchain  ✓ already installed
[04/17] python3          ⏵ installing... ✓
...
─────────────────────────────────────────
✅ 15 installed, 2 skipped, 0 failed
📋 Next steps:
   • Restart shell or `exec zsh`
   • Edit ~/.zshrc.local for work-specific exports
   • Open nvim — Mason auto-installs LSPs on first launch
```

## 10. Testing

### 10.1 Docker smoke tests (Linux)

A Dockerfile per supported distro version: `ubuntu-22.04`, `ubuntu-24.04`, `debian-12`, `fedora-40`, `arch`. Each builds an unprivileged user with passwordless sudo, copies the installer in, runs `install.sh --skip-fonts --skip-chsh`, then asserts:

- `command -v` succeeds for: `nvim`, `git`, `rg`, `fzf`, `zsh`, `tmux`, `node`, `go`, `cargo`.
- `nvim --version` runs without segfault.
- `/etc/shells` contains a zsh entry.
- `~/.dotfiles/.git` and `~/.config/nvim/init.lua` exist.

`tests/docker/run.sh` builds and runs all images, prints pass/fail per distro.

### 10.2 Idempotency test

Each Dockerfile runs `install.sh` twice. Second run must exit 0, install nothing, and report every tool as already installed.

### 10.3 Dry-run test

`install.sh --dry-run` followed by a snapshot diff (e.g. `dpkg -l > before; install.sh --dry-run; dpkg -l > after; diff before after`) must be empty.

### 10.4 macOS

No Docker. GitHub Actions `macos-latest` runner runs `install.sh --skip-fonts --skip-chsh --yes` and the same `command -v` assertions. Manual verification on the maintainer's machine before merging.

## 11. Open Questions / Follow-ups

- **`typo` source** — currently a manually-placed arm64 binary. If a canonical source is identified, add an installer module.
- **Upstream dotfiles edits** — §7.1 changes (`.zshrc` thefuck line removal, `.zshrc.local` source, `.gitconfig` includeIf split) must land before the installer is shipped, or the installer must patch them post-checkout. Default plan: land upstream first.
- **Nerd Font choice** — design assumes `NerdFontsSymbolsOnly.zip` from `ryanoasis/nerd-fonts`. If the user wants a full patched font (e.g. FiraCode Nerd Font), swap the asset.
- **Mason LSPs at first nvim launch** — assumed to "just work" because Mason auto-installs the `ensure_installed` list. If headless install in CI surfaces issues, may need a `nvim --headless +'MasonInstall ...' +qall` step.
