#!/usr/bin/env bash
#
# Structural invariants every published image must hold, checked on the built
# image itself rather than trusted to each image's hand-written test.sh:
#
#   prod  runs as nonroot             (unless a prod-root exception)
#   prod  has no /bin/sh              (unless a prod-shell exception)
#   prod  has no bash, no apk-tools   (always, even with a shell exception)
#   dev   has a shell and apk-tools   (the -dev contract, as Chainguard's)
#   all   installs OUR build of the primary package, at the recipe's version
#         (source-built only: catches Wolfi's package silently winning apk
#         resolution over the local one — see provider-priority in onboarding.md)
#
# A per-image test.sh can only assert what its author remembered to; the 2026-11
# audit found 108 tests never checked nonroot and 142 never checked the version.
#
# Reads only the image config and /lib/apk/db/installed (via docker cp from a
# created, never-started container), so it works on shell-less images.
#
# MODE=report (default): print findings as ::warning annotations, always exit 0.
#   Any internal error is reported and ALSO exits 0 — in report mode this
#   script must never be the reason a build goes red.
# MODE=assert: exit 1 on any finding.
#
# Usage: check-image-structure.sh <image-ref> <name> <prod|dev> [melange.yaml]
set -uo pipefail

IMAGE="${1:?image ref required}"
NAME="${2:?image name required}"
VARIANT="${3:?variant required (prod|dev)}"
MELANGE="${4:-}"
MODE="${MODE:-report}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EXC="${EXCEPTIONS:-$ROOT/.github/image-structure-exceptions.txt}"

findings=()
find_() { findings+=("$1"); }

internal_error() {
  echo "::warning title=image-structure ${NAME}-${VARIANT}::check could not run: $1"
  if [ "$MODE" = assert ]; then exit 1; fi
  exit 0
}

has_exception() {  # <check> — true only for an entry that carries a reason
  [ -r "$EXC" ] || return 1
  awk -v c="$1" -v n="$NAME" '$1==c && $2==n && NF>=3 {f=1} END {exit !f}' "$EXC"
}
exception_reason() {  # <check> — print the reason text, empty if none
  [ -r "$EXC" ] || return 0
  awk -v c="$1" -v n="$NAME" '$1==c && $2==n && NF>=3 {$1=$2=""; print; exit}' "$EXC"
}

cid=$(docker create "$IMAGE" 2>/dev/null) || internal_error "docker create $IMAGE failed"
work=$(mktemp -d)
trap 'docker rm -f "$cid" >/dev/null 2>&1; rm -rf "$work"' EXIT

# exists <path>: true if the path exists in the image (as a file or symlink).
exists() { docker cp "$cid:$1" - >/dev/null 2>&1; }

docker cp "$cid:/lib/apk/db/installed" - 2>/dev/null | tar -xOf - > "$work/installed" 2>/dev/null
[ -s "$work/installed" ] || internal_error "no /lib/apk/db/installed in image"

# installed <pkg>: print the installed version of <pkg>, empty if absent.
installed() { awk -v p="$1" '/^P:/{cur=substr($0,3)} /^V:/{if (cur==p) {print substr($0,3); exit}}' "$work/installed"; }

user=$(docker image inspect -f '{{.Config.User}}' "$IMAGE" 2>/dev/null) || internal_error "docker image inspect failed"
uid="${user%%:*}"

sh=false;   { exists /bin/sh || exists /usr/bin/sh; } && sh=true
bash=false; { exists /bin/bash || exists /usr/bin/bash; } && bash=true
apk=false;  [ -n "$(installed apk-tools)" ] && apk=true

if [ "$VARIANT" = prod ]; then
  if [ -z "$uid" ] || [ "$uid" = 0 ] || [ "$uid" = root ]; then
    has_exception prod-root || find_ "prod runs as root (USER='${user}')"
  fi
  if [ "$sh" = true ] && ! has_exception prod-shell; then
    find_ "prod contains /bin/sh with no prod-shell exception"
  fi
  # bash is a second shell on top of sh: allowed only where the exception's
  # reason names it (the launcher really is a bash script).
  if [ "$bash" = true ] && ! exception_reason prod-shell | grep -qi bash; then
    find_ "prod contains bash (no prod-shell exception names bash)"
  fi
  if [ "$apk" = true ]; then find_ "prod contains apk-tools"; fi
  # An exception the image no longer needs is drift, not a violation: say so,
  # never fail on it, so the list shrinks as images improve.
  if [ "$sh" != true ] && has_exception prod-shell; then
    echo "::notice title=image-structure ${NAME}-${VARIANT}::prod-shell exception is unused (no /bin/sh in image) — remove it"
  fi
  if [ -n "$uid" ] && [ "$uid" != 0 ] && [ "$uid" != root ] && has_exception prod-root; then
    echo "::notice title=image-structure ${NAME}-${VARIANT}::prod-root exception is unused (runs as ${user}) — remove it"
  fi
else
  if [ "$sh" != true ]; then find_ "dev has no /bin/sh"; fi
  if [ "$apk" != true ]; then find_ "dev has no apk-tools"; fi
fi

if [ -n "$MELANGE" ] && [ -f "$MELANGE" ]; then
  pkg=$(awk '/^package:/{p=1} p&&/^  name:/{print $2; exit}' "$MELANGE")
  ver=$(awk '/^package:/{p=1} p&&/^  version:/{print $2; exit}' "$MELANGE" | tr -d '"')
  epoch=$(awk '/^package:/{p=1} p&&/^  epoch:/{print $2; exit}' "$MELANGE")
  want="${ver}-r${epoch:-0}"
  got=$(installed "$pkg")
  if [ -z "$got" ]; then
    find_ "primary package '$pkg' is not installed"
  elif [ "$got" != "$want" ]; then
    find_ "primary package '$pkg' is $got, recipe says $want (another repository's build won?)"
  fi
fi

printf '%s %-5s user=%s sh=%s bash=%s apk=%s findings=%d\n' \
  "$NAME" "$VARIANT" "${user:-<unset>}" "$sh" "$bash" "$apk" "${#findings[@]}"
for f in "${findings[@]}"; do
  echo "::warning title=image-structure ${NAME}-${VARIANT}::$f"
done
if [ -n "${GITHUB_STEP_SUMMARY:-}" ] && [ "${#findings[@]}" -gt 0 ]; then
  { echo "### Image structure: ${NAME}-${VARIANT} (${MODE})"; for f in "${findings[@]}"; do echo "- $f"; done; } >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$MODE" = assert ] && [ "${#findings[@]}" -gt 0 ]; then exit 1; fi
exit 0
