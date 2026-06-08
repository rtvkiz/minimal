#!/usr/bin/env bash
# Download tarball(s) for a row, compute digest(s), and edit each file in files[].
#
# Usage:
#   apply-update.sh '<row-as-json>' <new_version>
#
# For melange.yaml rows this rewrites:
#   ^  version:   -> new_version
#   ^  <field>:   -> computed digest        (per tarball/tarballs)
#   ^  epoch:     -> 0
# For files[] entries given as {path, pattern, template}, runs sed with
# the row's own pattern → template (after {version} substitution).

set -euo pipefail

row="${1:?row JSON required as $1}"
new_version="${2:?new_version required as $2}"

j() { jq -r "$1" <<<"$row"; }

name=$(j '.name')

# --- substitute {version}, derived {major}/{minor}, and arbitrary {vars} ---
render() {
  local tmpl="$1"
  local major minor
  major="${new_version%%.*}"
  minor="${new_version%.*}"   # 3.4.0 -> 3.4 ; 2.11.4 -> 2.11
  tmpl="${tmpl//\{version\}/$new_version}"
  tmpl="${tmpl//\{major\}/$major}"
  tmpl="${tmpl//\{minor\}/$minor}"
  while IFS=$'\t' read -r k v; do
    [ -z "$k" ] && continue
    tmpl="${tmpl//\{$k\}/$v}"
  done < <(jq -r '(.tarball.vars // .tarballs[0].vars // {}) | to_entries[] | "\(.key)\t\(.value)"' <<<"$row")
  printf '%s' "$tmpl"
}

# --- download from the first working URL, return digest of given algo ---
fetch_digest() {
  local algo="$1"; shift
  local out=/tmp/upstream.tar
  local rendered=""
  for u in "$@"; do
    rendered=$(render "$u")
    if curl -fsSL --connect-timeout 20 --retry 5 --retry-all-errors "$rendered" -o "$out"; then
      break
    fi
    rendered=""
  done
  [ -n "$rendered" ] || { echo "::error::all tarball URLs failed for $name"; return 1; }
  case "$algo" in
    sha256) sha256sum "$out" | awk '{print $1}' ;;
    sha512) sha512sum "$out" | awk '{print $1}' ;;
    *) echo "::error::unsupported algo: $algo"; return 1 ;;
  esac
  rm -f "$out"
}

# --- collect {field, digest} pairs from tarball / tarballs ---
declare -A digests
# Normalize: .tarballs (list) wins; .tarball (single) becomes a 1-element list.
tarballs_json=$(jq -c '.tarballs // (if .tarball then [.tarball] else [] end)' <<<"$row")
tarball_count=$(jq 'length' <<<"$tarballs_json")
for i in $(seq 0 $((tarball_count - 1))); do
  t=$(jq -c ".[$i]" <<<"$tarballs_json")
  field=$(jq -r '.field' <<<"$t")
  algo=$(jq -r '.algo // .field' <<<"$t")
  # Per-tarball URL list: support both `urls:` (plural) and `url:` (single).
  mapfile -t urls < <(jq -r 'if .urls then .urls[] else .url end' <<<"$t")
  digest=$(fetch_digest "$algo" "${urls[@]}")
  echo "  $field=$digest" >&2
  digests[$field]="$digest"
done

# --- edit each file in files[] ---
file_count=$(jq '.files | length' <<<"$row")
for i in $(seq 0 $((file_count - 1))); do
  entry=$(jq -c ".files[$i]" <<<"$row")
  kind=$(jq -r 'type' <<<"$entry")
  if [ "$kind" = "string" ]; then
    path=$(jq -r '.' <<<"$entry")
    # Default melange.yaml editing: version, every collected digest field, epoch,
    # plus any row-level extra-fields: that should track the same value.
    sed -i "s/^  version: .*/  version: $new_version/" "$path"
    for field in "${!digests[@]}"; do
      sed -i "s/^  ${field}: .*/  ${field}: ${digests[$field]}/" "$path"
    done
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      sed -i "s/^  ${f}: .*/  ${f}: $new_version/" "$path"
    done < <(jq -r '.["extra-fields"][]? // empty' <<<"$row")
    sed -i "s/^  epoch: .*/  epoch: 0/" "$path"
    echo "  edited $path" >&2
  else
    # Custom row: {path, pattern, template} — template gets {version} substituted
    path=$(jq -r '.path' <<<"$entry")
    pattern=$(jq -r '.pattern' <<<"$entry")
    template=$(jq -r '.template' <<<"$entry")
    rendered_tmpl=$(render "$template")
    # Use a control char as the sed delimiter — patterns/templates contain `|`,
    # `/`, `#` etc, and we can't rely on any printable separator being safe.
    sed -i $'s\x01'"${pattern}"$'\x01'"${rendered_tmpl}"$'\x01' "$path"
    echo "  edited $path (custom)" >&2
  fi
done
