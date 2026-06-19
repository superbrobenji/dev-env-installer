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
