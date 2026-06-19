# shellcheck shell=bash
# Arch package manager adapter.

pkg_install_system() {
  sudo_run pacman -S --noconfirm --needed "$@"
}

pkg_query() {
  pacman -Qi "$1" >/dev/null 2>&1
}

pkg_update_index() {
  sudo_run pacman -Sy --noconfirm
}
