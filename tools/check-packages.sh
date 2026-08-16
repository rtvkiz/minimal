#!/usr/bin/env bash
# Assert the apk-package invariants that keep images scannable.
#
# These rules are stated in docs/onboarding.md but nothing enforced them, which
# is how `nats` shipped named after the NATS *CLI* while catalog.json correctly
# said nats-server — the repo contradicted itself and no gate noticed.
#
#   1. package.name carries no -minimal suffix.
#      A suffix breaks BOTH grype paths: no secdb entry, and a CPE
#      (cpe:2.3:a:foo-minimal:foo-minimal:*) that matches nothing in NVD.
#      Measured: haproxy-minimal 0 findings, haproxy 14, identical version.
#   2. package.name == catalog.json primary_package.
#      Disagreement means one of them is describing different software.
#   3. Wolfi ships the same name  =>  dependencies.provider-priority: 100.
#      apko resolves a top-level name across ALL repos by highest version and
#      does not prefer the local one, so without it apk can silently install
#      Wolfi's build instead of ours.
#   4. Every apko variant references the package name that melange builds.
#
# Modes: assert (default, non-zero on any violation) and --report (list and
# exit 0) for local use. The Wolfi check needs the APKINDEX; if it cannot be
# fetched the run FAILS rather than reporting "clear", because a missing index
# silently marked every package collision-free twice during the rename.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

MODE=assert
[ "${1:-}" = "--report" ] && MODE=report

IDX=${APKINDEX_CACHE:-/tmp/APKINDEX}
fail=0
note() { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail + 1)); }

if [ ! -s "$IDX" ]; then
  tmp=$(mktemp -d)
  if curl -sSfL --connect-timeout 10 --max-time 120 --retry 3 --retry-delay 5 \
       https://packages.wolfi.dev/os/x86_64/APKINDEX.tar.gz -o "$tmp/i.tar.gz"; then
    tar -xzOf "$tmp/i.tar.gz" APKINDEX > "$IDX" || : > "$IDX"
  fi
  rm -rf "$tmp"
fi
if [ ! -s "$IDX" ] || [ "$(wc -l < "$IDX")" -lt 100000 ]; then
  echo "✗ could not fetch a complete Wolfi APKINDEX — refusing to report" >&2
  echo "  (a truncated index makes every package look collision-free)" >&2
  exit 1
fi

images=$(jq -r '.images[].name' catalog.json)
checked=0

for img in $images; do
  mf="images/$img/melange.yaml"
  [ -f "$mf" ] || continue          # apko-only: no apk package of ours to check
  checked=$((checked + 1))

  pkg=$(yq e '.package.name' "$mf")
  prio=$(yq e '.package.dependencies.provider-priority // "none"' "$mf")
  cat_pkg=$(jq -r --arg n "$img" '.images[] | select(.name==$n) | .primary_package // "unset"' catalog.json)

  case "$pkg" in
    *-minimal) note "$img: package.name '$pkg' still carries the -minimal suffix" ;;
  esac

  if [ "$cat_pkg" = "unset" ]; then
    note "$img: catalog.json has no primary_package (should be '$pkg')"
  elif [ "$cat_pkg" != "$pkg" ]; then
    note "$img: catalog primary_package '$cat_pkg' != melange package.name '$pkg'"
  fi

  if grep -q "^P:${pkg}\$" "$IDX" && [ "$prio" != "100" ]; then
    wv=$(awk -v p="^P:${pkg}\$" '$0~p{f=1;next} f&&/^V:/{print substr($0,3);exit}' "$IDX")
    note "$img: Wolfi ships '$pkg' ($wv) but provider-priority is $prio (want 100)"
  fi

  for af in "images/$img"/apko/*.yaml; do
    [ -f "$af" ] || continue
    grep -qE "^\s*- ${pkg}\$" "$af" || \
      note "$(basename "$af"): does not reference package '$pkg'"
  done
done

echo
# Floor check. The loop skips any catalog image whose melange.yaml it cannot
# find, so a wrong path makes this script report "0 images clean" and exit 0 —
# absence read as success, the exact failure this gate exists to prevent. If
# almost nothing was checked, the paths are wrong, not the repo.
min_expected=${CHECK_PACKAGES_MIN:-80}
if [ "$checked" -lt "$min_expected" ]; then
  echo "✗ only $checked melange-built image(s) found, expected >= $min_expected" >&2
  echo "  the melange paths this script derives are almost certainly wrong" >&2
  exit 1
fi

if [ "$fail" -eq 0 ]; then
  echo "✓ apk package invariants: $checked melange-built images clean"
  exit 0
fi
echo "✗ apk package invariants: $fail violation(s) across $checked images"
[ "$MODE" = "report" ] && exit 0
exit 1
