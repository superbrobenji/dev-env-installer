# dev-env-installer

Single-command dev environment installer for macOS, Debian/Ubuntu, Fedora/RHEL, and Arch.

---

## Quick start

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/superbrobenji/dev-env-installer/main/bootstrap.sh | bash
```

The bootstrap script clones the repo to `~/.dev-env-installer` and runs `install.sh`. Any flags you pass are forwarded:

```bash
curl -fsSL https://raw.githubusercontent.com/superbrobenji/dev-env-installer/main/bootstrap.sh | bash -s -- --dry-run
```

### Clone and run

```bash
git clone https://github.com/superbrobenji/dev-env-installer ~/.dev-env-installer
~/.dev-env-installer/install.sh
```

---

## Step-by-step usage

### 1. Preview what will happen (dry run)

```bash
install.sh --dry-run
```

Prints every action that would be taken without changing anything on disk.

### 2. Full install

```bash
install.sh
```

Detects your platform, probes sudo, updates the package index, then installs each tool in order. Already-installed tools are skipped automatically (idempotent).

### 3. Install a subset of tools

```bash
# Only install ripgrep and neovim
install.sh --only ripgrep,neovim

# Install everything except fonts and kitty
install.sh --skip fonts,kitty
```

Tool names match the identifiers in the [What's installed](#whats-installed) table below.

### 4. Skip dotfiles sync

```bash
install.sh --skip-dotfiles
```

Installs all tools but does not clone or sync dotfiles or the nvim config.

### 5. Skip shell change

```bash
install.sh --skip-chsh
```

Does not call `chsh` to set zsh as the default shell.

### 6. Linux without sudo

```bash
install.sh --no-sudo
```

Skips any package that requires system-level install. Tools with user-local fallbacks (ripgrep → `~/.local/bin/rg`, Go → `~/.local/go`, Neovim → `~/.local/bin/nvim`) still install.

### 7. Verbose output

```bash
install.sh --verbose
```

By default, detailed `log` messages go only to `~/.dev-env-installer.log`. `--verbose` tees them to stdout too, useful for debugging or CI.

### 8. Unattended / scripted install

```bash
install.sh --yes --skip-chsh --skip-fonts
```

`--yes` suppresses any interactive prompts. Combine with `--skip-chsh` and `--skip-fonts` for headless environments.

### 9. Custom dotfiles repo

```bash
DOTFILES_REPO=https://github.com/yourname/dotfiles.git \
NVIM_REPO=https://github.com/yourname/nvim.git \
  install.sh
```

> **Note:** Dotfiles are always fetched and synced on every run. There is no "skip update" mode — re-running is safe because `cmp` skips identical files and conflicts are backed up.

---

## Flags

| Flag | Description |
|------|-------------|
| `-n`, `--dry-run` | Show what would happen, change nothing |
| `--no-sudo` | Force user-local mode; skip packages that need sudo |
| `--only TOOL[,...]` | Install only the listed tools (comma-separated) |
| `--skip TOOL[,...]` | Skip the listed tools (comma-separated) |
| `--skip-fonts` | Skip font installation |
| `--skip-chsh` | Don't change the default shell to zsh |
| `--skip-dotfiles` | Install tools only; don't touch dotfiles |
| `--verbose` | Print all `log` output to stdout (default: file only) |
| `--yes` | Accept all defaults; suppresses any interactive prompts |
| `-h`, `--help` | Show help |

---

## What's installed

Tools are installed in the order shown. The first three (`basics`, `git`, `build_toolchain`) are **fatal** — a failure aborts the run. All others are best-effort and logged without aborting.

| Tool name | What it installs | Install location | Notes |
|-----------|-----------------|------------------|-------|
| `basics` | curl, wget, unzip, tar, jq | System (via package manager) | Required by most other installers |
| `git` | git | System | |
| `build_toolchain` | C compiler + make | System | `build-essential` / `@development-tools` / `base-devel` / Xcode CLT |
| `python3` | Python 3 + pip + venv | System | |
| `zsh` | zsh shell | System | |
| `ohmyzsh` | Oh My Zsh framework | `~/.oh-my-zsh` | |
| `tmux` | tmux terminal multiplexer | System | |
| `fzf` | fzf fuzzy finder | System or `~/.fzf` | Falls back to git clone if pkg unavailable |
| `ripgrep` | rg (ripgrep) | System or `~/.local/bin/rg` | Falls back to GitHub release tarball |
| `nvm` | Node Version Manager | `~/.nvm` | |
| `node` | Node.js LTS | via nvm | Installed via `nvm install --lts` |
| `go` | Go toolchain (latest) | `~/.local/go` | User-local; no sudo required |
| `rust` | Rust + cargo via rustup | `~/.cargo` | `rustup` installer; user-local |
| `kitty` | kitty terminal emulator | System / app bundle / `~/.local/kitty.app` | |
| `neovim` | Neovim (latest release) | System or `~/.local/bin/nvim` | Prebuilt tarball; source build fallback |
| `clipboard` | Clipboard tools | System | Linux: xclip + wl-clipboard; macOS: pngpaste |
| `fonts` | FiraCode + NerdFont symbols | `~/.local/share/fonts` or `~/Library/Fonts` | Homebrew cask on macOS |

After tool installation, the installer:
- Syncs your dotfiles repo to `~/.dotfiles` and mirrors tracked files to `$HOME`
- Clones your nvim config to `~/.config/nvim`
- Creates stub files (`~/.zshrc.local`, `~/.gitconfig.work`, `~/.gitconfig.personal`) if absent
- Changes the default shell to zsh (unless `--skip-chsh`)
- Runs `npm install` in `~/.config/nvim` for tree-sitter-cli if node is available

---

## Supported platforms

| Platform | Package manager | Tested distros |
|----------|----------------|----------------|
| macOS (Apple Silicon + Intel) | Homebrew (auto-installed) | macOS 13+ |
| Debian / Ubuntu | apt | Ubuntu 22.04, Ubuntu 24.04, Debian 12 |
| Fedora / RHEL / Rocky / AlmaLinux | dnf | Fedora 40 |
| Arch / Manjaro / EndeavourOS | pacman | Arch (rolling) |

> **Not supported:** openSUSE, Alpine, NixOS, BSD, Windows/WSL.

---

## Idempotency

Re-running the installer on a system that already has tools installed is safe. Each tool has a `_check` function; if it passes, the tool is skipped. Dotfile sync uses `cmp` to avoid overwriting files that are already identical.

Conflicting dotfiles are moved to `~/.dotfiles-backup-<timestamp>` before the repo copy is applied. Files listed as local overrides (`.zshrc.local`, `.gitconfig.work`, `.gitconfig.personal`) are never overwritten.

---

## Tests

See [docs/TESTING.md](docs/TESTING.md) for full instructions.

```bash
make test         # shellcheck lint + bats unit tests
make test-docker  # full cross-distro smoke tests (requires Docker)
```

---

## Layout

```
dev-env-installer/
├── bootstrap.sh          # curl|bash entry — clones repo, execs install.sh
├── install.sh            # orchestrator: detect → sudo → install loop → dotfiles
├── dotfiles.sh           # safe dotfile clone and checkout
├── lib/
│   ├── core.sh           # logging, strict mode, dry-run helper
│   ├── detect.sh         # OS/distro/arch/display-server detection
│   ├── network.sh        # connectivity probe
│   ├── sudo.sh           # sudo probe, keepalive, sudo_run wrapper
│   ├── github.sh         # latest-release URL resolver (jq + grep fallback)
│   └── pkg/
│       ├── names.sh      # logical name → distro package name map
│       ├── apt.sh        # Debian/Ubuntu adapter
│       ├── dnf.sh        # Fedora/RHEL adapter
│       ├── pacman.sh     # Arch adapter
│       └── brew.sh       # macOS Homebrew adapter
├── installers/           # one file per tool: <tool>_check + <tool>_install
├── tests/
│   ├── unit/             # bats unit tests (one file per module/installer)
│   │   ├── helpers.bash  # shared test helpers
│   │   ├── fixtures/     # mock data (fake os-release, fake API payloads)
│   │   └── test_*.bats
│   ├── docker/           # Dockerfiles + run.sh for cross-distro smoke tests
│   └── lib/              # bats + bats-assert (vendored)
└── docs/
    └── TESTING.md        # detailed testing guide
```
