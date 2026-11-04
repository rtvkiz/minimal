#!/usr/bin/env bash
# Regression tests for .github/scripts/reconcile-apk-provenance.sh.
#
# The reconciler decides which grype findings count toward every published CVE
# number (build summaries, the image dashboard, /compare). It has failed in
# both directions, so each direction gets a fixture from a real scan:
#
#   grype-2026-11-01    our own `grype` apk matched in the Wolfi distro feed with
#                       "fixed in 0.121.0-r1" against our 0.121.0-r0 - a rebuild
#                       counter phantom. Must stay EXCLUDED. Its docker/docker
#                       go-module findings are real contents and must COUNT.
#
#   haproxy-2026-11-01  our own `haproxy` apk matched by NVD CPE (no fix
#                       version) while we were stuck on 3.4.0. These were real:
#                       the 3.4.7 bump removed them. Must COUNT, as needs_review.
#                       The reconciler used to exclude them, so haproxy scored 0.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fx="$root/tests/apk-provenance-fixtures"
rec="$root/.github/scripts/reconcile-apk-provenance.sh"
fail=0

check() {  # check <fixture> <jq expression that must be true> <description>
  local out
  out=$("$rec" "$fx/$1.json" "$root")
  if jq -e "$2" <<<"$out" >/dev/null; then
    echo "  ok    $1: $3"
  else
    echo "  FAIL  $1: $3"
    echo "        got: $(jq -c '{counted: .counted.total, excluded: .unsubstantiated.total, needs_review, excluded_pairs}' <<<"$out")"
    fail=1
  fi
}

echo "reconcile-apk-provenance"
check grype-2026-11-01 '.unsubstantiated.total == 2' \
  "Wolfi-feed -r0 vs -r1 phantoms are excluded"
check grype-2026-11-01 '[.excluded_pairs[].package] | unique == ["grype"]' \
  "only the apk-name matches are excluded"
check grype-2026-11-01 '.counted.total == 5' \
  "real go-module findings are counted"
check haproxy-2026-11-01 '.counted.total == 2 and .counted.critical == 1 and .counted.high == 1' \
  "NVD CPE matches on our own package are counted"
check haproxy-2026-11-01 '(.needs_review | map(.id) | sort) == ["CVE-2026-55203","CVE-2026-55204"]' \
  "and surfaced as needs_review"
check haproxy-2026-11-01 '.unsubstantiated.total == 0' \
  "and never excluded"

[ "$fail" = 0 ] && echo "✓ reconcile-apk-provenance: all checks passed" || { echo "✗ reconcile-apk-provenance: failures above"; exit 1; }
