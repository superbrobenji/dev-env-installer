#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load helpers

setup() {
  load_lib core.sh
}

@test "log writes to file only when VERBOSE=false" {
  CORE_LOG_FILE="$(mktemp)"
  export CORE_LOG_FILE
  VERBOSE=false run log "hello"
  assert_success
  assert_output ""
  run cat "$CORE_LOG_FILE"
  assert_output --partial "hello"
  rm -f "$CORE_LOG_FILE"
}

@test "log writes to stdout and file when VERBOSE=true" {
  CORE_LOG_FILE="$(mktemp)"
  export CORE_LOG_FILE
  VERBOSE=true run log "hello"
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
  VERBOSE=false log "init"
  [ -f "$CORE_LOG_FILE" ]
  rm -f "$CORE_LOG_FILE"
}
