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
