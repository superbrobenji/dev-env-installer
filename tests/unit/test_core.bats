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
