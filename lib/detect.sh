# shellcheck shell=bash
# Platform detection. Populates OS, DISTRO, DISTRO_FAMILY, ARCH, DISPLAY_SRV.

# Parse an os-release file. Prints `DISTRO=foo` and `DISTRO_FAMILY=bar` on stdout.
parse_os_release() {
  local file="${1:-/etc/os-release}"
  [[ -f "$file" ]] || { error "os-release not found at $file"; return 1; }
  local id id_like
  id="$(awk -F= '/^ID=/{gsub(/"/,"",$2); print $2}' "$file")"
  id_like="$(awk -F= '/^ID_LIKE=/{gsub(/"/,"",$2); print $2}' "$file")"
  printf 'DISTRO=%s\n' "$id"
  local family
  case "$id" in
    ubuntu|debian|linuxmint|pop)             family=debian ;;
    fedora|rhel|centos|rocky|almalinux)      family=rhel ;;
    arch|manjaro|endeavouros|cachyos)        family=arch ;;
    *)
      case "$id_like" in
        *debian*) family=debian ;;
        *rhel*|*fedora*) family=rhel ;;
        *arch*) family=arch ;;
        *) family=unknown ;;
      esac
      ;;
  esac
  printf 'DISTRO_FAMILY=%s\n' "$family"
}

normalise_arch() {
  case "$1" in
    x86_64|amd64)   echo "x86_64" ;;
    arm64|aarch64)  echo "arm64" ;;
    *)              echo "$1" ;;
  esac
}

detect_display_server() {
  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    echo "wayland"
  elif [[ -n "${DISPLAY:-}" ]]; then
    echo "x11"
  else
    echo "none"
  fi
}

detect_platform() {
  case "$(uname -s)" in
    Darwin) OS=macos ; DISTRO=macos ; DISTRO_FAMILY=macos ;;
    Linux)
      OS=linux
      eval "$(parse_os_release /etc/os-release)"
      ;;
    *) error "unsupported OS: $(uname -s)"; return 1 ;;
  esac
  ARCH="$(normalise_arch "$(uname -m)")"
  DISPLAY_SRV="$(detect_display_server)"
  export OS DISTRO DISTRO_FAMILY ARCH DISPLAY_SRV
}
