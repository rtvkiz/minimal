#!/usr/bin/env bash
#
# Assert that EVERY prod image (catalog.json) has exactly one auto-update
# mechanism configured. This is the invariant that stops an image from being
# onboarded — or silently drifting — without auto-update wired up.
#
# Mechanisms:
#   source-built (<name>/melange.yaml exists)
#       -> a .github/versions.yaml row whose files: points at that melange,
#          with cron-enabled: true. A row that exists but is not cron-enabled
#          (a "frozen" row) FAILS — auto-update must be live, not pending.
#   package-based (no melange.yaml)
#       -> declared in .github/autoupdate-coverage.yaml as either
#          wolfi-versioned (major-bump PR via update-wolfi-packages.yml) or
#          wolfi-rolling (auto-current via the 6-hourly rebuild), or exempt.
#
# Same entrypoint locally (`make check-autoupdate`) and in CI (build.yml
# validate-catalog job), so they cannot drift. jq is assumed present (it is on
# GitHub ubuntu runners); yq (mikefarah v4) is fetched if absent.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

CATALOG="catalog.json"
VERSIONS=".github/versions.yaml"
COVERAGE=".github/autoupdate-coverage.yaml"

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
    curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_${os}_amd64" -o "$yq_bin"
    chmod +x "$yq_bin"
  fi
fi

fail=0
err() { printf '  \033[31m✗\033[0m %s\n' "$*"; fail=1; }

# --- inputs -----------------------------------------------------------------
mapfile -t prod < <(jq -r '.images[].name' "$CATALOG" | sort -u)

versions_json="$("$yq_bin" -o=json '.' "$VERSIONS")"
coverage_json="$("$yq_bin" -o=json '.' "$COVERAGE")"

# versions.yaml: image-dir -> cron-enabled (true|false).
# A `files:` entry may be a plain string ("caddy/melange.yaml") or an object
# ({path,pattern,template}); a row may touch several melange files (e.g. the
# ruby row rewrites both ruby/ and rails/). Map every melange path in every row,
# and let an enabled row win if the same image is touched by more than one.
declare -A vcron
while IFS=$'\t' read -r dir cron; do
  [ -z "$dir" ] && continue
  if [ "${vcron[$dir]:-}" != "true" ]; then vcron["$dir"]="$cron"; fi
done < <(jq -r '
  .[] | select(.files) |
  ((.["cron-enabled"]) == true) as $cron |
  .files[] |
  (if type == "string" then . else .path end) as $p |
  select($p | test("/melange\\.yaml$")) |
  [($p | sub("/melange\\.yaml$"; "")), $cron] | @tsv
' <<<"$versions_json")

# coverage lists
mapfile -t wolfi_versioned < <(jq -r '.["wolfi-versioned"] // [] | .[]' <<<"$coverage_json")
mapfile -t wolfi_rolling   < <(jq -r '.["wolfi-rolling"]   // [] | .[]' <<<"$coverage_json")
mapfile -t exempt          < <(jq -r '.exempt             // [] | .[]?.name // empty' <<<"$coverage_json")
mapfile -t bespoke         < <(jq -r '.bespoke            // [] | .[]?.name // empty' <<<"$coverage_json")

# bespoke image -> its declared workflow file (for existence check)
declare -A bespoke_wf
while IFS=$'\t' read -r name wf; do
  [ -n "$name" ] && bespoke_wf["$name"]="$wf"
done < <(jq -r '.bespoke // [] | .[] | [.name, (.workflow // "")] | @tsv' <<<"$coverage_json")

has() { local x="$1"; shift; local e; for e in "$@"; do [ "$e" = "$x" ] && return 0; done; return 1; }

# --- forward check: every prod image is covered ------------------------------
echo "Checking auto-update coverage for ${#prod[@]} prod images…"
for img in "${prod[@]}"; do
  if [ -f "$img/melange.yaml" ]; then
    # source-built -> a cron-enabled versions.yaml row, OR a declared bespoke updater
    if has "$img" "${bespoke[@]:-}"; then
      wf="${bespoke_wf[$img]:-}"
      if [ -z "$wf" ]; then
        err "$img: declared bespoke but no workflow named in $COVERAGE"
      elif [ ! -f "$wf" ]; then
        err "$img: bespoke workflow '$wf' does not exist"
      fi
    elif [ -z "${vcron[$img]+x}" ]; then
      err "$img: source-built but has NO .github/versions.yaml row (auto-update missing)"
    elif [ "${vcron[$img]}" != "true" ]; then
      err "$img: versions.yaml row exists but cron-enabled is not true (frozen — validate then enable)"
    fi
  else
    # package-based -> must be classified
    if has "$img" "${wolfi_versioned[@]:-}"; then :
    elif has "$img" "${wolfi_rolling[@]:-}"; then :
    elif has "$img" "${exempt[@]:-}"; then :
    else
      err "$img: package-based but not classified in $COVERAGE (add to wolfi-versioned/wolfi-rolling/exempt)"
    fi
  fi
done

# --- reverse checks: no stale/orphan config ---------------------------------
in_prod() { has "$1" "${prod[@]}"; }

for dir in "${!vcron[@]}"; do
  in_prod "$dir" || err "versions.yaml has a row for '$dir' which is not a prod image in $CATALOG (orphan/rename?)"
done
for name in "${wolfi_versioned[@]:-}" "${wolfi_rolling[@]:-}"; do
  [ -n "$name" ] || continue
  in_prod "$name" || err "$COVERAGE lists '$name' which is not a prod image in $CATALOG"
  [ -f "$name/melange.yaml" ] && err "$COVERAGE lists '$name' as package-based, but it has a melange.yaml (should be a versions.yaml row)"
done
for name in "${bespoke[@]:-}" "${exempt[@]:-}"; do
  [ -n "$name" ] || continue
  in_prod "$name" || err "$COVERAGE lists '$name' which is not a prod image in $CATALOG"
done

# --- VEX existence: every prod image ships a vex/<name>.openvex.json ----------
for img in "${prod[@]}"; do
  [ -f "vex/$img.openvex.json" ] || err "$img: missing vex/$img.openvex.json (every catalog image needs a VEX file)"
done

# --- pin-alignment: a row's pin-major must equal its melange's current major --
# A wrong pin silently freezes the image — the resolver treats every same-major
# release as an un-adopted "new major" (helmfile 1.7.0 pinned to 7 → zero
# updates since onboarding, yet coverage passed). Assert it here at PR time.
# Read current the way the resolver does: a row may track a non-default field
# (rails tracks `rails_version`, not `version`) or use a custom grep — skip those
# we can't read simply rather than misfire.
# NB: emit "-" for an absent current-field — never an empty field. IFS=$'\t'
# treats tab as whitespace, so `read` collapses an empty field between two tabs
# and misaligns the rest (this silently defeated the check at first).
while IFS=$'\t' read -r rname melpath pinmaj curfield hasgrep; do
  [ -n "$pinmaj" ] || continue
  [ -f "$melpath" ] || continue
  [ "$curfield" = "-" ] && curfield=""
  if [ "$hasgrep" = "true" ] && [ -z "$curfield" ]; then
    continue   # custom current-grep — resolver handles it; don't guess here
  fi
  field="${curfield:-version}"
  # single awk (no grep|head pipe — that SIGPIPEs under set -o pipefail)
  cur=$(awk -v f="$field" 'index($0,"  " f ":")==1 {v=$2; gsub(/"/,"",v); print v; exit}' "$melpath")
  [ -n "$cur" ] || continue
  curmaj="${cur%%.*}"
  [ "$curmaj" = "$pinmaj" ] || err "$rname: versions.yaml pin-major=$pinmaj != current major $curmaj (version $cur) — this freezes the image"
done < <(jq -r '
  .[] | select(.source["pin-major"] != null) |
  [ .name,
    (.files[0] | if type=="string" then . else .path end),
    (.source["pin-major"]|tostring),
    (.source["current-field"] // "-"),
    ((.source["current-grep"] != null)|tostring) ] | @tsv
' <<<"$versions_json")

# --- Go transitive-dep patching: every source-built Go image must be registered
# in patch-go-deps.yml (as a MODROOTS key — SKIP/TESTKEEP images keep their key
# too). Catches silently-unpatched Go images (blackbox/node-exporter/pushgateway
# shipped this way). ------------------------------------------------------------
PGD=".github/workflows/patch-go-deps.yml"
for img in "${prod[@]}"; do
  [ -f "$img/melange.yaml" ] || continue
  # Go image heuristic: a whitespace-anchored "go build" (so Rust's
  # "cargo build" — which contains the substring "go build" — doesn't match).
  grep -qE '(^|[[:space:]])go build' "$img/melange.yaml" || continue
  # Must be a key in ALL 3 dicts (MODROOTS/MAIN_MODULES/BUILD_MARKERS) — a
  # partial registration (in 1 or 2) silently under-patches. Each `[img]=` key
  # appears once per dict, so a fully-registered image has >= 3 (TESTKEEP images
  # get a 4th in TESTKEEP_BUILD). A count < 3 means an incomplete registration.
  n=$(grep -cE "^[[:space:]]*\[$img\]=" "$PGD")
  [ "$n" -ge 3 ] \
    || err "$img: incompletely registered in patch-go-deps.yml (found $n/3 dict entries — needs MODROOTS + MAIN_MODULES + BUILD_MARKERS, or SKIP/TESTKEEP)"
done

if [ "$fail" -ne 0 ]; then
  echo
  echo "✗ auto-update coverage FAILED — every prod image must have exactly one live auto-update mechanism."
  exit 1
fi
echo "✓ auto-update coverage: all ${#prod[@]} prod images configured + VEX + pin-alignment + Go-patch registration"
