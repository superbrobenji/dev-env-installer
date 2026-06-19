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
