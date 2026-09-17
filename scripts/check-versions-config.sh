#!/usr/bin/env bash
# Validate the semantic contract consumed by .github/scripts/apply-update.sh.
# YAML syntax alone cannot catch a custom checksum field accidentally being
# treated as the digest algorithm (for example, cli_sha256 vs sha256).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

versions_file="${1:-.github/versions.yaml}"

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

if command -v yq >/dev/null 2>&1; then
  yq_bin="yq"
else
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/minimal-workflow-lint"
  mkdir -p "$cache"
  yq_bin="$cache/yq"
  if [ ! -x "$yq_bin" ]; then
    echo "→ fetching yq"
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"
    case "$arch" in
      x86_64) arch="amd64" ;;
      aarch64|arm64) arch="arm64" ;;
      *) echo "unsupported architecture for yq: $arch" >&2; exit 2 ;;
    esac
    curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_${os}_${arch}" -o "$yq_bin"
    chmod +x "$yq_bin"
  fi
fi

if [ ! -f "$versions_file" ]; then
  echo "versions config not found: $versions_file" >&2
  exit 2
fi

versions_json="$("$yq_bin" -o=json '.' "$versions_file")"

fail=0
err() { printf '  \033[31m✗\033[0m %s\n' "$*"; fail=1; }

while IFS= read -r message; do
  [ -n "$message" ] && err "$message"
done < <(jq -r '
  if type != "array" then
    "root: expected a list of updater rows"
  else
    (
      group_by(.name)[] |
      select(length > 1) |
      "\(.[0].name // "<missing>"): duplicate updater name"
    ),
    (
      .[] |
      .name as $name |
      if (($name | type) != "string" or $name == "") then
        "<missing>: updater row requires a non-empty name"
      elif (has("tarball") and has("tarballs")) then
        "\($name): use either tarball or tarballs, not both"
      else empty end
    ),
    (
      .[] |
      (.name // "<missing>") as $name |
      (
        if has("tarballs") then .tarballs[]?
        elif has("tarball") then .tarball
        else empty
        end
      ) as $tarball |
      ($tarball.field // "") as $field |
      ($tarball.algo // $field) as $algo |
      if (($field | type) != "string" or $field == "") then
        "\($name): every tarball requires a non-empty field"
      elif (($algo | type) != "string" or ($algo != "sha256" and $algo != "sha512")) then
        "\($name): tarball field \($field) resolves to unsupported digest algorithm \($algo | tojson); set algo to sha256 or sha512"
      elif ($tarball | has("url") and has("urls")) then
        "\($name): tarball field \($field) must use either url or urls, not both"
      elif ($tarball | (has("url") or has("urls")) | not) then
        "\($name): tarball field \($field) requires url or urls"
      elif ($tarball | has("url")) and (($tarball.url | type) != "string" or $tarball.url == "") then
        "\($name): tarball field \($field) has an invalid url"
      elif ($tarball | has("urls")) and (
        ($tarball.urls | type) != "array" or
        ($tarball.urls | length) == 0 or
        any($tarball.urls[]; (type != "string" or . == ""))
      ) then
        "\($name): tarball field \($field) requires a non-empty list of URL strings"
      else empty end
    )
  end
' <<<"$versions_json")

if [ "$fail" -ne 0 ]; then
  echo
  echo "✗ versions config validation failed"
  exit 1
fi

echo "✓ versions config valid"
