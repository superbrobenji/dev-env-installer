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
