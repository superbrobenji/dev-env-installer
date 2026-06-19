# shellcheck shell=bash
# GitHub release URL resolver. Uses jq if available, otherwise grep.

match_release_asset() {
  local payload="$1"
  local pattern="$2"
  if command -v jq >/dev/null 2>&1; then
    local url
    url="$(printf '%s' "$payload" \
      | jq -r --arg pat "$pattern" '.assets[] | select(.name | contains($pat)) | .browser_download_url' \
      | head -n1)"
    [[ -n "$url" ]] || return 1
    printf '%s\n' "$url"
    return 0
  fi
  # Fallback: grep-based extraction (best-effort, single asset name match).
  local url
  url="$(printf '%s' "$payload" \
    | grep -oE '"browser_download_url"\s*:\s*"[^"]*'"$pattern"'[^"]*"' \
    | head -n1 \
    | sed -E 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  [[ -n "$url" ]] || return 1
  printf '%s\n' "$url"
}

github_latest_release_url() {
  local repo="$1"
  local pattern="$2"
  local api="https://api.github.com/repos/${repo}/releases/latest"
  local payload
  payload="$(curl -fsSL "$api")" || { error "Failed to fetch $api"; return 1; }
  match_release_asset "$payload" "$pattern"
}
