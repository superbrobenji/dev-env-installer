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
