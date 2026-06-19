# shellcheck shell=bash
# Fedora/RHEL package manager adapter.

pkg_install_system() {
  sudo_run dnf install -y "$@"
}

pkg_query() {
  rpm -q "$1" >/dev/null 2>&1
}

pkg_update_index() {
  # dnf check-update exits 100 when updates available — not an error.
  local rc=0
  sudo_run dnf -q check-update || rc=$?
  [[ "$rc" == "0" || "$rc" == "100" ]]
}
