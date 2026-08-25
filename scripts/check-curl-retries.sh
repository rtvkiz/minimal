#!/usr/bin/env bash
#
# Assert that every source download in a melange recipe retries patiently.
#
# Upstream mirrors rate-limit. When they do, curl's default backoff is far too
# short to survive it and the build dies on a condition that clears by itself
# minutes later — a red `main`, a skipped site deploy, and a human needed to
# press re-run.
#
# Three of these in four days, none code-caused:
#
#   2026-08-22  kafka       429 from the Apache mirror   (--retry 5, ~31s)
#   2026-08-23  opensearch  403 from the CDN             (--retry 5, ~31s)
#   2026-08-25  flink       429 from the Apache mirror   (--retry 3, ~20s)
#
# `--retry N` alone uses curl's exponential backoff (1,2,4,8,… seconds), so the
# total wait is roughly 2^N seconds. At N=5 that is ~31s, which demonstrably
# loses the race against a CDN rate-limit; at N=8 it is ~255s, which is long
# enough to ride one out while still retrying within a second of a brief blip.
#
# `--retry-delay` is deliberately NOT used: it replaces the exponential backoff
# with a fixed interval, which is the worst of both — slow to recover from a
# blip and still too short in total for a sustained block.
#
# `--retry-all-errors` is required because curl otherwise retries only a narrow
# set of conditions and treats an HTTP error body as a successful transfer.
#
# Same entrypoint locally (`make check-curl-retries`) and in CI, so they cannot
# drift.
#
# Usage:
#   check-curl-retries.sh            assert (exit 1 on any weak download)
#   check-curl-retries.sh --report   list findings, always exit 0
set -euo pipefail

MIN_RETRY=8
mode="assert"
[ "${1:-}" = "--report" ] && mode="report"

fail=0
found=0

while IFS= read -r recipe; do
  # Join backslash-continued lines so a curl invocation split across several
  # lines is examined as one command.
  joined=$(sed -e ':a' -e '/\\$/{N;s/\\\n//;ta' -e '}' "$recipe")

  while IFS= read -r line; do
    case "$line" in
      *curl*) ;;
      *) continue ;;
    esac

    # Skip anything that is not actually fetching a payload:
    #   -I / --head        availability probe, deliberately fast
    #   --with-curl etc.   a configure flag that merely contains the word
    case "$line" in
      *' -sfI '*|*' -I '*|*--head*) continue ;;
      *--with-curl*|*-lcurl*) continue ;;
    esac
    # Must be an invocation, not a mention inside a comment.
    case "$line" in
      *'#'*curl*) continue ;;
    esac
    printf '%s' "$line" | grep -qE '(^|[^-[:alnum:]])curl[[:space:]]' || continue

    found=$((found + 1))
    n=$(printf '%s' "$line" | grep -oE -- '--retry[[:space:]]+[0-9]+' | grep -oE '[0-9]+' | head -1)

    why=""
    if [ -z "$n" ]; then
      why="no --retry"
    elif [ "$n" -lt "$MIN_RETRY" ]; then
      why="--retry $n (minimum $MIN_RETRY)"
    elif ! printf '%s' "$line" | grep -q -- '--retry-all-errors'; then
      why="missing --retry-all-errors"
    elif printf '%s' "$line" | grep -q -- '--retry-delay'; then
      why="--retry-delay defeats exponential backoff"
    fi

    if [ -n "$why" ]; then
      fail=$((fail + 1))
      snippet=$(printf '%s' "$line" | sed 's/^[[:space:]]*//' | cut -c1-90)
      echo "::error file=${recipe}::${why}"
      printf '  %-34s %s\n     %s\n' "$recipe" "$why" "$snippet" >&2
    fi
  done <<EOF
$joined
EOF
done < <(find images -name melange.yaml | sort)

if [ "$fail" -gt 0 ]; then
  echo >&2
  echo "$fail of $found download(s) retry too impatiently." >&2
  echo "Use: curl ... --retry ${MIN_RETRY} --retry-all-errors" >&2
  [ "$mode" = "assert" ] && exit 1
  exit 0
fi

echo "✓ all $found melange download(s) retry with --retry ${MIN_RETRY}+ --retry-all-errors"
