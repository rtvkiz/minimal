#!/usr/bin/env bash
# Rolling major/minor tag derivation, shared by build.yml's two publish steps.
#
# Consumers today pin either :latest (breaks on a major bump) or an exact patch
# (frozen forever, including security fixes). The rolling ladder gives them a
# middle option — :3 tracks the 3.x line, :3.21 tracks 3.21.x — so a major
# upgrade stops being all-or-nothing. Same digest, no extra build: these are
# additional tags on the image that was already published.
#
#   derive_version_ladder <version> -> space-separated extra tags (may be empty)
#
# Usage: source this file, then call derive_version_ladder "$VER".
# Self-test: bash .github/scripts/version-ladder.sh --test

derive_version_ladder() {
  local raw="$1" base major minor

  [ -n "$raw" ] || return 0

  # Strip the Wolfi package epoch (-r0, -r12). apko-only images take their
  # version from the SBOM, which carries it (python 3.14.7-r0); source-built
  # images never do.
  base="${raw%-r[0-9]*}"

  # Only pure numeric dotted versions get a ladder. A pre-release or build
  # suffix (1.2.3-rc1, 1.2.3+meta) is skipped — a rolling tag pointing at a
  # pre-release would misrepresent the line.
  case "$base" in
    *[!0-9.]*) return 0 ;;
  esac

  major="${base%%.*}"
  [ -n "$major" ] || return 0

  # Calendar-versioned releases (minio: 2025.10.15) have no meaningful major
  # line; a :2025 tag would imply a support line that does not exist.
  if [ "$major" -ge 1000 ] 2>/dev/null; then
    return 0
  fi

  # x.y.z -> x.y ; x.y -> x.y ; x -> none
  case "$base" in
    *.*.*) minor="${base%.*}" ;;
    *.*)   minor="$base" ;;
    *)     minor="" ;;
  esac

  # 0.x has no stable major line: semver permits breaking changes between 0.x
  # minors, so a rolling :0 tag would promise compatibility we cannot keep.
  # 16 images are on 0.x (thanos, trivy, otelcol, grype, …). There the minor is
  # the compatibility boundary, so emit :0.42 but never :0.
  if [ "$major" = "0" ]; then
    printf '%s' "$minor"
    return 0
  fi

  if [ -n "$minor" ] && [ "$minor" != "$major" ]; then
    printf '%s %s' "$major" "$minor"
  else
    printf '%s' "$major"
  fi
}

# --- self-test -------------------------------------------------------------
if [ "${1:-}" = "--test" ]; then
  fail=0
  check() {
    local in="$1" want="$2" got
    got="$(derive_version_ladder "$in")"
    if [ "$got" = "$want" ]; then
      printf '  ok    %-14s -> [%s]\n' "$in" "$got"
    else
      printf '  FAIL  %-14s -> [%s], want [%s]\n' "$in" "$got" "$want"
      fail=1
    fi
  }
  check "3.4.0"       "3 3.4"      # source-built semver
  check "8.10.0"      "8 8.10"     # redis
  check "3.14.7-r0"   "3 3.14"     # apko-only, epoch stripped
  check "1.26.5-r2"   "1 1.26"     # go
  check "18.4-r7"     "18 18.4"    # postgres, two-part + epoch
  check "3.53.4"      "3 3.53"     # sqlite, no epoch
  check "2025.10.15"  ""           # minio, calendar-versioned
  check "0.42.4"      "0.42"       # thanos, 0.x -> minor only
  check "0.73.0"      "0.73"       # trivy
  check "1.2.3-rc1"   ""           # pre-release
  check "1.2.3+meta"  ""           # build metadata
  check "7"           "7"          # single component
  check ""            ""           # empty
  [ "$fail" -eq 0 ] && echo "version-ladder: all cases passed"
  exit "$fail"
fi
