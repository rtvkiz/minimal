#!/usr/bin/env bash
# Assert the README's image count matches catalog.json, and that every image
# category is one the catalog declares.
#
# The count sat at 96 while the catalog grew to 100 — in the badge, the nav
# link and a section heading. Nothing noticed, because nothing was looking. The
# category check exists for the same reason: metrics-server was filed under
# "Kubernetes", which is not a declared category, so the site rendered it as an
# orphan group of one.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
note() { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail + 1)); }

want=$(jq '.images | length' catalog.json)

# Any bare number in the README that is meant to be the image count.
badge=$(grep -oE 'Images-[0-9]+-' README.md | grep -oE '[0-9]+' | head -1)
[ "${badge:-}" = "$want" ] || note "README badge says ${badge:-<none>}, catalog has $want images"

prose=$(grep -oE '\b(all )?[0-9]{2,3} images\b' README.md | grep -oE '[0-9]{2,3}' | sort -u)
for n in $prose; do
  [ "$n" = "$want" ] || note "README prose says '$n images', catalog has $want"
done

undeclared=$(jq -r '([.images[].category] | unique) - .categories | join(", ")' catalog.json)
[ -z "$undeclared" ] || note "catalog.json images use undeclared categories: $undeclared"

if [ "$fail" -eq 0 ]; then
  echo "✓ docs currency: README matches catalog.json ($want images), categories all declared"
  exit 0
fi
echo "✗ docs currency: $fail problem(s)"
exit 1
