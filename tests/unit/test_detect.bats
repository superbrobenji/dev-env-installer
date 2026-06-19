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
