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
