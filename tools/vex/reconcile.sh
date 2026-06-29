#!/usr/bin/env bash
# Reconcile a VEX document against a fresh grype scan so suppressions can't go
# stale and silently feed users false information.
#
# For every not_affected/fixed statement in the VEX file, it checks the CVE
# against the current raw scan and reports two drift conditions:
#
#   STALE        the suppressed CVE is no longer in the scan (dep was fixed or
#                removed). The statement now suppresses nothing; remove it so a
#                future re-introduction can't be auto-hidden without re-review.
#
#   NOW-FIXABLE  a `fixed` statement is still present AND an upstream fix newer
#                than the installed version now exists. A `fixed` statement
#                asserts the shipped version already contains the fix, so a
#                higher fix version proves that claim false — bump the dep
#                instead of suppressing. (Version-compared, so an advisory whose
#                "fix" is <= what we ship is NOT flagged.) This is intentionally
#                NOT applied to `not_affected`: a reachability justification (the
#                vulnerable code is absent or off the execute path) is
#                independent of version, so a newer upstream release does not
#                make it dishonest.
#
# Usage:  reconcile.sh <grype.json> <vex.openvex.json>
# Exit:   non-zero if any NOW-FIXABLE drift is found (the integrity gate).
#         STALE is reported as a warning (exit stays 0 unless --strict).
set -euo pipefail

STRICT=0; JSON=0
while [ "${1:-}" = "--strict" ] || [ "${1:-}" = "--json" ]; do
  [ "$1" = "--strict" ] && STRICT=1
  [ "$1" = "--json" ] && JSON=1
  shift
done
GRYPE="${1:?grype json required}"
VEX="${2:?vex file required}"
IMG=$(basename "$VEX" .openvex.json)

# Suppressing statements: "{id}<TAB>{status}" for not_affected | fixed.
mapfile -t SUP < <(jq -r '.statements[]? | select(.status=="not_affected" or .status=="fixed") | "\(.vulnerability.name)\t\(.status)"' "$VEX" 2>/dev/null || true)
if [ "${#SUP[@]}" -eq 0 ]; then
  [ "$JSON" -eq 1 ] && echo '{"stale":[],"now_fixable":[]}' || echo "ok   $IMG: no suppressing VEX statements"
  exit 0
fi

# Map of present CVE id -> "installed_version<TAB>fix_version" from the scan.
SCAN=$(jq -r '.matches[] | "\(.vulnerability.id)\t\(.artifact.version)\t\(.vulnerability.fix.versions[0] // "")"' "$GRYPE" 2>/dev/null || true)

STALE_IDS=(); FIXABLE=()
ver_gt() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]; }

for entry in "${SUP[@]}"; do
  id=${entry%%$'\t'*}; status=${entry##*$'\t'}
  line=$(awk -F'\t' -v v="$id" '$1==v{print; exit}' <<<"$SCAN")
  if [ -z "$line" ]; then
    STALE_IDS+=("$id"); continue
  fi
  # NOW-FIXABLE only applies to `fixed` claims. A not_affected statement is a
  # reachability assertion independent of version — a newer fix existing does
  # not make it dishonest, so don't flag it (see telegraf's rclone rc-server
  # CVEs: fixed upstream, but telegraf never starts the rc daemon).
  [ "$status" = "fixed" ] || continue
  installed=$(cut -f2 <<<"$line"); fix=$(cut -f3 <<<"$line")
  # strip a leading v and any +incompatible / pseudo suffix for the compare
  ic=${installed#v}; ic=${ic%%+*}; fc=${fix#v}; fc=${fc%%+*}
  if [ -n "$fix" ] && ver_gt "$fc" "$ic"; then
    FIXABLE+=("$id|$fix|$installed")
  fi
done

if [ "$JSON" -eq 1 ]; then
  jq -nc --args '{stale: $ARGS.positional}' "${STALE_IDS[@]}" > /tmp/.vexstale.$$
  printf '%s\n' "${FIXABLE[@]}" | jq -Rc 'select(length>0)|split("|")|{id:.[0],fix:.[1],installed:.[2]}' | jq -sc '{now_fixable:.}' > /tmp/.vexfix.$$
  jq -cs '.[0] * .[1]' /tmp/.vexstale.$$ /tmp/.vexfix.$$; rm -f /tmp/.vexstale.$$ /tmp/.vexfix.$$
  [ "${#FIXABLE[@]}" -gt 0 ] && exit 1 || exit 0
fi

for id in "${STALE_IDS[@]}"; do
  echo "STALE        $IMG: VEX suppresses $id but it is not in the current scan — remove the statement"
done
for f in "${FIXABLE[@]}"; do
  IFS='|' read -r id fix inst <<<"$f"
  echo "NOW-FIXABLE  $IMG: VEX suppresses $id but fix $fix > installed $inst — bump the dep, don't suppress"
done
[ "${#STALE_IDS[@]}" -eq 0 ] && [ "${#FIXABLE[@]}" -eq 0 ] && echo "ok   $IMG: all ${#SUP[@]} VEX suppression(s) still valid"
{ [ "${#FIXABLE[@]}" -gt 0 ] || { [ "$STRICT" -eq 1 ] && [ "${#STALE_IDS[@]}" -gt 0 ]; }; } && exit 1
exit 0
