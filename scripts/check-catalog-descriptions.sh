#!/usr/bin/env bash
#
# Assert that EVERY image in catalog.json carries a distinct, useful
# `description` — the string that becomes <meta name="description"> and the
# og:/twitter: description on that image's page.
#
# Why this is a gate and not a style note:
#   `summary` is the short card line, and across the catalogue it is 23-77 chars
#   of one sentence shape ("Shell-less X built on Wolfi." / "... built from
#   source via melange."). At meta-description length a search engine reads ~108
#   pages of that as duplicate boilerplate, so the pages cannot rank against the
#   registries they compete with. `description` is the field that has to differ.
#
# Rules (all failures, not warnings — a new image must not ship without one):
#   present     non-empty `description` on every image
#   length      140-160 chars — under-length wastes the SERP snippet, over-length
#               gets truncated mid-sentence by Google
#   distinct    no two images share a description
#   not-summary description must not merely repeat `summary`
#   no-boilerplate  must not end in the catalogue's stock trailing phrases, which
#               is what made `summary` unusable here in the first place
#
# Dual-mode, like the other reconciliation gates: default asserts (exit 1 on any
# violation), `--report` prints the same findings and exits 0 so it can be run
# for information without blocking. Same entrypoint locally
# (`make check-catalog-descriptions`) and in CI (build.yml validate-catalog).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

CATALOG="catalog.json"
MIN_LEN=140
MAX_LEN=160

MODE="assert"
[ "${1:-}" = "--report" ] && MODE="report"

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }
[ -f "$CATALOG" ] || { echo "$CATALOG not found" >&2; exit 2; }

fail=0
note() { echo "  ✗ $*"; fail=1; }

total=$(jq '.images | length' "$CATALOG")
echo "→ checking $total catalog descriptions (${MIN_LEN}-${MAX_LEN} chars, distinct)"

# Missing or empty.
while IFS= read -r name; do
  [ -n "$name" ] && note "$name: no description field"
done < <(jq -r '.images[] | select((.description // "") | gsub("^\\s+|\\s+$";"") == "") | .name' "$CATALOG")

# Length. Counts characters, not bytes — descriptions contain en dashes.
while IFS=$'\t' read -r name len; do
  [ -n "$name" ] && note "$name: description is $len chars (want ${MIN_LEN}-${MAX_LEN})"
done < <(jq -r --argjson lo "$MIN_LEN" --argjson hi "$MAX_LEN" '
  .images[]
  | select((.description // "") != "")
  | (.description | length) as $l
  | select($l < $lo or $l > $hi)
  | [.name, ($l | tostring)] | @tsv' "$CATALOG")

# Distinctness — the whole point of the field.
while IFS=$'\t' read -r desc names; do
  [ -n "$names" ] && note "duplicate description shared by: $names"
done < <(jq -r '
  [.images[] | select((.description // "") != "")]
  | group_by(.description) | map(select(length > 1))
  | .[] | [(.[0].description[0:40]), ([.[].name] | join(", "))] | @tsv' "$CATALOG")

# Must not simply restate the card line.
while IFS= read -r name; do
  [ -n "$name" ] && note "$name: description merely repeats summary"
done < <(jq -r '
  .images[]
  | select((.description // "") != "" and (.summary // "") != "")
  | select((.description | ascii_downcase | gsub("\\s+";" ")) ==
           (.summary     | ascii_downcase | gsub("\\s+";" ")))
  | .name' "$CATALOG")

# The stock phrases that made `summary` unusable as a meta description.
while IFS=$'\t' read -r name phrase; do
  [ -n "$name" ] && note "$name: description ends in boilerplate \"$phrase\""
done < <(jq -r '
  ["built on Wolfi.", "source via melange.", "built from source via melange."] as $stock
  | .images[]
  | select((.description // "") != "")
  | . as $i
  | ($stock | map(. as $s | select($i.description | endswith($s))) | first) as $hit
  | select($hit != null)
  | [$i.name, $hit] | @tsv' "$CATALOG")

if [ "$fail" -eq 0 ]; then
  echo "✓ all $total descriptions present, distinct, and ${MIN_LEN}-${MAX_LEN} chars"
  exit 0
fi

echo ""
if [ "$MODE" = "report" ]; then
  echo "(report mode — not failing)"
  exit 0
fi
echo "Every catalog.json image needs a distinct ${MIN_LEN}-${MAX_LEN} char \`description\`."
echo "See docs/onboarding.md — it is part of the registration checklist."
exit 1
