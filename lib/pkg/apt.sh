# shellcheck shell=bash
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
