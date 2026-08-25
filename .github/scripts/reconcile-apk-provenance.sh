#!/usr/bin/env bash
#
# Separate findings that are IN THE IMAGE from findings that are only an
# artefact of sharing a package name with Wolfi/Chainguard.
#
# THE PROBLEM. Our images are built from Wolfi packages, so their apk database
# says "this is a Wolfi system" and grype looks up every installed package name
# in Wolfi/Chainguard's distro advisory feed — including the packages we build
# ourselves. Their feed records fixes against THEIR rebuild counter:
#
#   installed gitleaks 8.30.1-r0        (our first build of 8.30.1)
#   "fixed in" gitleaks 8.30.1-r13      (Chainguard's fourteenth build of 8.30.1)
#
# r0 < r13, so we are reported as unpatched. But -rN is a per-distro build
# counter, not a patch level: both start at zero and they count different
# distros' build events. Comparing them across distros is not a meaningful
# operation, and grype has no way to know our apk is not one of theirs.
#
# On 2026-08-24 this accounted for 439 of 648 findings — 68% of the catalogue's
# reported CVEs, none of them present in the images.
#
# THE RULE. Three outcomes, decided by evidence rather than by suppression:
#
#   substantiated    the vulnerable component is actually in the image — grype
#                    matched the module/jar/gem/crate itself, or the apk is a
#                    genuine Wolfi package we did not build, or the same
#                    advisory ALSO matched real binary contents
#
#   unsubstantiated  our own package, no corroboration in the contents, and the
#                    fix is a same-version rebuild. A rebuild at the same
#                    upstream version cannot patch the application's own
#                    source, so the fix must live in a dependency or the
#                    compiler — exactly what our from-source rebuild picks up.
#                    Excluded from the headline count, still reported.
#
#   needs_review     our own package, no corroboration, but the fix requires a
#                    genuinely NEWER UPSTREAM VERSION. That normally means we
#                    are stale and the finding is real. NEVER auto-excluded.
#                    This is the safety valve that stops this script becoming a
#                    suppression mechanism.
#
# Nothing is deleted. `unsubstantiated` is reported alongside the headline so a
# finding that later gains corroboration moves into the count on its own, and
# so the exclusion can always be audited.
#
# Usage: reconcile-apk-provenance.sh <grype-report.json> [repo-root]
set -euo pipefail

REPORT="${1:?grype report required}"
ROOT="${2:-.}"

# Package names we build ourselves. The melange recipes are the source of
# truth: package.name plus any subpackages (2-space indent — pipeline steps
# nest deeper, so they are not picked up).
ours=$(
  for f in "$ROOT"/images/*/melange.yaml; do
    [ -f "$f" ] || continue
    awk '/^package:/{p=1} p&&/^  name:/{print $2; exit}' "$f"
    awk '/^subpackages:/{s=1} s&&/^  - name:/{print $3}' "$f"
  done | sort -u | jq -R . | jq -s .
)

jq --argjson ours "$ours" '
  [ .matches[] ] as $m
  # Advisory IDs that matched real binary contents (go-module, java-archive,
  # gem, rust-crate, stdlib …). This is the ground truth for what is actually
  # shipped, and it is what corroborates — or fails to corroborate — an
  # apk-name match.
  | ( [ $m[] | select(.artifact.type != "apk") | .vulnerability.id ] | unique ) as $lang
  | def upstream: sub("-r[0-9]+$"; "");
    def klass($a; $v):
      ( ((($v.fix.versions // [])[0]) // "") as $fix
        | if   $a.type != "apk"                then "substantiated"
          elif ($a.name | IN($ours[]) | not)   then "substantiated"
          elif ($v.id   | IN($lang[]))         then "substantiated"
          elif ($fix == "")                    then "unsubstantiated"
          elif (($a.version | upstream) == ($fix | upstream))
                                               then "unsubstantiated"
          else                                      "needs_review"
          end );
    [ $m[] | . + {klass: klass(.artifact; .vulnerability)} ] as $tagged
  | def counts($set):
      ( [ $set[] ] as $s
        | def sev($l): [ $s[] | select(.vulnerability.severity | ascii_upcase == $l) ] | length;
          { critical:   sev("CRITICAL"),
            high:       sev("HIGH"),
            medium:     sev("MEDIUM"),
            low:        sev("LOW"),
            negligible: sev("NEGLIGIBLE"),
            unknown:    sev("UNKNOWN") }
          | . + {total: ($s | length)} );
    [ $tagged[] | select(.klass != "unsubstantiated") ] as $counted
  | [ $tagged[] | select(.klass == "unsubstantiated") ] as $excluded
  | [ $tagged[] | select(.klass == "needs_review")    ] as $review
  | {
      counted:         counts($counted),
      unsubstantiated: counts($excluded),
      needs_review: [ $review[] | {
        id:       .vulnerability.id,
        package:  .artifact.name,
        installed:.artifact.version,
        fixed_in: ((.vulnerability.fix.versions // [])[0] // null)
      } ] | unique,
      # (package, id) pairs, so any consumer can exclude exactly these matches
      # instead of re-deriving the rule and drifting from it.
      excluded_pairs: [ $excluded[] | {package: .artifact.name, id: .vulnerability.id} ] | unique
    }
' "$REPORT"
