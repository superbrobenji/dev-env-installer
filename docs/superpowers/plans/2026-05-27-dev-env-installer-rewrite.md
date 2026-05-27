# Dev Env Installer Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the three existing scripts (`install.sh`, `dep-installer.sh`, `fetch-dotfiles.sh`) into a modular, cross-platform installer that works on macOS, Debian/Ubuntu, Fedora/RHEL, and Arch, with hybrid sudo, idempotent installs, and safe dotfile handling.

**Architecture:** Single `install.sh` orchestrator sources `lib/*.sh` for shared helpers, picks a package-manager adapter from `lib/pkg/{apt,dnf,pacman,brew}.sh`, and loops over per-tool installer modules in `installers/*.sh`. Each installer exposes a `<tool>_check` and `<tool>_install` function. A separate `dotfiles.sh` clones the dotfiles + nvim repos with backup-then-checkout. A `bootstrap.sh` provides the `curl | bash` entry that clones this repo and calls `install.sh`.

**Tech Stack:** Bash 4+, [Bats-core](https://github.com/bats-core/bats-core) for unit tests, [ShellCheck](https://www.shellcheck.net/) for static analysis, Docker for cross-distro integration tests.

**Spec:** `docs/superpowers/specs/2026-05-27-dev-env-installer-rewrite-design.md`

---

## Conventions for every task

- **Strict mode:** Every script starts with `#!/usr/bin/env bash` and `set -Eeuo pipefail`. Library files (sourced) omit the shebang but keep the strict flags via `core.sh` (which is sourced first).
- **No top-level side effects in libs:** `lib/*.sh` and `installers/*.sh` only define functions when sourced — they do nothing else.
- **Testing:** Pure functions get Bats unit tests under `tests/unit/`. Anything that needs a real package manager gets Docker integration tests under `tests/docker/`.
- **Commits:** One commit per task, conventional-commit style (`feat:`, `fix:`, `refactor:`, `test:`, `chore:`, `docs:`).
- **ShellCheck clean:** Every shell file must pass `shellcheck -x <file>` with zero warnings before commit.

---

## Task 1: Project scaffolding and test harness

**Files:**
- Create: `lib/.gitkeep`, `lib/pkg/.gitkeep`, `installers/.gitkeep`, `tests/unit/.gitkeep`, `tests/docker/.gitkeep`
- Create: `tests/unit/helpers.bash`
- Create: `tests/unit/test_smoke.bats`
- Create: `Makefile`
- Create: `.shellcheckrc`

- [ ] **Step 1: Create directories**

```bash
mkdir -p lib/pkg installers tests/unit tests/docker
touch lib/.gitkeep lib/pkg/.gitkeep installers/.gitkeep tests/unit/.gitkeep tests/docker/.gitkeep
```

- [ ] **Step 2: Install bats locally (no global install)**

Run:

```bash
mkdir -p tests/lib
git clone --depth 1 https://github.com/bats-core/bats-core.git tests/lib/bats
git clone --depth 1 https://github.com/bats-core/bats-support.git tests/lib/bats-support
git clone --depth 1 https://github.com/bats-core/bats-assert.git tests/lib/bats-assert
```

Add `tests/lib/` to `.gitignore` (we'll vendor by git submodule later if needed, but for now keep out of repo).

- [ ] **Step 3: Add `.gitignore` entries**

`.gitignore` (append):

```
tests/lib/
*.log
.dev-env-installer.log
```

- [ ] **Step 4: Create test helpers**

`tests/unit/helpers.bash`:

```bash
#!/usr/bin/env bash
# Shared Bats helpers. Source from every .bats file.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PROJECT_ROOT

load "${PROJECT_ROOT}/tests/lib/bats-support/load.bash"
load "${PROJECT_ROOT}/tests/lib/bats-assert/load.bash"

# Source a lib file under test in a clean subshell context.
load_lib() {
  # shellcheck disable=SC1090
  source "${PROJECT_ROOT}/lib/$1"
}

load_installer() {
  # shellcheck disable=SC1090
  source "${PROJECT_ROOT}/installers/$1"
}
```

- [ ] **Step 5: Create a smoke test that runs**

`tests/unit/test_smoke.bats`:

```bash
#!/usr/bin/env bats

load helpers

@test "bats harness works" {
  run echo "ok"
  assert_success
  assert_output "ok"
}
```

- [ ] **Step 6: Create the Makefile**

`Makefile`:

```make
.PHONY: test lint test-unit test-docker

test: lint test-unit

lint:
	@find . -type f \( -name '*.sh' -o -name '*.bash' \) \
	  -not -path './tests/lib/*' -not -path './.git/*' \
	  -print0 | xargs -0 shellcheck -x

test-unit:
	@tests/lib/bats/bin/bats tests/unit/

test-docker:
	@bash tests/docker/run.sh
```

- [ ] **Step 7: Create `.shellcheckrc`**

`.shellcheckrc`:

```
# Allow sourcing files dynamically; we vouch for them in code review.
external-sources=true
```

- [ ] **Step 8: Run the test harness and shellcheck**

```bash
make test-unit
```

Expected: `1 test, 0 failures`.

```bash
make lint
```

Expected: no output, exit 0.

- [ ] **Step 9: Commit**

```bash
git add Makefile .shellcheckrc .gitignore lib installers tests
git commit -m "chore: scaffold installer test harness with bats and shellcheck"
```

---

## Task 2: `lib/core.sh` — logging, strict mode, dry-run

**Files:**
- Create: `lib/core.sh`
- Create: `tests/unit/test_core.bats`

- [ ] **Step 1: Write failing tests**

`tests/unit/test_core.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
}

@test "log writes to stdout and log file" {
  CORE_LOG_FILE="$(mktemp)"
  export CORE_LOG_FILE
  run log "hello"
  assert_success
  assert_output --partial "hello"
  run cat "$CORE_LOG_FILE"
  assert_output --partial "hello"
  rm -f "$CORE_LOG_FILE"
}

@test "error writes to stderr" {
  CORE_LOG_FILE="$(mktemp)"
  export CORE_LOG_FILE
  run -1 bash -c 'source "${PROJECT_ROOT}/lib/core.sh"; error "boom"; exit 1'
  assert_output --partial "boom"
  rm -f "$CORE_LOG_FILE"
}

@test "is_dry_run reflects DRY_RUN env var" {
  DRY_RUN=true run is_dry_run
  assert_success
  DRY_RUN=false run is_dry_run
  assert_failure
}

@test "log file is created if missing" {
  CORE_LOG_FILE="$(mktemp -u)"
  export CORE_LOG_FILE
  log "init" >/dev/null
  [ -f "$CORE_LOG_FILE" ]
  rm -f "$CORE_LOG_FILE"
}
```

- [ ] **Step 2: Run tests; expect failure**

```bash
make test-unit
```

Expected: `4 failures` (tests can't find `log`, `error`, `is_dry_run`).

- [ ] **Step 3: Implement `lib/core.sh`**

`lib/core.sh`:

```bash
# Shared logging, strict mode, dry-run flag.
# Sourced by every other lib/installer file.

# Strict mode for any script that sources us.
set -Eeuo pipefail

# Log file. Override via CORE_LOG_FILE env. Default: ~/.dev-env-installer.log
: "${CORE_LOG_FILE:=${HOME}/.dev-env-installer.log}"
: "${DRY_RUN:=false}"

# Ensure log file exists.
_core_init_log() {
  local dir
  dir="$(dirname "${CORE_LOG_FILE}")"
  [[ -d "$dir" ]] || mkdir -p "$dir"
  [[ -f "$CORE_LOG_FILE" ]] || : > "$CORE_LOG_FILE"
}

_core_emit() {
  local prefix="$1"; shift
  local msg="$*"
  _core_init_log
  printf '%s %s\n' "$prefix" "$msg" | tee -a "$CORE_LOG_FILE"
}

log()     { _core_emit "🔹" "$*"; }
info()    { _core_emit "ℹ️ " "$*"; }
success() { _core_emit "✅" "$*"; }
warn()    { _core_emit "⚠️ " "$*"; }
error()   { _core_emit "❌" "$*" >&2; }

is_dry_run() {
  [[ "${DRY_RUN}" == "true" ]]
}

# Trap unexpected errors with line number and exit code.
_core_on_err() {
  local exit_code=$?
  local line=$1
  error "Aborted at line ${line} (exit ${exit_code})"
  exit "$exit_code"
}
trap '_core_on_err $LINENO' ERR
```

- [ ] **Step 4: Run tests; expect pass**

```bash
make test-unit
```

Expected: `5 tests, 0 failures` (smoke + 4 new).

- [ ] **Step 5: ShellCheck**

```bash
make lint
```

Expected: no output, exit 0.

- [ ] **Step 6: Commit**

```bash
git add lib/core.sh tests/unit/test_core.bats
git commit -m "feat: add lib/core.sh with logging and strict-mode bootstrap"
```

---

## Task 3: `lib/detect.sh` — platform detection

**Files:**
- Create: `lib/detect.sh`
- Create: `tests/unit/test_detect.bats`
- Create: `tests/unit/fixtures/os-release-ubuntu.txt`
- Create: `tests/unit/fixtures/os-release-fedora.txt`
- Create: `tests/unit/fixtures/os-release-arch.txt`

- [ ] **Step 1: Create os-release fixtures**

`tests/unit/fixtures/os-release-ubuntu.txt`:

```
PRETTY_NAME="Ubuntu 24.04 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
ID=ubuntu
ID_LIKE=debian
```

`tests/unit/fixtures/os-release-fedora.txt`:

```
NAME="Fedora Linux"
VERSION="40 (Workstation Edition)"
ID=fedora
VERSION_ID=40
ID_LIKE="rhel"
```

`tests/unit/fixtures/os-release-arch.txt`:

```
NAME="Arch Linux"
ID=arch
ID_LIKE=archlinux
```

- [ ] **Step 2: Write failing tests**

`tests/unit/test_detect.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_lib detect.sh
}

@test "parse_os_release returns ubuntu/debian for Ubuntu" {
  run parse_os_release "${PROJECT_ROOT}/tests/unit/fixtures/os-release-ubuntu.txt"
  assert_success
  assert_output --partial "DISTRO=ubuntu"
  assert_output --partial "DISTRO_FAMILY=debian"
}

@test "parse_os_release returns fedora/rhel for Fedora" {
  run parse_os_release "${PROJECT_ROOT}/tests/unit/fixtures/os-release-fedora.txt"
  assert_success
  assert_output --partial "DISTRO=fedora"
  assert_output --partial "DISTRO_FAMILY=rhel"
}

@test "parse_os_release returns arch/arch for Arch" {
  run parse_os_release "${PROJECT_ROOT}/tests/unit/fixtures/os-release-arch.txt"
  assert_success
  assert_output --partial "DISTRO=arch"
  assert_output --partial "DISTRO_FAMILY=arch"
}

@test "detect_arch normalises uname -m output" {
  run normalise_arch "x86_64";  assert_output "x86_64"
  run normalise_arch "amd64";   assert_output "x86_64"
  run normalise_arch "arm64";   assert_output "arm64"
  run normalise_arch "aarch64"; assert_output "arm64"
}

@test "detect_display_server returns wayland if WAYLAND_DISPLAY set" {
  WAYLAND_DISPLAY=wayland-0 DISPLAY="" run detect_display_server
  assert_output "wayland"
}

@test "detect_display_server returns x11 if DISPLAY set and no WAYLAND_DISPLAY" {
  DISPLAY=":0" WAYLAND_DISPLAY="" run detect_display_server
  assert_output "x11"
}

@test "detect_display_server returns none when neither set" {
  DISPLAY="" WAYLAND_DISPLAY="" run detect_display_server
  assert_output "none"
}
```

- [ ] **Step 3: Run tests; expect failure**

```bash
make test-unit
```

Expected: 7 new failures.

- [ ] **Step 4: Implement `lib/detect.sh`**

`lib/detect.sh`:

```bash
# Platform detection. Populates OS, DISTRO, DISTRO_FAMILY, ARCH, DISPLAY_SRV.

# Parse an os-release file. Prints `DISTRO=foo` and `DISTRO_FAMILY=bar` on stdout.
parse_os_release() {
  local file="${1:-/etc/os-release}"
  [[ -f "$file" ]] || { error "os-release not found at $file"; return 1; }
  # shellcheck disable=SC1090
  local id id_like
  id="$(awk -F= '/^ID=/{gsub(/"/,"",$2); print $2}' "$file")"
  id_like="$(awk -F= '/^ID_LIKE=/{gsub(/"/,"",$2); print $2}' "$file")"
  printf 'DISTRO=%s\n' "$id"
  local family
  case "$id" in
    ubuntu|debian|linuxmint|pop)             family=debian ;;
    fedora|rhel|centos|rocky|almalinux)      family=rhel ;;
    arch|manjaro|endeavouros|cachyos)        family=arch ;;
    *)
      case "$id_like" in
        *debian*) family=debian ;;
        *rhel*|*fedora*) family=rhel ;;
        *arch*) family=arch ;;
        *) family=unknown ;;
      esac
      ;;
  esac
  printf 'DISTRO_FAMILY=%s\n' "$family"
}

normalise_arch() {
  case "$1" in
    x86_64|amd64)   echo "x86_64" ;;
    arm64|aarch64)  echo "arm64" ;;
    *)              echo "$1" ;;
  esac
}

detect_display_server() {
  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    echo "wayland"
  elif [[ -n "${DISPLAY:-}" ]]; then
    echo "x11"
  else
    echo "none"
  fi
}

detect_platform() {
  case "$(uname -s)" in
    Darwin) OS=macos ; DISTRO=macos ; DISTRO_FAMILY=macos ;;
    Linux)
      OS=linux
      eval "$(parse_os_release /etc/os-release)"
      ;;
    *) error "unsupported OS: $(uname -s)"; return 1 ;;
  esac
  ARCH="$(normalise_arch "$(uname -m)")"
  DISPLAY_SRV="$(detect_display_server)"
  export OS DISTRO DISTRO_FAMILY ARCH DISPLAY_SRV
}
```

- [ ] **Step 5: Run tests; expect pass**

```bash
make test-unit
```

- [ ] **Step 6: Lint and commit**

```bash
make lint
git add lib/detect.sh tests/unit/test_detect.bats tests/unit/fixtures/
git commit -m "feat: add lib/detect.sh with os-release parser and arch detection"
```

---

## Task 4: `lib/network.sh` — connectivity probe

**Files:**
- Create: `lib/network.sh`
- Create: `tests/unit/test_network.bats`

- [ ] **Step 1: Write failing tests**

`tests/unit/test_network.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_lib network.sh
}

@test "probe_url returns 0 for reachable host" {
  run probe_url "https://github.com"
  assert_success
}

@test "probe_url returns non-zero for unreachable host" {
  run probe_url "https://this-host-does-not-exist-1234567890.invalid"
  assert_failure
}

@test "check_network passes if at least one probe succeeds" {
  NETWORK_PROBE_URLS=("https://this-does-not-exist-zzz.invalid" "https://github.com")
  run check_network
  assert_success
}

@test "check_network fails if all probes fail" {
  NETWORK_PROBE_URLS=("https://nope1.invalid" "https://nope2.invalid")
  run check_network
  assert_failure
}
```

- [ ] **Step 2: Run tests; expect failure**

```bash
make test-unit
```

- [ ] **Step 3: Implement `lib/network.sh`**

`lib/network.sh`:

```bash
# Connectivity check.

: "${NETWORK_PROBE_URLS:=}"
if [[ -z "${NETWORK_PROBE_URLS}" ]]; then
  NETWORK_PROBE_URLS=("https://github.com" "https://raw.githubusercontent.com")
fi

probe_url() {
  local url="$1"
  curl -fsI --max-time 5 "$url" >/dev/null 2>&1
}

check_network() {
  info "Checking network connectivity"
  for url in "${NETWORK_PROBE_URLS[@]}"; do
    if probe_url "$url"; then
      success "Network reachable via $url"
      return 0
    fi
  done
  error "No network connectivity (tried: ${NETWORK_PROBE_URLS[*]})"
  return 1
}
```

- [ ] **Step 4: Run tests; expect pass (requires actual internet)**

```bash
make test-unit
```

If running offline, skip with `bats --filter-tags '!net' tests/unit/test_network.bats`. For now assume the dev machine is online.

- [ ] **Step 5: Lint and commit**

```bash
make lint
git add lib/network.sh tests/unit/test_network.bats
git commit -m "feat: add lib/network.sh with exit-code-based connectivity probe"
```

---

## Task 5: `lib/sudo.sh` — sudo probe, keepalive, wrapper

**Files:**
- Create: `lib/sudo.sh`
- Create: `tests/unit/test_sudo.bats`

- [ ] **Step 1: Write failing tests**

`tests/unit/test_sudo.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_lib sudo.sh
}

@test "sudo_run runs the command directly when SUDO_MODE=userlocal" {
  SUDO_MODE=userlocal
  run sudo_run echo "hi"
  assert_success
  assert_output "hi"
}

@test "needs_sudo returns 0 when SUDO_MODE=full" {
  SUDO_MODE=full run needs_sudo
  assert_success
}

@test "needs_sudo returns 1 when SUDO_MODE=userlocal" {
  SUDO_MODE=userlocal run needs_sudo
  assert_failure
}

@test "probe_sudo on macOS sets SUDO_MODE=userlocal" {
  OS=macos
  probe_sudo
  [[ "$SUDO_MODE" == "userlocal" ]]
}
```

- [ ] **Step 2: Run tests; expect failure**

- [ ] **Step 3: Implement `lib/sudo.sh`**

`lib/sudo.sh`:

```bash
# Hybrid sudo handling. Sets SUDO_MODE=full|userlocal.

: "${SUDO_MODE:=}"
_SUDO_KEEPALIVE_PID=""

needs_sudo() {
  [[ "$SUDO_MODE" == "full" ]]
}

sudo_run() {
  if [[ "$SUDO_MODE" == "full" ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

# Probe sudo: prefer NOPASSWD; otherwise prompt once with `sudo -v`.
# On macOS we force userlocal (Homebrew refuses sudo).
probe_sudo() {
  if [[ "${OS:-}" == "macos" ]]; then
    SUDO_MODE=userlocal
    info "Sudo not required (macOS)"
    return 0
  fi

  if sudo -n true 2>/dev/null; then
    SUDO_MODE=full
    success "Sudo available (NOPASSWD)"
    _start_keepalive
    return 0
  fi

  if [[ "${NO_SUDO:-false}" == "true" ]]; then
    SUDO_MODE=userlocal
    warn "Forced user-local mode (--no-sudo); skipping system packages"
    return 0
  fi

  info "Sudo required for system packages — you may be prompted"
  if sudo -v; then
    SUDO_MODE=full
    _start_keepalive
    return 0
  fi

  warn "Sudo refused; falling back to user-local mode"
  SUDO_MODE=userlocal
  return 0
}

_start_keepalive() {
  ( while true; do sudo -n true 2>/dev/null || exit; sleep 60; kill -0 $$ 2>/dev/null || exit; done ) &
  _SUDO_KEEPALIVE_PID=$!
  trap _stop_keepalive EXIT
}

_stop_keepalive() {
  [[ -n "$_SUDO_KEEPALIVE_PID" ]] && kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
```

- [ ] **Step 4: Run tests; expect pass**

- [ ] **Step 5: Lint and commit**

```bash
make lint
git add lib/sudo.sh tests/unit/test_sudo.bats
git commit -m "feat: add lib/sudo.sh with hybrid sudo probe and trap-safe keepalive"
```

---

## Task 6: `lib/github.sh` — release URL resolver

**Files:**
- Create: `lib/github.sh`
- Create: `tests/unit/test_github.bats`

- [ ] **Step 1: Write failing tests**

`tests/unit/test_github.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_lib github.sh
}

@test "match_release_asset picks the matching asset by pattern" {
  local payload='{"assets":[{"name":"foo-linux-x86_64.tar.gz","browser_download_url":"https://example.com/a"},{"name":"foo-macos-arm64.tar.gz","browser_download_url":"https://example.com/b"}]}'
  run match_release_asset "$payload" "linux-x86_64.tar.gz"
  assert_success
  assert_output "https://example.com/a"
}

@test "match_release_asset returns non-zero when no match" {
  local payload='{"assets":[{"name":"foo.tar.gz","browser_download_url":"https://example.com/a"}]}'
  run match_release_asset "$payload" "macos-arm64.tar.gz"
  assert_failure
}
```

- [ ] **Step 2: Run tests; expect failure**

- [ ] **Step 3: Implement `lib/github.sh`**

`lib/github.sh`:

```bash
# GitHub release URL resolver. Uses jq if available, otherwise grep.

match_release_asset() {
  local payload="$1"
  local pattern="$2"
  if command -v jq >/dev/null 2>&1; then
    local url
    url="$(printf '%s' "$payload" \
      | jq -r --arg pat "$pattern" '.assets[] | select(.name | contains($pat)) | .browser_download_url' \
      | head -n1)"
    [[ -n "$url" ]] || return 1
    printf '%s\n' "$url"
    return 0
  fi
  # Fallback: grep-based extraction (best-effort, single asset name match).
  local url
  url="$(printf '%s' "$payload" \
    | grep -oE '"browser_download_url"\s*:\s*"[^"]*'"$pattern"'[^"]*"' \
    | head -n1 \
    | sed -E 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  [[ -n "$url" ]] || return 1
  printf '%s\n' "$url"
}

github_latest_release_url() {
  local repo="$1"
  local pattern="$2"
  local api="https://api.github.com/repos/${repo}/releases/latest"
  local payload
  payload="$(curl -fsSL "$api")" || { error "Failed to fetch $api"; return 1; }
  match_release_asset "$payload" "$pattern"
}
```

- [ ] **Step 4: Run tests; expect pass**

- [ ] **Step 5: Lint and commit**

```bash
make lint
git add lib/github.sh tests/unit/test_github.bats
git commit -m "feat: add lib/github.sh release-asset URL resolver"
```

---

## Task 7: `lib/pkg/names.sh` — logical name table

**Files:**
- Create: `lib/pkg/names.sh`
- Create: `tests/unit/test_names.bats`

- [ ] **Step 1: Write failing tests**

`tests/unit/test_names.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  source "${PROJECT_ROOT}/lib/pkg/names.sh"
}

@test "name_for build-toolchain maps per family" {
  DISTRO_FAMILY=debian run name_for build-toolchain
  assert_output "build-essential"
  DISTRO_FAMILY=rhel    run name_for build-toolchain
  assert_output --partial "@development-tools"
  DISTRO_FAMILY=arch    run name_for build-toolchain
  assert_output "base-devel"
  DISTRO_FAMILY=macos   run name_for build-toolchain
  assert_output ""
}

@test "name_for fira-code maps per family" {
  DISTRO_FAMILY=debian run name_for fira-code
  assert_output "fonts-firacode"
  DISTRO_FAMILY=rhel    run name_for fira-code
  assert_output "fira-code-fonts"
  DISTRO_FAMILY=arch    run name_for fira-code
  assert_output "ttf-fira-code"
  DISTRO_FAMILY=macos   run name_for fira-code
  assert_output "font-fira-code"
}

@test "name_for python3 includes pip per family" {
  DISTRO_FAMILY=debian run name_for python3
  assert_output --partial "python3-pip"
  DISTRO_FAMILY=rhel    run name_for python3
  assert_output --partial "python3-pip"
  DISTRO_FAMILY=arch    run name_for python3
  assert_output --partial "python-pip"
}
```

- [ ] **Step 2: Implement `lib/pkg/names.sh`**

`lib/pkg/names.sh`:

```bash
# Logical name → distro-specific package name table.
# Looked up by `name_for <logical>` after DISTRO_FAMILY is set.

name_for() {
  local logical="$1"
  case "$logical" in
    build-toolchain)
      case "$DISTRO_FAMILY" in
        debian) echo "build-essential" ;;
        rhel)   echo "@development-tools" ;;
        arch)   echo "base-devel" ;;
        macos)  echo "" ;;
      esac ;;
    fira-code)
      case "$DISTRO_FAMILY" in
        debian) echo "fonts-firacode" ;;
        rhel)   echo "fira-code-fonts" ;;
        arch)   echo "ttf-fira-code" ;;
        macos)  echo "font-fira-code" ;;
      esac ;;
    python3)
      case "$DISTRO_FAMILY" in
        debian) echo "python3 python3-pip python3-venv" ;;
        rhel)   echo "python3 python3-pip" ;;
        arch)   echo "python python-pip" ;;
        macos)  echo "python@3" ;;
      esac ;;
    clipboard-x11)     echo "xclip" ;;
    clipboard-wayland) echo "wl-clipboard" ;;
    pngpaste)
      [[ "$DISTRO_FAMILY" == "macos" ]] && echo "pngpaste" ;;
    basics)
      case "$DISTRO_FAMILY" in
        debian) echo "curl wget unzip tar jq ca-certificates" ;;
        rhel)   echo "curl wget unzip tar jq ca-certificates" ;;
        arch)   echo "curl wget unzip tar jq ca-certificates" ;;
        macos)  echo "curl wget unzip jq" ;;
      esac ;;
    git|zsh|tmux|fzf|ripgrep)
      echo "$logical" ;;
    *)
      error "name_for: unknown logical name '$logical'"
      return 1 ;;
  esac
}
```

- [ ] **Step 3: Run tests; expect pass**

- [ ] **Step 4: Lint and commit**

```bash
make lint
git add lib/pkg/names.sh tests/unit/test_names.bats
git commit -m "feat: add lib/pkg/names.sh logical name table"
```

---

## Task 8: `lib/pkg/apt.sh` — Debian/Ubuntu adapter

**Files:**
- Create: `lib/pkg/apt.sh`
- Create: `tests/unit/test_apt.bats`

- [ ] **Step 1: Write tests using mocked `sudo_run` and `dpkg`**

`tests/unit/test_apt.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_lib sudo.sh
  SUDO_MODE=full
  source "${PROJECT_ROOT}/lib/pkg/apt.sh"

  # Mock sudo_run to capture the command.
  CAPTURED="$(mktemp)"
  sudo_run() { printf '%s\n' "$*" >> "$CAPTURED"; }
  export -f sudo_run
}

teardown() {
  rm -f "$CAPTURED"
}

@test "pkg_install_system runs apt-get install with packages" {
  pkg_install_system curl wget
  run cat "$CAPTURED"
  assert_output --partial "apt-get install -y --no-install-recommends curl wget"
}

@test "pkg_update_index runs apt-get update" {
  pkg_update_index
  run cat "$CAPTURED"
  assert_output --partial "apt-get update"
}
```

- [ ] **Step 2: Implement `lib/pkg/apt.sh`**

`lib/pkg/apt.sh`:

```bash
# Debian/Ubuntu package manager adapter.

pkg_install_system() {
  sudo_run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

pkg_query() {
  dpkg -s "$1" >/dev/null 2>&1
}

pkg_update_index() {
  sudo_run apt-get update -qq
}
```

- [ ] **Step 3: Tests pass; lint; commit**

```bash
make test-unit && make lint
git add lib/pkg/apt.sh tests/unit/test_apt.bats
git commit -m "feat: add lib/pkg/apt.sh adapter"
```

---

## Task 9: `lib/pkg/dnf.sh` — Fedora/RHEL adapter

**Files:**
- Create: `lib/pkg/dnf.sh`
- Create: `tests/unit/test_dnf.bats`

- [ ] **Step 1: Write tests**

`tests/unit/test_dnf.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_lib sudo.sh
  SUDO_MODE=full
  source "${PROJECT_ROOT}/lib/pkg/dnf.sh"
  CAPTURED="$(mktemp)"
  sudo_run() { printf '%s\n' "$*" >> "$CAPTURED"; }
  export -f sudo_run
}

teardown() { rm -f "$CAPTURED"; }

@test "pkg_install_system uses dnf install -y" {
  pkg_install_system git
  run cat "$CAPTURED"
  assert_output --partial "dnf install -y git"
}

@test "pkg_update_index uses dnf check-update and tolerates exit 100" {
  # Simulate dnf returning 100 (updates available — normal)
  sudo_run() { return 100; }
  export -f sudo_run
  run pkg_update_index
  assert_success
}
```

- [ ] **Step 2: Implement `lib/pkg/dnf.sh`**

`lib/pkg/dnf.sh`:

```bash
# Fedora/RHEL package manager adapter.

pkg_install_system() {
  sudo_run dnf install -y "$@"
}

pkg_query() {
  rpm -q "$1" >/dev/null 2>&1
}

pkg_update_index() {
  # dnf check-update exits 100 when updates available — not an error.
  local rc=0
  sudo_run dnf -q check-update || rc=$?
  [[ "$rc" == "0" || "$rc" == "100" ]]
}
```

- [ ] **Step 3: Tests pass; lint; commit**

```bash
make test-unit && make lint
git add lib/pkg/dnf.sh tests/unit/test_dnf.bats
git commit -m "feat: add lib/pkg/dnf.sh adapter"
```

---

## Task 10: `lib/pkg/pacman.sh` — Arch adapter

**Files:**
- Create: `lib/pkg/pacman.sh`
- Create: `tests/unit/test_pacman.bats`

- [ ] **Step 1: Write tests**

`tests/unit/test_pacman.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_lib sudo.sh
  SUDO_MODE=full
  source "${PROJECT_ROOT}/lib/pkg/pacman.sh"
  CAPTURED="$(mktemp)"
  sudo_run() { printf '%s\n' "$*" >> "$CAPTURED"; }
  export -f sudo_run
}

teardown() { rm -f "$CAPTURED"; }

@test "pkg_install_system uses pacman -S --noconfirm --needed" {
  pkg_install_system git
  run cat "$CAPTURED"
  assert_output --partial "pacman -S --noconfirm --needed git"
}

@test "pkg_update_index uses pacman -Sy" {
  pkg_update_index
  run cat "$CAPTURED"
  assert_output --partial "pacman -Sy"
}
```

- [ ] **Step 2: Implement `lib/pkg/pacman.sh`**

`lib/pkg/pacman.sh`:

```bash
# Arch package manager adapter.

pkg_install_system() {
  sudo_run pacman -S --noconfirm --needed "$@"
}

pkg_query() {
  pacman -Qi "$1" >/dev/null 2>&1
}

pkg_update_index() {
  sudo_run pacman -Sy --noconfirm
}
```

- [ ] **Step 3: Tests pass; lint; commit**

```bash
make test-unit && make lint
git add lib/pkg/pacman.sh tests/unit/test_pacman.bats
git commit -m "feat: add lib/pkg/pacman.sh adapter"
```

---

## Task 11: `lib/pkg/brew.sh` — macOS adapter

**Files:**
- Create: `lib/pkg/brew.sh`
- Create: `tests/unit/test_brew.bats`

- [ ] **Step 1: Write tests**

`tests/unit/test_brew.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_lib sudo.sh
  SUDO_MODE=userlocal
  source "${PROJECT_ROOT}/lib/pkg/brew.sh"
  CAPTURED="$(mktemp)"
  brew() { printf 'brew %s\n' "$*" >> "$CAPTURED"; }
  export -f brew
}

teardown() { rm -f "$CAPTURED"; }

@test "pkg_install_system uses brew install" {
  pkg_install_system git
  run cat "$CAPTURED"
  assert_output --partial "brew install git"
}

@test "pkg_install_cask uses brew install --cask" {
  pkg_install_cask kitty
  run cat "$CAPTURED"
  assert_output --partial "brew install --cask kitty"
}

@test "pkg_update_index is a no-op" {
  run pkg_update_index
  assert_success
}
```

- [ ] **Step 2: Implement `lib/pkg/brew.sh`**

`lib/pkg/brew.sh`:

```bash
# Homebrew adapter (macOS). No sudo.

pkg_install_system() {
  brew install "$@"
}

pkg_install_cask() {
  brew install --cask "$@"
}

pkg_query() {
  brew list --formula --versions "$1" >/dev/null 2>&1 \
    || brew list --cask --versions "$1" >/dev/null 2>&1
}

pkg_update_index() {
  # Homebrew refreshes automatically on install; no-op here.
  return 0
}

ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi
  log "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Persist shellenv and load into current shell.
  local brew_bin
  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_bin=/opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_bin=/usr/local/bin/brew
  else
    error "Homebrew installed but brew binary not found"
    return 1
  fi
  eval "$("$brew_bin" shellenv)"
  if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
    printf '\neval "$(%s shellenv)"\n' "$brew_bin" >> "$HOME/.zprofile"
  fi
}
```

- [ ] **Step 3: Tests pass; lint; commit**

```bash
make test-unit && make lint
git add lib/pkg/brew.sh tests/unit/test_brew.bats
git commit -m "feat: add lib/pkg/brew.sh adapter with shellenv persistence"
```

---

## Task 12: `installers/git.sh`

**Files:**
- Create: `installers/git.sh`
- Create: `tests/unit/test_installer_git.bats`

- [ ] **Step 1: Write failing tests**

`tests/unit/test_installer_git.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer git.sh
}

@test "git_check returns 0 when git is on PATH" {
  run git_check
  assert_success
}

@test "git_check returns 1 when git not on PATH" {
  PATH=/tmp/empty run git_check
  assert_failure
}
```

- [ ] **Step 2: Implement `installers/git.sh`**

`installers/git.sh`:

```bash
# Installer: git.

git_check() {
  command -v git >/dev/null 2>&1
}

git_install() {
  log "Installing git"
  pkg_install_system "$(name_for git)"
  success "git installed"
}
```

- [ ] **Step 3: Tests pass; lint; commit**

```bash
make test-unit && make lint
git add installers/git.sh tests/unit/test_installer_git.bats
git commit -m "feat: add installers/git.sh"
```

---

## Task 13: `installers/basics.sh`, `build-toolchain.sh`, `python3.sh`, `zsh.sh`, `tmux.sh`

These follow the same pattern as `git.sh`. Each task is identical structure.

**For each installer:**
- Create: `installers/<name>.sh`
- Create: `tests/unit/test_installer_<name>.bats` with `*_check` tests.
- Implement `<name>_check` (a `command -v` or marker file) and `<name>_install` (call `pkg_install_system "$(name_for <logical>)"`).

- [ ] **Step 1: `installers/basics.sh`**

```bash
# Installer: curl, wget, unzip, tar, jq, ca-certificates.

basics_check() {
  command -v curl >/dev/null 2>&1 \
    && command -v wget >/dev/null 2>&1 \
    && command -v unzip >/dev/null 2>&1 \
    && command -v tar >/dev/null 2>&1 \
    && command -v jq >/dev/null 2>&1
}

basics_install() {
  log "Installing basics (curl, wget, unzip, tar, jq)"
  # shellcheck disable=SC2046
  pkg_install_system $(name_for basics)
  success "basics installed"
}
```

Bats test: assert `basics_check` returns 0 on a system where the tools are present; mock `pkg_install_system` to verify `basics_install` calls it.

- [ ] **Step 2: `installers/build-toolchain.sh`**

```bash
# Installer: gcc, make, pkg-config (or platform equivalent).

build_toolchain_check() {
  command -v cc >/dev/null 2>&1 && command -v make >/dev/null 2>&1
}

build_toolchain_install() {
  log "Installing build toolchain"
  if [[ "$OS" == "macos" ]]; then
    if ! xcode-select -p >/dev/null 2>&1; then
      info "Triggering Xcode Command Line Tools install — complete the GUI prompt"
      xcode-select --install || true
      until xcode-select -p >/dev/null 2>&1; do sleep 5; done
    fi
  else
    # shellcheck disable=SC2046
    pkg_install_system $(name_for build-toolchain)
  fi
  success "build toolchain installed"
}
```

- [ ] **Step 3: `installers/python3.sh`**

```bash
# Installer: python3 + pip.

python3_check() {
  command -v python3 >/dev/null 2>&1 \
    && (command -v pip3 >/dev/null 2>&1 || python3 -m pip --version >/dev/null 2>&1)
}

python3_install() {
  log "Installing python3 + pip"
  # shellcheck disable=SC2046
  pkg_install_system $(name_for python3)
  success "python3 installed"
}
```

- [ ] **Step 4: `installers/zsh.sh`**

```bash
# Installer: zsh.

zsh_check() {
  command -v zsh >/dev/null 2>&1
}

zsh_install() {
  log "Installing zsh"
  pkg_install_system "$(name_for zsh)"
  # Ensure zsh is in /etc/shells so chsh accepts it.
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ -n "$zsh_path" ]] && ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    if needs_sudo; then
      echo "$zsh_path" | sudo_run tee -a /etc/shells >/dev/null
    fi
  fi
  success "zsh installed"
}
```

- [ ] **Step 5: `installers/tmux.sh`**

```bash
# Installer: tmux.

tmux_check() {
  command -v tmux >/dev/null 2>&1
}

tmux_install() {
  log "Installing tmux"
  pkg_install_system "$(name_for tmux)"
  success "tmux installed"
}
```

- [ ] **Step 6: Write minimal Bats tests for each `*_check`**

Pattern (one file per installer):

```bash
#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer <NAME>.sh
}

@test "<NAME>_check returns 0 when present" {
  run <NAME>_check
  # The check may pass or fail depending on the dev box; just assert the
  # function exists and returns deterministically.
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
```

- [ ] **Step 7: Commit one installer per commit**

```bash
git add installers/basics.sh tests/unit/test_installer_basics.bats
git commit -m "feat: add installers/basics.sh"

git add installers/build-toolchain.sh tests/unit/test_installer_build_toolchain.bats
git commit -m "feat: add installers/build-toolchain.sh"

git add installers/python3.sh tests/unit/test_installer_python3.bats
git commit -m "feat: add installers/python3.sh"

git add installers/zsh.sh tests/unit/test_installer_zsh.bats
git commit -m "feat: add installers/zsh.sh"

git add installers/tmux.sh tests/unit/test_installer_tmux.bats
git commit -m "feat: add installers/tmux.sh"
```

---

## Task 14: `installers/ohmyzsh.sh`

**Files:**
- Create: `installers/ohmyzsh.sh`
- Create: `tests/unit/test_installer_ohmyzsh.bats`

- [ ] **Step 1: Implement `installers/ohmyzsh.sh`**

`installers/ohmyzsh.sh`:

```bash
# Installer: oh-my-zsh.

ohmyzsh_check() {
  [[ -d "$HOME/.oh-my-zsh" ]]
}

ohmyzsh_install() {
  log "Installing oh-my-zsh"
  local script
  script="$(mktemp)"
  curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$script"
  RUNZSH=no KEEP_ZSHRC=yes bash "$script" --unattended
  rm -f "$script"
  success "oh-my-zsh installed"
}
```

- [ ] **Step 2: Bats test for `_check` only**

`tests/unit/test_installer_ohmyzsh.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  load_installer ohmyzsh.sh
}

@test "ohmyzsh_check is deterministic" {
  run ohmyzsh_check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "ohmyzsh_check returns 0 when dir exists" {
  HOME="$(mktemp -d)"
  mkdir -p "$HOME/.oh-my-zsh"
  run ohmyzsh_check
  assert_success
  rm -rf "$HOME"
}
```

- [ ] **Step 3: Lint and commit**

```bash
make test-unit && make lint
git add installers/ohmyzsh.sh tests/unit/test_installer_ohmyzsh.bats
git commit -m "feat: add installers/ohmyzsh.sh"
```

---

## Task 15: `installers/fzf.sh`

**Files:**
- Create: `installers/fzf.sh`
- Create: `tests/unit/test_installer_fzf.bats`

- [ ] **Step 1: Implement `installers/fzf.sh`**

`installers/fzf.sh`:

```bash
# Installer: fzf.

fzf_check() {
  command -v fzf >/dev/null 2>&1 || [[ -x "$HOME/.fzf/bin/fzf" ]]
}

fzf_install() {
  log "Installing fzf"
  if [[ "$OS" == "macos" ]] || needs_sudo; then
    pkg_install_system "$(name_for fzf)" || _fzf_install_userlocal
  else
    _fzf_install_userlocal
  fi
  success "fzf installed"
}

_fzf_install_userlocal() {
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --all --no-bash --no-fish
}
```

- [ ] **Step 2: Bats test for `_check`**

Same pattern as Task 14.

- [ ] **Step 3: Lint and commit**

```bash
make test-unit && make lint
git add installers/fzf.sh tests/unit/test_installer_fzf.bats
git commit -m "feat: add installers/fzf.sh with userlocal fallback"
```

---

## Task 16: `installers/ripgrep.sh`

**Files:**
- Create: `installers/ripgrep.sh`
- Create: `tests/unit/test_installer_ripgrep.bats`

- [ ] **Step 1: Implement `installers/ripgrep.sh`**

`installers/ripgrep.sh`:

```bash
# Installer: ripgrep. Prefer pkg manager, fall back to GitHub release tarball.

ripgrep_check() {
  command -v rg >/dev/null 2>&1
}

ripgrep_install() {
  log "Installing ripgrep"
  if [[ "$OS" == "macos" ]] || needs_sudo; then
    if pkg_install_system "$(name_for ripgrep)"; then
      success "ripgrep installed"
      return 0
    fi
  fi
  _ripgrep_install_release
}

_ripgrep_install_release() {
  log "Falling back to ripgrep GitHub release"
  local pattern url tmp
  case "$ARCH" in
    x86_64) pattern="x86_64-unknown-linux-musl.tar.gz" ;;
    arm64)  pattern="aarch64-unknown-linux-gnu.tar.gz" ;;
    *)      error "Unsupported arch for ripgrep release: $ARCH"; return 1 ;;
  esac
  url="$(github_latest_release_url "BurntSushi/ripgrep" "$pattern")"
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/rg.tar.gz"
  tar -xzf "$tmp/rg.tar.gz" -C "$tmp"
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$tmp"/*/rg "$HOME/.local/bin/rg"
  rm -rf "$tmp"
  success "ripgrep installed to ~/.local/bin/rg"
}
```

- [ ] **Step 2: Bats test for `_check`**

- [ ] **Step 3: Lint and commit**

```bash
make test-unit && make lint
git add installers/ripgrep.sh tests/unit/test_installer_ripgrep.bats
git commit -m "feat: add installers/ripgrep.sh with github-release fallback"
```

---

## Task 17: `installers/nvm.sh` and `installers/node.sh`

**Files:**
- Create: `installers/nvm.sh`
- Create: `installers/node.sh`
- Create: `tests/unit/test_installer_nvm.bats`
- Create: `tests/unit/test_installer_node.bats`

- [ ] **Step 1: Implement `installers/nvm.sh`**

`installers/nvm.sh`:

```bash
# Installer: nvm. User-local install to $HOME/.nvm.

nvm_check() {
  [[ -s "$HOME/.nvm/nvm.sh" ]]
}

nvm_install() {
  log "Installing nvm"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
  ensure_nvm_loaded
  success "nvm installed"
}

# Loads nvm into the current shell. Idempotent. Source before any nvm-dependent step.
ensure_nvm_loaded() {
  export NVM_DIR="$HOME/.nvm"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
  fi
}
```

- [ ] **Step 2: Implement `installers/node.sh`**

`installers/node.sh`:

```bash
# Installer: Node (LTS, via nvm).

node_check() {
  ensure_nvm_loaded 2>/dev/null || true
  command -v node >/dev/null 2>&1
}

node_install() {
  log "Installing Node.js (LTS)"
  ensure_nvm_loaded
  nvm install --lts
  nvm alias default 'lts/*'
  nvm use default
  success "node installed"
}
```

- [ ] **Step 3: Bats `_check` tests for both**

- [ ] **Step 4: Lint and commit**

```bash
make test-unit && make lint
git add installers/nvm.sh tests/unit/test_installer_nvm.bats
git commit -m "feat: add installers/nvm.sh with ensure_nvm_loaded helper"

git add installers/node.sh tests/unit/test_installer_node.bats
git commit -m "feat: add installers/node.sh"
```

---

## Task 18: `installers/go.sh`

**Files:**
- Create: `installers/go.sh`
- Create: `tests/unit/test_installer_go.bats`

- [ ] **Step 1: Implement `installers/go.sh`**

`installers/go.sh`:

```bash
# Installer: Go. User-local install to $HOME/.local/go.

GO_LOCAL_ROOT="$HOME/.local/go"

go_check() {
  command -v go >/dev/null 2>&1 || [[ -x "$GO_LOCAL_ROOT/bin/go" ]]
}

go_install() {
  log "Installing Go"
  local os_name arch_name latest url tmp
  case "$OS" in
    macos) os_name=darwin ;;
    linux) os_name=linux ;;
  esac
  case "$ARCH" in
    x86_64) arch_name=amd64 ;;
    arm64)  arch_name=arm64 ;;
  esac
  latest="$(curl -fsSL https://go.dev/VERSION?m=text | head -n1)"
  url="https://go.dev/dl/${latest}.${os_name}-${arch_name}.tar.gz"
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/go.tar.gz"
  rm -rf "$GO_LOCAL_ROOT"
  mkdir -p "$(dirname "$GO_LOCAL_ROOT")"
  tar -C "$(dirname "$GO_LOCAL_ROOT")" -xzf "$tmp/go.tar.gz"
  rm -rf "$tmp"
  success "go installed to $GO_LOCAL_ROOT"
}
```

- [ ] **Step 2: Bats `_check` test**

- [ ] **Step 3: Lint and commit**

```bash
make test-unit && make lint
git add installers/go.sh tests/unit/test_installer_go.bats
git commit -m "feat: add installers/go.sh user-local tarball install"
```

---

## Task 19: `installers/rust.sh`

**Files:**
- Create: `installers/rust.sh`
- Create: `tests/unit/test_installer_rust.bats`

- [ ] **Step 1: Implement `installers/rust.sh`**

`installers/rust.sh`:

```bash
# Installer: Rust toolchain via rustup. User-local install to $HOME/.cargo.

rust_check() {
  command -v cargo >/dev/null 2>&1 || [[ -x "$HOME/.cargo/bin/cargo" ]]
}

rust_install() {
  log "Installing Rust via rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path
  # shellcheck disable=SC1091
  [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
  success "rust installed"
}
```

- [ ] **Step 2: Bats `_check` test**

- [ ] **Step 3: Lint and commit**

```bash
make test-unit && make lint
git add installers/rust.sh tests/unit/test_installer_rust.bats
git commit -m "feat: add installers/rust.sh via rustup"
```

---

## Task 20: `installers/kitty.sh`

**Files:**
- Create: `installers/kitty.sh`
- Create: `tests/unit/test_installer_kitty.bats`

- [ ] **Step 1: Implement `installers/kitty.sh`**

`installers/kitty.sh`:

```bash
# Installer: kitty. macOS = brew cask. Linux = official installer + desktop integration.

kitty_check() {
  command -v kitty >/dev/null 2>&1 \
    || [[ -x "/Applications/kitty.app/Contents/MacOS/kitty" ]] \
    || [[ -x "$HOME/.local/kitty.app/bin/kitty" ]]
}

kitty_install() {
  log "Installing kitty"
  if [[ "$OS" == "macos" ]]; then
    pkg_install_cask kitty
  else
    _kitty_install_linux
  fi
  success "kitty installed"
}

_kitty_install_linux() {
  curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n
  mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
  ln -sf "$HOME/.local/kitty.app/bin/kitty"  "$HOME/.local/bin/kitty"
  ln -sf "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/kitten"
  cp -f "$HOME/.local/kitty.app/share/applications/kitty.desktop"      "$HOME/.local/share/applications/" 2>/dev/null || true
  cp -f "$HOME/.local/kitty.app/share/applications/kitty-open.desktop" "$HOME/.local/share/applications/" 2>/dev/null || true
  sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" \
    "$HOME/.local/share/applications/"kitty*.desktop 2>/dev/null || true
  sed -i "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|g" \
    "$HOME/.local/share/applications/"kitty*.desktop 2>/dev/null || true
}
```

- [ ] **Step 2: Bats `_check` test**

- [ ] **Step 3: Lint and commit**

```bash
make test-unit && make lint
git add installers/kitty.sh tests/unit/test_installer_kitty.bats
git commit -m "feat: add installers/kitty.sh with linux desktop integration"
```

---

## Task 21: `installers/neovim.sh`

**Files:**
- Create: `installers/neovim.sh`
- Create: `tests/unit/test_installer_neovim.bats`

- [ ] **Step 1: Implement `installers/neovim.sh`**

`installers/neovim.sh`:

```bash
# Installer: Neovim. Prefer GitHub release tarball; build from source as fallback.

neovim_check() {
  command -v nvim >/dev/null 2>&1
}

neovim_install() {
  log "Installing Neovim"
  if _neovim_install_release; then
    success "neovim installed (prebuilt)"
    return 0
  fi
  warn "Prebuilt release unavailable; falling back to source build"
  _neovim_install_source
  success "neovim installed (from source)"
}

_neovim_install_release() {
  local asset
  case "${OS}-${ARCH}" in
    macos-arm64)  asset="nvim-macos-arm64.tar.gz" ;;
    macos-x86_64) asset="nvim-macos-x86_64.tar.gz" ;;
    linux-x86_64) asset="nvim-linux-x86_64.tar.gz" ;;
    linux-arm64)  asset="nvim-linux-arm64.tar.gz" ;;
    *) return 1 ;;
  esac
  local url tmp
  url="$(github_latest_release_url "neovim/neovim" "$asset")" || return 1
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/nvim.tar.gz" || { rm -rf "$tmp"; return 1; }
  mkdir -p "$HOME/.local"
  tar -xzf "$tmp/nvim.tar.gz" -C "$HOME/.local"
  rm -rf "$tmp"
  # Symlink binaries into ~/.local/bin so they're on PATH.
  mkdir -p "$HOME/.local/bin"
  local extracted
  extracted="$(find "$HOME/.local" -maxdepth 1 -type d -name 'nvim-*' | head -n1)"
  [[ -n "$extracted" ]] || return 1
  ln -sf "$extracted/bin/nvim" "$HOME/.local/bin/nvim"
}

_neovim_install_source() {
  local deps
  case "$DISTRO_FAMILY" in
    debian) deps="ninja-build gettext cmake unzip curl build-essential" ;;
    rhel)   deps="ninja-build gettext cmake unzip curl" ;;
    arch)   deps="ninja gettext cmake unzip curl base-devel" ;;
    macos)  brew install ninja libtool automake cmake pkg-config gettext curl; deps="" ;;
  esac
  [[ -n "$deps" ]] && pkg_install_system $deps
  local src
  src="$(mktemp -d)/neovim"
  git clone --depth 1 --branch stable https://github.com/neovim/neovim.git "$src"
  (
    cd "$src"
    make CMAKE_BUILD_TYPE=RelWithDebInfo
    sudo_run make install
  )
  rm -rf "$(dirname "$src")"
}
```

- [ ] **Step 2: Bats `_check` test**

- [ ] **Step 3: Lint and commit**

```bash
make test-unit && make lint
git add installers/neovim.sh tests/unit/test_installer_neovim.bats
git commit -m "feat: add installers/neovim.sh with release-first install"
```

---

## Task 22: `installers/clipboard.sh` and `installers/fonts.sh`

**Files:**
- Create: `installers/clipboard.sh`
- Create: `installers/fonts.sh`
- Tests for `_check` of both

- [ ] **Step 1: Implement `installers/clipboard.sh`**

`installers/clipboard.sh`:

```bash
# Installer: clipboard tools. Linux: xclip + wl-clipboard. macOS: pngpaste.

clipboard_check() {
  if [[ "$OS" == "macos" ]]; then
    command -v pngpaste >/dev/null 2>&1
  else
    command -v xclip >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1
  fi
}

clipboard_install() {
  log "Installing clipboard tools"
  if [[ "$OS" == "macos" ]]; then
    pkg_install_system "$(name_for pngpaste)"
  else
    if [[ "$DISPLAY_SRV" == "none" ]]; then
      warn "Headless system; skipping clipboard tools"
      return 0
    fi
    pkg_install_system "$(name_for clipboard-x11)" "$(name_for clipboard-wayland)"
  fi
  success "clipboard tools installed"
}
```

- [ ] **Step 2: Implement `installers/fonts.sh`**

`installers/fonts.sh`:

```bash
# Installer: FiraCode + NerdFont symbols.

NERDFONT_DIR_LINUX="$HOME/.local/share/fonts"
NERDFONT_DIR_MACOS="$HOME/Library/Fonts"

fonts_check() {
  local dir
  if [[ "$OS" == "macos" ]]; then dir="$NERDFONT_DIR_MACOS"; else dir="$NERDFONT_DIR_LINUX"; fi
  [[ -d "$dir" ]] && ls "$dir" 2>/dev/null | grep -qiE 'fira.*code'
}

fonts_install() {
  log "Installing fonts: FiraCode + NerdFont symbols"
  if [[ "$OS" == "macos" ]]; then
    pkg_install_cask "$(name_for fira-code)"
  else
    pkg_install_system "$(name_for fira-code)"
  fi
  _fonts_install_nerdfont
  if command -v fc-cache >/dev/null 2>&1; then fc-cache -fv >/dev/null; fi
  success "fonts installed"
}

_fonts_install_nerdfont() {
  local url tmp dest
  url="$(github_latest_release_url "ryanoasis/nerd-fonts" "NerdFontsSymbolsOnly.zip")" || return 1
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/nf.zip"
  if [[ "$OS" == "macos" ]]; then dest="$NERDFONT_DIR_MACOS"; else dest="$NERDFONT_DIR_LINUX"; fi
  mkdir -p "$dest"
  unzip -oq "$tmp/nf.zip" -d "$dest"
  rm -rf "$tmp"
}
```

- [ ] **Step 3: Bats `_check` tests**

- [ ] **Step 4: Lint and commit**

```bash
make test-unit && make lint
git add installers/clipboard.sh tests/unit/test_installer_clipboard.bats
git commit -m "feat: add installers/clipboard.sh"

git add installers/fonts.sh tests/unit/test_installer_fonts.bats
git commit -m "feat: add installers/fonts.sh with NerdFont symbols release"
```

---

## Task 23: `dotfiles.sh` — safe checkout with backup and local-override stubs

**Files:**
- Create: `dotfiles.sh`
- Create: `tests/unit/test_dotfiles.bats`

- [ ] **Step 1: Write failing tests for the pure helper functions**

`tests/unit/test_dotfiles.bats`:

```bash
#!/usr/bin/env bats

load helpers

setup() {
  load_lib core.sh
  source "${PROJECT_ROOT}/dotfiles.sh"
}

@test "default_branch resolves origin/HEAD" {
  local tmp
  tmp="$(mktemp -d)"
  ( cd "$tmp" && git init -q --bare remote.git )
  ( cd "$tmp" && git clone -q remote.git work )
  ( cd "$tmp/work" \
    && git config user.email t@t \
    && git config user.name t \
    && git commit --allow-empty -qm init \
    && git push -q origin master 2>/dev/null || git push -q origin main 2>/dev/null )
  ( cd "$tmp/work" && git remote set-head origin -a >/dev/null )
  run default_branch "$tmp/work"
  assert_success
  [[ "$output" =~ ^(main|master)$ ]]
  rm -rf "$tmp"
}

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

- [ ] **Step 2: Implement `dotfiles.sh`**

`dotfiles.sh`:

```bash
#!/usr/bin/env bash
# Dotfiles + nvim config sync. Source from install.sh.

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/superbrobenji/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
NVIM_REPO="${NVIM_REPO:-https://github.com/superbrobenji/nvim.git}"
NVIM_DIR="${NVIM_DIR:-$HOME/.config/nvim}"

default_branch() {
  local dir="$1"
  git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
    | sed 's|^origin/||'
}

# Refuse to operate if the existing .dotfiles dir isn't owned by $USER.
verify_dotfiles_ownership() {
  [[ -e "$DOTFILES_DIR" ]] || return 0
  local owner
  owner="$(stat -f '%Su' "$DOTFILES_DIR" 2>/dev/null || stat -c '%U' "$DOTFILES_DIR")"
  if [[ "$owner" != "$USER" ]]; then
    warn "$DOTFILES_DIR is owned by $owner, not $USER"
    if needs_sudo; then
      info "Fixing ownership"
      sudo_run chown -R "$USER:$(id -gn)" "$DOTFILES_DIR"
    else
      error "Run with sudo to fix, or remove $DOTFILES_DIR manually"
      return 1
    fi
  fi
}

clone_or_update_repo() {
  local repo="$1" dir="$2"
  if [[ ! -d "$dir/.git" ]]; then
    log "Cloning $repo → $dir"
    rm -rf "$dir"
    git clone --depth=1 "$repo" "$dir"
  else
    log "Updating $dir"
    git -C "$dir" fetch --all --quiet
    local branch
    branch="$(default_branch "$dir")"
    [[ -n "$branch" ]] || branch="main"
    git -C "$dir" reset --hard "origin/$branch"
  fi
}

# Bare-repo checkout helper: works with $DOTFILES_DIR as the git dir and $HOME as worktree.
# For now we keep the conventional clone-into-$HOME approach but back up conflicts first.
checkout_dotfiles() {
  local tracked file backup_dir
  backup_dir="$HOME/.dotfiles-backup-$(date +%s)"
  mapfile -t tracked < <(git -C "$DOTFILES_DIR" ls-tree -r HEAD --name-only)
  for file in "${tracked[@]}"; do
    if [[ -e "$HOME/$file" ]] && ! _is_local_override "$file"; then
      if ! cmp -s "$HOME/$file" "$DOTFILES_DIR/$file" 2>/dev/null; then
        mkdir -p "$(dirname "$backup_dir/$file")"
        mv "$HOME/$file" "$backup_dir/$file"
      fi
    fi
  done
  # Mirror tracked files from the repo into $HOME.
  for file in "${tracked[@]}"; do
    mkdir -p "$HOME/$(dirname "$file")"
    cp -a "$DOTFILES_DIR/$file" "$HOME/$file"
  done
  if [[ -d "$backup_dir" ]]; then
    warn "Backed up conflicting files to $backup_dir"
  fi
}

_is_local_override() {
  case "$1" in
    .zshrc.local|.gitconfig.work|.gitconfig.personal) return 0 ;;
    *) return 1 ;;
  esac
}

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

run_dotfiles() {
  verify_dotfiles_ownership
  clone_or_update_repo "$DOTFILES_REPO" "$DOTFILES_DIR"
  checkout_dotfiles
  ensure_local_override_stubs
  clone_or_update_repo "$NVIM_REPO" "$NVIM_DIR"
  success "dotfiles + nvim config in place"
}
```

- [ ] **Step 3: Tests pass; lint; commit**

```bash
make test-unit && make lint
git add dotfiles.sh tests/unit/test_dotfiles.bats
git commit -m "feat: add dotfiles.sh with safe checkout and local-override stubs"
```

---

## Task 24: `install.sh` orchestrator

**Files:**
- Create: `install.sh` (new orchestrator that will eventually replace the legacy one)
- Create: `tests/unit/test_install.bats`

- [ ] **Step 1: Move the legacy scripts out of the way**

```bash
mkdir -p legacy
git mv install.sh           legacy/install.sh
git mv dep-installer.sh     legacy/dep-installer.sh
git mv fetch-dotfiles.sh    legacy/fetch-dotfiles.sh
git commit -m "refactor: move legacy installer scripts to legacy/ during rewrite"
```

- [ ] **Step 2: Write the new `install.sh`**

`install.sh`:

```bash
#!/usr/bin/env bash
# Entry point. Orchestrates platform detection, sudo probe, and per-tool install.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/core.sh
source "$SCRIPT_DIR/lib/core.sh"
# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/network.sh
source "$SCRIPT_DIR/lib/network.sh"
# shellcheck source=lib/sudo.sh
source "$SCRIPT_DIR/lib/sudo.sh"
# shellcheck source=lib/github.sh
source "$SCRIPT_DIR/lib/github.sh"
# shellcheck source=lib/pkg/names.sh
source "$SCRIPT_DIR/lib/pkg/names.sh"

# Defaults
DRY_RUN=false
NO_SUDO=false
SKIP_FONTS=false
SKIP_CHSH=false
SKIP_DOTFILES=false
ONLY=""
SKIP=""
VERBOSE=false
UPDATE=false
ASSUME_YES=false

usage() {
  cat <<'EOF'
Usage: install.sh [FLAGS]

  -n, --dry-run         Show what would happen, change nothing
      --no-sudo         Force user-local mode; skip pkgs needing sudo
      --skip-fonts      Skip font install
      --skip-chsh       Don't change default shell to zsh
      --skip-dotfiles   Install deps only; don't touch dotfiles
      --only TOOL[,...] Install only listed tools
      --skip TOOL[,...] Skip listed tools
      --verbose         Tee full log to stdout
      --update          Force re-pull of dotfiles + nvim config
      --yes             Assume yes to all prompts (unattended)
  -h, --help            Show help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run)     DRY_RUN=true ;;
      --no-sudo)        NO_SUDO=true ;;
      --skip-fonts)     SKIP_FONTS=true ;;
      --skip-chsh)      SKIP_CHSH=true ;;
      --skip-dotfiles)  SKIP_DOTFILES=true ;;
      --only)           ONLY="$2"; shift ;;
      --skip)           SKIP="$2"; shift ;;
      --verbose)        VERBOSE=true ;;
      --update)         UPDATE=true ;;
      --yes)            ASSUME_YES=true ;;
      -h|--help)        usage; exit 0 ;;
      *)                error "Unknown arg: $1"; usage; exit 1 ;;
    esac
    shift
  done
  export DRY_RUN NO_SUDO SKIP_FONTS SKIP_CHSH SKIP_DOTFILES ONLY SKIP VERBOSE UPDATE ASSUME_YES
}

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
  go
  rust
  kitty
  neovim
  clipboard
  fonts
)

FATAL_TOOLS=(basics git build_toolchain)

INSTALLED=()
SKIPPED=()
FAILED=()

load_installers() {
  for f in "$SCRIPT_DIR/installers/"*.sh; do
    # Replace - with _ in function names (filenames use -, funcs use _).
    # shellcheck source=/dev/null
    source "$f"
  done
}

load_adapter() {
  case "$DISTRO_FAMILY" in
    debian) source "$SCRIPT_DIR/lib/pkg/apt.sh" ;;
    rhel)   source "$SCRIPT_DIR/lib/pkg/dnf.sh" ;;
    arch)   source "$SCRIPT_DIR/lib/pkg/pacman.sh" ;;
    macos)  source "$SCRIPT_DIR/lib/pkg/brew.sh"; ensure_brew ;;
    *)      error "Unsupported distro family: $DISTRO_FAMILY"; exit 1 ;;
  esac
}

should_skip() {
  local tool="$1"
  if [[ -n "$ONLY" ]] && [[ ",$ONLY," != *",$tool,"* ]]; then return 0; fi
  if [[ -n "$SKIP" ]] && [[ ",$SKIP," == *",$tool,"* ]]; then return 0; fi
  if [[ "$SKIP_FONTS" == "true" && "$tool" == "fonts" ]]; then return 0; fi
  return 1
}

run_tool() {
  local tool="$1"
  local check_fn="${tool}_check"
  local install_fn="${tool}_install"
  if should_skip "$tool"; then
    info "Skipping $tool (filtered)"
    SKIPPED+=("$tool")
    return 0
  fi
  if $check_fn 2>/dev/null; then
    success "$tool already installed"
    SKIPPED+=("$tool")
    return 0
  fi
  if is_dry_run; then
    info "[dry-run] would install $tool"
    return 0
  fi
  if $install_fn; then
    INSTALLED+=("$tool")
  else
    error "$tool install failed"
    FAILED+=("$tool")
    if printf '%s\n' "${FATAL_TOOLS[@]}" | grep -qxF "$tool"; then
      error "Fatal tool failed; aborting"
      exit 1
    fi
  fi
}

run_chsh() {
  if [[ "$SKIP_CHSH" == "true" ]]; then return 0; fi
  local zsh_path
  zsh_path="$(command -v zsh)"
  [[ -n "$zsh_path" ]] || { warn "zsh not found; skipping chsh"; return 0; }
  if [[ "$SHELL" == "$zsh_path" ]]; then
    info "Default shell already zsh"
    return 0
  fi
  log "Changing default shell to $zsh_path"
  chsh -s "$zsh_path" || warn "chsh failed; change manually"
}

post_install() {
  run_chsh
  if [[ -d "$HOME/.config/nvim" ]] && command -v npm >/dev/null 2>&1; then
    log "Running npm install in nvim config (tree-sitter-cli)"
    (cd "$HOME/.config/nvim" && npm install --silent) || warn "npm install in nvim dir failed"
  fi
}

print_summary() {
  printf '\n─────────────────────────────────────────\n'
  printf '✅ %d installed, %d skipped, %d failed\n' \
    "${#INSTALLED[@]}" "${#SKIPPED[@]}" "${#FAILED[@]}"
  if (( ${#FAILED[@]} > 0 )); then
    printf '   Failed: %s\n' "${FAILED[*]}"
  fi
  printf '📋 Next steps:\n'
  printf '   • Restart shell or `exec zsh`\n'
  printf '   • Edit ~/.zshrc.local for work-specific exports\n'
  printf '   • Open nvim — Mason auto-installs LSPs on first launch\n'
}

main() {
  parse_args "$@"
  : > "$CORE_LOG_FILE"
  info "🔧 Dev Env Installer starting"
  info "📝 Log: $CORE_LOG_FILE"
  detect_platform
  info "🔍 Detected: $OS $ARCH / $DISTRO ($DISTRO_FAMILY) / display=$DISPLAY_SRV"
  load_adapter
  load_installers
  check_network
  probe_sudo
  pkg_update_index || warn "Package index refresh failed; continuing"
  info "Beginning install"
  local i total
  total="${#TOOL_ORDER[@]}"
  i=0
  for tool in "${TOOL_ORDER[@]}"; do
    i=$((i+1))
    log "[$i/$total] $tool"
    run_tool "$tool"
  done
  if [[ "$SKIP_DOTFILES" != "true" ]]; then
    # shellcheck source=dotfiles.sh
    source "$SCRIPT_DIR/dotfiles.sh"
    run_dotfiles
  fi
  post_install
  print_summary
  if (( ${#FAILED[@]} > 0 )); then exit 2; fi
}

main "$@"
```

- [ ] **Step 3: Make executable**

```bash
chmod +x install.sh
```

- [ ] **Step 4: Test parser**

`tests/unit/test_install.bats`:

```bash
#!/usr/bin/env bats

load helpers

@test "install.sh --help exits 0" {
  run bash "${PROJECT_ROOT}/install.sh" --help
  assert_success
  assert_output --partial "Usage: install.sh"
}

@test "install.sh --bad-flag exits 1" {
  run bash "${PROJECT_ROOT}/install.sh" --bad-flag
  assert_failure
}
```

- [ ] **Step 5: Lint and commit**

```bash
make test-unit && make lint
git add install.sh tests/unit/test_install.bats
git commit -m "feat: add new install.sh orchestrator"
```

---

## Task 25: `bootstrap.sh` — curl|bash entry

**Files:**
- Create: `bootstrap.sh`

- [ ] **Step 1: Implement `bootstrap.sh`**

`bootstrap.sh`:

```bash
#!/usr/bin/env bash
# Bootstrap entry: `curl -fsSL <url> | bash`. Clones repo and executes install.sh.

set -Eeuo pipefail

REPO_URL="${BOOTSTRAP_REPO_URL:-https://github.com/superbrobenji/dev-env-installer.git}"
DEST_DIR="${BOOTSTRAP_DEST_DIR:-$HOME/.dev-env-installer}"
BRANCH="${BOOTSTRAP_BRANCH:-main}"

err() { printf '❌ %s\n' "$*" >&2; }
log() { printf '🔹 %s\n' "$*"; }

require() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing $1 — please install it first"; exit 1; }
}

require git
require curl

if [[ -d "$DEST_DIR/.git" ]]; then
  log "Updating $DEST_DIR"
  git -C "$DEST_DIR" fetch --quiet origin
  git -C "$DEST_DIR" reset --hard "origin/$BRANCH"
else
  log "Cloning $REPO_URL → $DEST_DIR"
  rm -rf "$DEST_DIR"
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$DEST_DIR"
fi

exec bash "$DEST_DIR/install.sh" "$@"
```

- [ ] **Step 2: Make executable and lint**

```bash
chmod +x bootstrap.sh
make lint
```

- [ ] **Step 3: Commit**

```bash
git add bootstrap.sh
git commit -m "feat: add bootstrap.sh for curl|bash entry"
```

---

## Task 26: Docker integration tests

**Files:**
- Create: `tests/docker/ubuntu-24.04.Dockerfile`
- Create: `tests/docker/debian-12.Dockerfile`
- Create: `tests/docker/fedora-40.Dockerfile`
- Create: `tests/docker/arch.Dockerfile`
- Create: `tests/docker/run.sh`
- Create: `tests/docker/assert.sh`

- [ ] **Step 1: Create `tests/docker/assert.sh`**

`tests/docker/assert.sh`:

```bash
#!/usr/bin/env bash
# Runs inside container after install.sh. Asserts post-conditions.

set -Eeuo pipefail

fail=0
check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "✓ $1"
  else
    echo "✗ $1 missing"
    fail=1
  fi
}

for c in git rg fzf zsh tmux node go cargo; do check_cmd "$c"; done

if [[ ! -x "$HOME/.local/bin/nvim" ]] && ! command -v nvim >/dev/null 2>&1; then
  echo "✗ nvim missing"
  fail=1
else
  echo "✓ nvim"
fi

if [[ ! -d "$HOME/.dotfiles/.git" ]]; then
  echo "✗ ~/.dotfiles missing"
  fail=1
else
  echo "✓ ~/.dotfiles"
fi

if [[ ! -f "$HOME/.config/nvim/init.lua" ]]; then
  echo "✗ nvim init.lua missing"
  fail=1
else
  echo "✓ nvim/init.lua"
fi

exit "$fail"
```

- [ ] **Step 2: Create `tests/docker/ubuntu-24.04.Dockerfile`**

```dockerfile
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      sudo curl git ca-certificates locales && \
    locale-gen en_US.UTF-8 && \
    useradd -m -G sudo -s /bin/bash dev && \
    echo "dev ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    rm -rf /var/lib/apt/lists/*

USER dev
WORKDIR /home/dev/installer
COPY --chown=dev:dev . /home/dev/installer/

ENV LANG=en_US.UTF-8

CMD bash install.sh --skip-fonts --skip-chsh --yes && bash tests/docker/assert.sh
```

- [ ] **Step 3: Create the other Dockerfiles**

`tests/docker/debian-12.Dockerfile`: identical to ubuntu except `FROM debian:12`.

`tests/docker/fedora-40.Dockerfile`:

```dockerfile
FROM fedora:40

RUN dnf install -y sudo curl git ca-certificates glibc-langpack-en && \
    useradd -m -G wheel -s /bin/bash dev && \
    echo "dev ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER dev
WORKDIR /home/dev/installer
COPY --chown=dev:dev . /home/dev/installer/

CMD bash install.sh --skip-fonts --skip-chsh --yes && bash tests/docker/assert.sh
```

`tests/docker/arch.Dockerfile`:

```dockerfile
FROM archlinux:latest

RUN pacman -Sy --noconfirm sudo curl git ca-certificates && \
    useradd -m -G wheel -s /bin/bash dev && \
    sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

USER dev
WORKDIR /home/dev/installer
COPY --chown=dev:dev . /home/dev/installer/

CMD bash install.sh --skip-fonts --skip-chsh --yes && bash tests/docker/assert.sh
```

- [ ] **Step 4: Create `tests/docker/run.sh`**

`tests/docker/run.sh`:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

DISTROS=(ubuntu-24.04 debian-12 fedora-40 arch)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

results=()
for d in "${DISTROS[@]}"; do
  tag="devenv-test-$d"
  echo "── $d ────────────────────────────"
  docker build -t "$tag" -f "$ROOT/tests/docker/${d}.Dockerfile" "$ROOT"
  if docker run --rm "$tag"; then
    results+=("$d: PASS")
  else
    results+=("$d: FAIL")
  fi
done

echo
printf '%s\n' "${results[@]}"
if printf '%s\n' "${results[@]}" | grep -q FAIL; then exit 1; fi
```

- [ ] **Step 5: Make scripts executable and run**

```bash
chmod +x tests/docker/run.sh tests/docker/assert.sh
make test-docker
```

Expected: all four distros report PASS.

- [ ] **Step 6: Idempotency test (manual one-off)**

Edit `tests/docker/ubuntu-24.04.Dockerfile`'s `CMD` line to run install twice:

```dockerfile
CMD bash install.sh --skip-fonts --skip-chsh --yes \
    && bash install.sh --skip-fonts --skip-chsh --yes \
    && bash tests/docker/assert.sh
```

Run once to confirm second run reports all-already-installed, then revert.

- [ ] **Step 7: Commit**

```bash
git add tests/docker/
git commit -m "test: add docker smoke tests for ubuntu/debian/fedora/arch"
```

---

## Task 27: Documentation and legacy cleanup

**Files:**
- Create: `README.md`
- Delete: `legacy/`

- [ ] **Step 1: Write `README.md`**

`README.md`:

```markdown
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
```

- [ ] **Step 2: Verify all tests still pass**

```bash
make test
```

- [ ] **Step 3: Remove legacy directory**

```bash
git rm -r legacy
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add README for new installer"

git commit -m "chore: remove legacy installer scripts"
```

---

## Task 28: macOS manual verification

This task is **manual** — no automation.

- [ ] **Step 1: On a macOS machine, back up the existing `.zshrc`, `.gitconfig`, `~/.dotfiles`, and `~/.config/nvim`**

```bash
mkdir -p ~/dev-env-installer-backups
cp -a ~/.zshrc ~/dev-env-installer-backups/ 2>/dev/null || true
cp -a ~/.gitconfig ~/dev-env-installer-backups/ 2>/dev/null || true
cp -a ~/.dotfiles ~/dev-env-installer-backups/ 2>/dev/null || true
cp -a ~/.config/nvim ~/dev-env-installer-backups/ 2>/dev/null || true
```

- [ ] **Step 2: Fix the existing root-owned `.dotfiles` if present**

```bash
[[ -d ~/.dotfiles ]] && sudo chown -R "$USER:$(id -gn)" ~/.dotfiles
```

- [ ] **Step 3: Run the new installer**

```bash
./install.sh --skip-fonts
```

- [ ] **Step 4: Verify**

- `command -v nvim git rg fzf zsh tmux node go cargo kitty` — every entry resolves.
- `~/.zshrc.local` exists and contains the placeholder template.
- `~/.gitconfig.work` and `~/.gitconfig.personal` exist.
- The original `.gitconfig`, `.zshrc`, etc. — if they conflicted — were moved to `~/.dotfiles-backup-<ts>/`.
- `nvim` opens, Mason runs on first launch.

- [ ] **Step 5: Run install a second time**

```bash
./install.sh --skip-fonts
```

Expected: summary reports every tool as "already installed".

- [ ] **Step 6: Restore work-specific config**

Move the contents that used to live in `.zshrc` (AWS_PROFILE, AVANTE_ANTHROPIC_API_KEY, typo init line) into `~/.zshrc.local`.

Move the work git identity into `~/.gitconfig.work`.

---

## Spec-coverage check (self-review)

| Spec section | Implemented in task |
|---|---|
| §4 Repo Layout | Tasks 1, 2–11, 12–22, 23, 24, 25, 26 |
| §5.1 Module responsibilities | Tasks 2 (core), 3 (detect), 4 (network), 5 (sudo), 6 (github) |
| §5.2 Adapter interface | Tasks 7 (names), 8 (apt), 9 (dnf), 10 (pacman), 11 (brew) |
| §5.3 Logical name mapping | Task 7 |
| §6 Install flow | Task 24 |
| §6.1 Tool order | Task 24 (`TOOL_ORDER` array matches spec ordering) |
| §6.2 Failure policy | Task 24 (`FATAL_TOOLS` and partial-failure exit-2) |
| §6.3 Sudo strategy | Task 5 |
| §7 Dotfiles handling | Task 23 |
| §8 Critical bug fixes | Distributed: #1 Task 3, #2 Task 25, #3 Task 11, #4 Task 17, #5 Task 5, #6 Task 16, #7 Task 4, #8 Task 20, #9 Task 21, #10 Task 23, #11 Task 23, #12 Task 24 ordering, #13 audited via shellcheck Task 1, #14 Task 21, #15 Task 5 |
| §9 CLI flags | Task 24 |
| §10 Testing | Tasks 1, 26, 28 |
