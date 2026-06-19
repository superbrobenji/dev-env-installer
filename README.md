# dev-env-installer

Single-command dev environment installer for macOS, Debian/Ubuntu, Fedora/RHEL, and Arch.

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/superbrobenji/dev-env-installer/main/bootstrap.sh | bash
```

Or clone first:

```bash
git clone https://github.com/superbrobenji/dev-env-installer ~/.dev-env-installer
~/.dev-env-installer/install.sh
```

## Flags

See `install.sh --help`.

## What it installs

git, curl/wget/unzip/tar/jq, build toolchain, python3+pip, zsh+oh-my-zsh,
tmux, fzf, ripgrep, nvm + node LTS, go (user-local), rust via rustup, kitty,
neovim (prebuilt release), Linux clipboard tools or macOS pngpaste,
FiraCode + NerdFont symbols, plus dotfiles + nvim config.

## Tests

```bash
make test         # shellcheck + bats unit tests
make test-docker  # full cross-distro smoke (requires Docker)
```

## Layout

- `bootstrap.sh` — `curl | bash` entry.
- `install.sh` — orchestrator.
- `lib/` — shared helpers, including per-distro package-manager adapters.
- `installers/` — one module per tool.
- `dotfiles.sh` — safe clone-and-checkout of dotfiles + nvim config.
- `tests/` — bats unit tests and Docker integration tests.
