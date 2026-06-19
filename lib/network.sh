# shellcheck shell=bash
# Connectivity check.

if [[ -z "${NETWORK_PROBE_URLS+x}" ]] || [[ "${#NETWORK_PROBE_URLS[@]}" -eq 0 ]]; then
  NETWORK_PROBE_URLS=("https://github.com" "https://raw.githubusercontent.com")
fi

probe_url() {
  local url="$1"
  curl -fsI --max-time 5 "$url" >/dev/null 2>&1
}

check_network() {
  if [[ "${#NETWORK_PROBE_URLS[@]}" -eq 0 ]]; then
    NETWORK_PROBE_URLS=("https://github.com" "https://raw.githubusercontent.com")
  fi
  info "Checking network connectivity"
  for url in "${NETWORK_PROBE_URLS[@]}"; do
    if probe_url "$url"; then
      success "Network reachable via $url"
      return 0
    fi
  done
  error "No network connectivity (tried: ${NETWORK_PROBE_URLS[*]})"
  return 1
}
