#!/usr/bin/env bash
# Resolve the latest upstream version for a single row from versions.yaml.
#
# Usage:
#   check-upstream.sh '<row-as-json>'
#
# Emits to $GITHUB_OUTPUT (or stdout if unset):
#   update=true|false
#   current_version=<x>
#   new_version=<x>            (only when update=true)
#   next_major=<N>             (only when an unhandled higher major exists)
#   next_major_tag=<x>         (first tag observed for that major)
#
# Required tools: bash, jq, curl. GH_TOKEN env var if hitting api.github.com.

set -euo pipefail

row="${1:?row JSON required as $1}"
out="${GITHUB_OUTPUT:-/dev/stdout}"

j() { jq -r "$1" <<<"$row"; }

name=$(j '.name')
source_type=$(j '.source.type')
strip_v=$(j '.source["strip-v"] // false')
pin_major=$(j '.source["pin-major"] // empty')
files_first=$(j '.files[0] | if type == "string" then . else .path end')

# --- read CURRENT version ---
# Default: grep `^  version:` in the first melange.yaml. Rows that edit
# non-melange files (Makefile, README) must set source.current-grep to a
# {file, pattern} pair; we don't try to be clever about it.
current_grep_file=$(j '.source["current-grep"].file // empty')
if [ -n "$current_grep_file" ]; then
  current_pattern=$(j '.source["current-grep"].pattern')
  current=$(grep -oE "$current_pattern" "$current_grep_file" | head -1)
else
  current=$(grep -E '^  version:' "$files_first" | head -1 | awk '{print $2}')
fi
[ -n "$current" ] || { echo "::error::could not read current version for $name"; exit 1; }

# --- fetch LATEST per source type ---
gh_curl() {
  curl -sS --retry 3 --retry-all-errors \
    ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} \
    "$1"
}

fetch_github_releases_latest() {
  local repo; repo=$(j '.source.repo')
  local tag
  tag=$(gh_curl "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name // empty')
  [ -n "$tag" ] || { echo "::error::no tag from $repo/releases/latest"; return 1; }
  if [ "$strip_v" = "true" ]; then tag="${tag#v}"; fi
  printf '%s\n' "$tag"
}

# /repos/<repo>/tags filtered by jq regex pattern. Tags ordered by creation
# date, not semver, so we sort numerically after filtering.
fetch_github_tags() {
  local repo pattern strip_prefix tags
  repo=$(j '.source.repo')
  pattern=$(j '.source.pattern')
  strip_prefix=$(j '.source["strip-prefix"] // ""')
  [ -n "$pattern" ] || { echo "::error::source.pattern required for github-tags"; return 1; }
  # Pull all matching tags, strip the configured prefix, semver-sort, take last.
  tags=$(gh_curl "https://api.github.com/repos/${repo}/tags?per_page=100" \
    | jq -r --arg p "$pattern" --arg s "$strip_prefix" \
        '[.[] | .name | select(test($p)) | sub("^" + $s; "")] | .[]' \
    | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
  [ -n "$tags" ] || { echo "::error::no tags matching /$pattern/ in $repo"; return 1; }
  printf '%s\n' "$tags"
}

case "$source_type" in
  github-releases-latest) latest=$(fetch_github_releases_latest) ;;
  github-tags)            latest=$(fetch_github_tags) ;;
  *) echo "::error::source.type '$source_type' not implemented yet"; exit 1 ;;
esac

# --- validate shape: N.N.N ---
if ! [[ "$latest" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]]; then
  echo "::error::invalid upstream version received for $name: $latest"; exit 1
fi

echo "current=$current latest=$latest" >&2

# --- pin-major guard: surface next major separately, do not bump across it ---
if [ -n "$pin_major" ]; then
  latest_major="${latest%%.*}"
  if [ "$latest_major" != "$pin_major" ]; then
    {
      echo "update=false"
      echo "current_version=$current"
      echo "next_major=$latest_major"
      echo "next_major_tag=$latest"
    } >> "$out"
    echo "::warning::$name: new major ${latest_major}.x detected (current pinned to ${pin_major}.x)"
    exit 0
  fi
fi

if [ "$latest" = "$current" ]; then
  echo "update=false" >> "$out"
  echo "current_version=$current" >> "$out"
  exit 0
fi

{
  echo "update=true"
  echo "current_version=$current"
  echo "new_version=$latest"
} >> "$out"
