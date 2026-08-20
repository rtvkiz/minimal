#!/usr/bin/env bash
#
# Bump the pinned language-toolchain packages in melange build environments to
# the newest version Wolfi publishes.
#
# Why this exists: build environments pin versioned toolchain packages
# (go-1.26, nodejs-26, rust-1.97) rather than the bare virtual provider, because
# a bare provider silently resolves to the newest version and changes the
# compiler mid-build (go-1.27 did exactly that on 2026-08-19 and broke trivy).
# Pinning removes the surprise, but it must not become a manual chore — this
# script is the other half: it moves the pins forward automatically.
#
# The pins are NOT hand-maintained decisions. Every run bumps EVERY image to the
# newest toolchain, including images a previous run had to hold back. CI's
# per-image build is the probe: whatever compiles keeps the new toolchain,
# whatever fails gets reverted by the repair step and stays on the old one until
# upstream catches up. A pin is therefore the last known-good probe result, and
# a held-back image clears itself with no human involvement.
#
# Nothing here is specific to a version or a language: the current pin is read
# from the files, the target is read from the Wolfi index, and every family in
# TOOLCHAINS is handled by the same code path.
#
# Usage:
#   bump-toolchain-pins.sh [--dry-run] [--packages <file>]
#     --dry-run     print what would change, write nothing
#     --packages    "name version" listing (defaults to fetching the APKINDEX)
#
# Output (to $GITHUB_OUTPUT when set): has_changes, summary, branch_suffix
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

DRY_RUN=false
PKGS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  DRY_RUN=true; shift ;;
    --packages) PKGS="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Toolchain families to track. A family is a package prefix whose versioned
# form is "<prefix>-<major>[.<minor>]". Add a row when a new language is
# onboarded; check-toolchain-pins.sh enforces that nothing uses the bare form.
TOOLCHAINS=(go nodejs rust)

out="${GITHUB_OUTPUT:-/dev/null}"

if [ -z "$PKGS" ]; then
  PKGS=$(mktemp)
  curl -fsS --retry 3 --retry-all-errors --max-time 180 \
    https://packages.wolfi.dev/os/x86_64/APKINDEX.tar.gz -o /tmp/_tc_idx.tar.gz
  tar -xzOf /tmp/_tc_idx.tar.gz APKINDEX \
    | awk '/^P:/{p=substr($0,3)} /^V:/{if(p!=""){print p, substr($0,3); p=""}}' > "$PKGS"
  rm -f /tmp/_tc_idx.tar.gz
fi

SUMMARY=""
SUFFIX=""
CHANGED=false

for fam in "${TOOLCHAINS[@]}"; do
  # Newest versioned package for this family. Restricted to "<fam>-<numbers>"
  # so variants (nodejs-26-minimal, go-1.27-doc, rust-1.97-src) never win.
  candidates=$(awk -v f="$fam" '$1 ~ "^"f"-[0-9]+(\\.[0-9]+)?$" {print $1}' "$PKGS" | sort -u -V)
  # Family-specific validity rules. Node LTS lines are EVEN majors (20/22/24…);
  # odd majors are short-lived non-LTS and must never be a bump target. Same
  # rule the existing Node step in update-wolfi-packages.yml already applies.
  if [ "$fam" = "nodejs" ]; then
    candidates=$(printf '%s\n' "$candidates" | awk -F- 'NF==2 && ($2 % 2)==0')
  fi
  latest=$(printf '%s\n' "$candidates" | grep -v '^$' | tail -1)
  [ -n "$latest" ] || { echo "  $fam: no versioned package in index, skipping"; continue; }

  # Every distinct pin currently in use for this family.
  # Strip the YAML list marker only — `tr -d '-'` would also eat the dash
  # inside go-1.26 and match nothing.
  current=$(grep -hoE "^[[:space:]]*-[[:space:]]+${fam}-[0-9]+(\.[0-9]+)?[[:space:]]*$" \
    images/*/melange.yaml 2>/dev/null \
    | sed -E 's/^[[:space:]]*-[[:space:]]+//; s/[[:space:]]*$//' | sort -u || true)
  [ -n "$current" ] || { echo "  $fam: not used by any build environment"; continue; }

  for cur in $current; do
    [ "$cur" = "$latest" ] && continue
    # Never move a pin backwards: the index can briefly list an older build, and
    # a downgrade would silently undo a working toolchain.
    hi=$(printf '%s\n%s\n' "$cur" "$latest" | sort -V | tail -1)
    if [ "$hi" != "$latest" ]; then
      echo "  $fam: index newest ($latest) is not newer than $cur — not downgrading"
      continue
    fi
    files=$(grep -lE "^[[:space:]]*-[[:space:]]+${cur}[[:space:]]*$" images/*/melange.yaml 2>/dev/null || true)
    [ -n "$files" ] || continue
    n=$(printf '%s\n' "$files" | grep -c .)
    echo "  $fam: $cur -> $latest ($n image(s))"
    CHANGED=true
    SUMMARY="${SUMMARY}- \`${cur}\` → \`${latest}\` (${n} image(s))"$'\n'
    [ -n "$SUFFIX" ] && SUFFIX="${SUFFIX}-"
    SUFFIX="${SUFFIX}${latest}"
    if [ "$DRY_RUN" = false ]; then
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        sed -i -E "s|^([[:space:]]*-[[:space:]]+)${cur}[[:space:]]*$|\1${latest}|" "$f"
      done <<< "$files"
    fi
  done
done

if [ "$CHANGED" = false ]; then
  echo "All toolchain pins are already current."
  { echo "has_changes=false"; } >> "$out"
  exit 0
fi

if [ "$DRY_RUN" = true ]; then
  echo "(dry run — no files written)"
  { echo "has_changes=false"; } >> "$out"
  exit 0
fi

# --- validate the rewrite before anyone sees it -----------------------------
# A bad sed here would be spliced into every Go image at once, so assert the
# shape rather than trusting the substitution.
fail=0
for f in $(git diff --name-only -- images/); do
  # still valid YAML
  if command -v yq >/dev/null 2>&1; then
    yq -e '.' "$f" >/dev/null 2>&1 || { echo "  ✗ $f: no longer parses" >&2; fail=1; }
  fi
  # Every changed line must be a toolchain pin and nothing else. Counting
  # lines is not enough: an image can legitimately pin two toolchains (gitea
  # builds a Go binary AND a Node frontend, so it moves +2/-2), while a sed
  # that clobbered unrelated content would also change "one line".
  stray=$(git diff -U0 -- "$f" \
    | grep -E '^[+-][^+-]' \
    | grep -vE "^[+-][[:space:]]*-[[:space:]]+($(IFS='|'; echo "${TOOLCHAINS[*]}"))-[0-9]+(\.[0-9]+)?[[:space:]]*$" \
    || true)
  if [ -n "$stray" ]; then
    echo "  ✗ $f: diff touches non-toolchain lines:" >&2
    printf '      %s\n' "$stray" >&2
    fail=1
  fi
  # and the file must still pin every family it had before
  ins=$(git diff --numstat -- "$f" | awk '{print $1}')
  del=$(git diff --numstat -- "$f" | awk '{print $2}')
  [ "$ins" = "$del" ] \
    || { echo "  ✗ $f: added/removed line count differs (+$ins/-$del)" >&2; fail=1; }
done
# and no bare provider was introduced
./scripts/check-toolchain-pins.sh >/dev/null || fail=1
if [ "$fail" -ne 0 ]; then
  echo "✗ toolchain bump produced an unexpected diff — refusing to continue" >&2
  git checkout -- images/ 2>/dev/null || true
  exit 1
fi

echo "✓ bumped $(git diff --name-only -- images/ | wc -l) file(s), all validated"
{
  echo "has_changes=true"
  echo "branch_suffix=${SUFFIX}"
  echo "summary<<EOF_SUMMARY"
  printf '%s' "$SUMMARY"
  echo "EOF_SUMMARY"
} >> "$out"
