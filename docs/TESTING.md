# Testing

Two test layers: **unit tests** (bats, fast, no network) and **Docker integration tests** (full install smoke, requires Docker).

---

## Prerequisites

### For unit tests

- [shellcheck](https://github.com/koalaman/shellcheck) — static analysis
- bats and bats-assert are vendored under `tests/lib/` — no install needed

Install shellcheck:

```bash
# macOS
brew install shellcheck

# Debian/Ubuntu
sudo apt install shellcheck

# Fedora
sudo dnf install ShellCheck

# Arch
sudo pacman -S shellcheck
```

### For Docker integration tests

- [Docker](https://docs.docker.com/get-docker/) with the daemon running

---

## Running tests

### All checks (lint + unit)

```bash
make test
```

Runs shellcheck on every `.sh` file in the repo (excluding vendored `tests/lib/`), then runs all bats unit tests.

### Lint only

```bash
make lint
```

Runs `shellcheck -x` over all project shell scripts. Findings are printed with file and line number. The build fails on any warning or error.

### Unit tests only

```bash
make test-unit
```

Runs the full bats suite under `tests/unit/`. Each `.bats` file covers one module or installer.

### Run a single test file

```bash
tests/lib/bats/bin/bats tests/unit/test_core.bats
```

Useful when iterating on a specific module.

### Run a single test by name

```bash
tests/lib/bats/bin/bats --filter "log writes to file" tests/unit/test_core.bats
```

### Docker integration tests (cross-distro smoke)

```bash
make test-docker
```

Builds a Docker image for each supported distro, runs a full install with `--skip-fonts --skip-chsh --yes` inside it, then runs `tests/docker/assert.sh` to verify post-conditions. Reports PASS/FAIL per distro.

Tested distros:

| Image | Distro |
|-------|--------|
| `ubuntu-22.04` | Ubuntu 22.04 LTS (Jammy) |
| `ubuntu-24.04` | Ubuntu 24.04 LTS (Noble) |
| `debian-12` | Debian 12 (Bookworm) |
| `fedora-40` | Fedora 40 |
| `arch` | Arch Linux (rolling) |

Images are tagged `devenv-test-<distro>` and are rebuilt fresh on each run.

To test a single distro manually:

```bash
docker build -t devenv-test-ubuntu-24.04 \
  -f tests/docker/ubuntu-24.04.Dockerfile .

docker run --rm devenv-test-ubuntu-24.04
```

---

## Test layout

```
tests/
├── unit/
│   ├── helpers.bash                  # shared setup/teardown helpers
│   ├── fixtures/                     # mock data (fake os-release, fake API payloads)
│   ├── test_apt.bats                 # apt adapter
│   ├── test_brew.bats                # brew adapter
│   ├── test_core.bats                # logging (verbose/quiet), dry-run, is_dry_run
│   ├── test_detect.bats              # OS/distro/arch detection
│   ├── test_dnf.bats                 # dnf adapter
│   ├── test_dotfiles.bats            # clone, checkout, backup logic
│   ├── test_github.bats              # release URL resolver
│   ├── test_install.bats             # orchestration (arg parsing, --help)
│   ├── test_installer_basics.bats
│   ├── test_installer_build_toolchain.bats
│   ├── test_installer_clipboard.bats
│   ├── test_installer_fonts.bats
│   ├── test_installer_fzf.bats
│   ├── test_installer_git.bats
│   ├── test_installer_go.bats
│   ├── test_installer_kitty.bats
│   ├── test_installer_neovim.bats
│   ├── test_installer_claude.bats
│   ├── test_installer_node.bats
│   ├── test_installer_nvm.bats
│   ├── test_installer_ohmyzsh.bats
│   ├── test_installer_python3.bats
│   ├── test_installer_ripgrep.bats
│   ├── test_installer_rust.bats
│   ├── test_installer_tmux.bats
│   ├── test_installer_tree_sitter_cli.bats
│   ├── test_installer_zsh.bats
│   ├── test_names.bats               # logical-name → package-name map
│   ├── test_network.bats             # connectivity probe
│   ├── test_pacman.bats              # pacman adapter
│   ├── test_smoke.bats               # bats harness smoke test
│   └── test_sudo.bats                # sudo probe and keepalive
├── docker/
│   ├── run.sh                        # iterates distros, builds + runs each image
│   ├── assert.sh                     # post-install assertions run inside container
│   ├── ubuntu-22.04.Dockerfile
│   ├── ubuntu-24.04.Dockerfile
│   ├── debian-12.Dockerfile
│   ├── fedora-40.Dockerfile
│   └── arch.Dockerfile
└── lib/
    ├── bats/                         # bats test runner (vendored)
    └── bats-assert/                  # assertion helpers (vendored)
```

---

## Writing a new test

1. Create `tests/unit/test_<module>.bats`.
2. Source `helpers.bash` at the top:

```bash
# shellcheck disable=SC1091
load 'helpers'
```

3. Use standard bats + bats-assert syntax:

```bash
#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load helpers

setup() {
  load_lib core.sh
}

@test "my_function returns 0 on success" {
  run my_function
  assert_success
}

@test "my_function prints expected output" {
  run my_function
  assert_output "expected"
}
```

4. Run `make test` to confirm the new test is picked up and passes lint.

---

## CI

The test suite is designed to run in CI without modification:

```bash
make test        # lint + unit (no Docker required)
make test-docker # cross-distro (requires Docker daemon)
```

Set `DISTROS` in `tests/docker/run.sh` to adjust which distros are tested in CI.
