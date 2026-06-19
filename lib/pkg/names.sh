# shellcheck shell=bash
# Logical name → distro-specific package name table.
# Looked up by `name_for <logical>` after DISTRO_FAMILY is set.

name_for() {
  local logical="$1"
  case "$logical" in
    build-toolchain)
      case "$DISTRO_FAMILY" in
        debian) echo "build-essential" ;;
        rhel)   echo "@development-tools" ;;
        arch)   echo "base-devel" ;;
        macos)  echo "" ;;
      esac ;;
    fira-code)
      case "$DISTRO_FAMILY" in
        debian) echo "fonts-firacode" ;;
        rhel)   echo "fira-code-fonts" ;;
        arch)   echo "ttf-fira-code" ;;
        macos)  echo "font-fira-code" ;;
      esac ;;
    python3)
      case "$DISTRO_FAMILY" in
        debian) echo "python3 python3-pip python3-venv" ;;
        rhel)   echo "python3 python3-pip" ;;
        arch)   echo "python python-pip" ;;
        macos)  echo "python@3" ;;
      esac ;;
    clipboard-x11)     echo "xclip" ;;
    clipboard-wayland) echo "wl-clipboard" ;;
    pngpaste)
      if [[ "$DISTRO_FAMILY" == "macos" ]]; then
        echo "pngpaste"
      else
        error "name_for: pngpaste is macOS-only"
        return 1
      fi ;;
    basics)
      case "$DISTRO_FAMILY" in
        debian) echo "curl wget unzip tar jq ca-certificates" ;;
        rhel)   echo "curl wget unzip tar jq ca-certificates" ;;
        arch)   echo "curl wget unzip tar jq ca-certificates" ;;
        macos)  echo "curl wget unzip jq" ;;
      esac ;;
    git|zsh|tmux|fzf|ripgrep)
      echo "$logical" ;;
    *)
      error "name_for: unknown logical name '$logical'"
      return 1 ;;
  esac
}
