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
# Resolution order:
#   1. source.current-field      → grep '^  <field>:' files[0]            (melange shortcut)
#   2. source.current-grep.{file, line?, pattern}                          (arbitrary files)
#   3. default                   → grep '^  version:' files[0]
current_field=$(j '.source["current-field"] // empty')
current_grep_file=$(j '.source["current-grep"].file // empty')
if [ -n "$current_field" ]; then
  current=$(grep -E "^  ${current_field}:" "$files_first" | head -1 | awk '{print $2}')
elif [ -n "$current_grep_file" ]; then
  line_pat=$(j '.source["current-grep"].line // empty')
  val_pat=$(j '.source["current-grep"].pattern')
  if [ -n "$line_pat" ]; then
    current=$(grep -E "$line_pat" "$current_grep_file" | head -1 | grep -oE "$val_pat" | head -1)
  else
    current=$(grep -oE "$val_pat" "$current_grep_file" | head -1)
  fi
else
  current=$(grep -E '^  version:' "$files_first" | head -1 | awk '{print $2}')
fi
[ -n "$current" ] || { echo "::error::could not read current version for $name"; exit 1; }

# --- pin-alignment guard ---
# The configured pin-major MUST match the current recipe's major. If it doesn't,
# the row is misconfigured: the pin-major guard below treats every same-major
# release as an un-adopted "new major" and silently freezes the image (helmfile
# 1.7.0 pinned to `7` did exactly this — zero updates since onboarding). Fail
# loudly here so the mistake is visible instead of a quiet freeze.
if [ -n "$pin_major" ]; then
  current_major="${current%%.*}"
  if [ "$current_major" != "$pin_major" ]; then
    echo "::error::$name: pin-major=$pin_major does not match current version $current (major $current_major) — fix the row's pin-major"
    exit 1
  fi
fi

# --- fetch LATEST per source type ---
gh_curl() {
  # --max-time bounds each attempt so a stalled endpoint (server accepts the
  # connection then never sends a body — --connect-timeout alone won't catch it)
  # fails fast instead of hanging the whole update-versions job.
  curl -sS --connect-timeout 20 --max-time 20 --retry 3 --retry-all-errors \
    ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} \
    "$1"
}

fetch_github_releases_latest() {
  local repo; repo=$(j '.source.repo')
  local tag strip_prefix
  tag=$(gh_curl "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name // empty')
  [ -n "$tag" ] || { echo "::error::no tag from $repo/releases/latest"; return 1; }
  # Optional source.strip-prefix removes a fixed release-name prefix
  # (e.g. grafana/mimir tags releases `mimir-3.1.2`). No-op when unset.
  strip_prefix=$(j '.source["strip-prefix"] // ""')
  if [ -n "$strip_prefix" ]; then tag="${tag#"$strip_prefix"}"; fi
  if [ "$strip_v" = "true" ]; then tag="${tag#v}"; fi
  printf '%s\n' "$tag"
}

# /repos/<repo>/tags filtered by jq regex pattern. Tags ordered by creation
# date, not semver, so we sort numerically after filtering.
# Optional source.tag-rewrite: {from, to} runs a tr-style char substitution
# before semver-sorting (for ruby's underscore-separated tags).
fetch_github_tags() {
  local repo pattern strip_prefix from to tags
  repo=$(j '.source.repo')
  pattern=$(j '.source.pattern')
  strip_prefix=$(j '.source["strip-prefix"] // ""')
  from=$(j '.source["tag-rewrite"].from // empty')
  to=$(j '.source["tag-rewrite"].to // empty')
  [ -n "$pattern" ] || { echo "::error::source.pattern required for github-tags"; return 1; }
  tags=$(gh_curl "https://api.github.com/repos/${repo}/tags?per_page=100" \
    | jq -r --arg p "$pattern" --arg s "$strip_prefix" \
        '[.[] | .name | select(test($p)) | sub("^" + $s; "")] | .[]')
  if [ -n "$from" ]; then
    tags=$(printf '%s\n' "$tags" | tr "$from" "$to")
  fi
  tags=$(printf '%s\n' "$tags" | sort -t. -k1,1n -k2,2n -k3,3n)
  [ -n "$tags" ] || { echo "::error::no tags matching /$pattern/ in $repo"; return 1; }

  # Tags can be created before the release assets are published (keycloak cuts
  # the tag, then publishes `releases/download/<v>/...` minutes-to-hours later).
  # When the tarball is a release-download asset, picking the newest tag blindly
  # makes apply-update.sh 404 on a not-yet-published asset. Probe from newest
  # down and return the newest tag whose tarball actually exists; tags whose
  # release is still pending are skipped (a later run picks them up).
  local tb; tb=$(j '.tarball.url // .tarballs[0].url // empty')
  if [[ "$tb" == *"/releases/download/"* ]]; then
    local v url
    while IFS= read -r v; do
      [ -n "$v" ] || continue
      url="${tb//\{version\}/$v}"
      url="${url//\{major\}/${v%%.*}}"
      url="${url//\{minor\}/${v%.*}}"
      if curl -fsSLI -o /dev/null --connect-timeout 20 --retry 2 --retry-all-errors "$url" >/dev/null 2>&1; then
        printf '%s\n' "$v"; return 0
      fi
      echo "::warning::$repo tag $v has no published release asset yet — skipping until it is" >&2
    done < <(printf '%s\n' "$tags" | tac)
    echo "::error::no released tag matching /$pattern/ in $repo"; return 1
  fi

  printf '%s\n' "$tags" | tail -1
}

# Single URL returning the bare version as text (e.g. jenkins latestCore.txt).
fetch_plain_text() {
  local url; url=$(j '.source.url')
  curl -fsSL --connect-timeout 20 --max-time 20 --retry 3 --retry-all-errors "$url" | tr -d '[:space:]'
}

# Substitute {series} = "MAJOR.MINOR" of current version into a URL template.
# Used by sources whose discovery endpoint is series-scoped (php, mariadb).
render_url() {
  local tmpl="$1"
  local series; series=$(cut -d. -f1,2 <<<"$current")
  tmpl="${tmpl//\{series\}/$series}"
  printf '%s' "$tmpl"
}

# Try a list of URLs in order; return body of the first that succeeds.
fetch_first_url() {
  # Reads URLs from $@; returns first non-empty body.
  local u body
  for u in "$@"; do
    # --max-time so a stalled URL fails fast and we fall through to the next one.
    body=$(curl -fsSL --connect-timeout 20 --max-time 20 --retry 3 --retry-all-errors "$u" 2>/dev/null) || continue
    [ -n "$body" ] && { printf '%s' "$body"; return 0; }
  done
  return 1
}

# Build the URL list for sources with `url:` or `urls:` (post-template).
url_list() {
  if jq -e '.source.urls' <<<"$row" >/dev/null; then
    jq -r '.source.urls[]' <<<"$row" | while read -r u; do render_url "$u"; echo; done
  else
    render_url "$(j '.source.url')"; echo
  fi
}

# Generic scrape: fetch URL(s), grep -oE the pattern, semver-sort, take last.
# Pattern's capture group 1 is the version; if no group, the full match is used.
fetch_scrape() {
  local pattern; pattern=$(j '.source.pattern')
  [ -n "$pattern" ] || { echo "::error::source.pattern required for scrape"; return 1; }
  mapfile -t urls < <(url_list)
  local body; body=$(fetch_first_url "${urls[@]}") || { echo "::error::all scrape URLs failed"; return 1; }
  # grep -oE returns full matches; if the pattern has a capture, post-process.
  printf '%s' "$body" | grep -oE "$pattern" \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
    | sort -t. -k1,1n -k2,2n -k3,3n | tail -1
}

# Fetch URL returning JSON, run the supplied jq expression, return its output.
fetch_json() {
  local jq_expr; jq_expr=$(j '.source.jq')
  [ -n "$jq_expr" ] || { echo "::error::source.jq required for json"; return 1; }
  mapfile -t urls < <(url_list)
  local body; body=$(fetch_first_url "${urls[@]}") || { echo "::error::all json URLs failed"; return 1; }
  local out; out=$(jq -r "$jq_expr" <<<"$body")
  [ -n "$out" ] && [ "$out" != "null" ] || { echo "::error::jq expression returned empty"; return 1; }
  printf '%s' "$out"
}

case "$source_type" in
  github-releases-latest) latest=$(fetch_github_releases_latest) ;;
  github-tags)            latest=$(fetch_github_tags) ;;
  plain-text)             latest=$(fetch_plain_text) ;;
  scrape)                 latest=$(fetch_scrape) ;;
  json)                   latest=$(fetch_json) ;;
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

# --- no-downgrade guard ---
# Only advance forward. `latest != current` alone would let a stale endpoint,
# an incomplete tag window, or a misconfigured source emit a DOWNGRADE PR.
# Require latest > current (semver) before proposing an update.
highest=$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -1)
if [ "$latest" = "$current" ] || [ "$highest" != "$latest" ]; then
  if [ "$latest" != "$current" ]; then
    echo "::warning::$name: upstream latest ($latest) is not newer than current ($current) — not downgrading"
  fi
  echo "update=false" >> "$out"
  echo "current_version=$current" >> "$out"
  exit 0
fi

{
  echo "update=true"
  echo "current_version=$current"
  echo "new_version=$latest"
} >> "$out"
