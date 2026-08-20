#!/usr/bin/env bash
#
# Test the build-failure classifier against fixtures whose expected verdict is
# encoded in the filename extension (.build / .transient / .unknown).
#
# The fixtures are drawn from failures this repo actually hit on 2026-08-19/20,
# so they encode real signatures rather than invented ones. Notably
# timestamp-429-not-ratelimit.build is a regression test: a first version matched
# a bare "429" and classified every compile failure as transient, because GitHub
# log timestamps like 19:12:42.0429512Z contain "429".
#
# Getting a verdict wrong is asymmetric: calling a transient failure "build"
# makes the repair step revert an image's toolchain pin for no reason — silent,
# durable, and looking deliberate. So a wrong "transient" is a retry; a wrong
# "build" is a bad commit.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

CLS=".github/scripts/classify-build-failure.sh"
pass=0; fail=0
for f in tests/classify-fixtures/*; do
  expected="${f##*.}"
  got=$("$CLS" "$f")
  if [ "$got" = "$expected" ]; then
    pass=$((pass+1)); printf '  ✓ %-38s %s\n' "$(basename "$f")" "$got"
  else
    fail=$((fail+1)); printf '  ✗ %-38s expected=%s got=%s\n' "$(basename "$f")" "$expected" "$got"
  fi
done
# A missing/unreadable log must never authorise a revert.
got=$("$CLS" /nonexistent/log 2>/dev/null || echo ERR)
if [ "$got" = "unknown" ]; then pass=$((pass+1)); printf '  ✓ %-38s %s\n' "missing-log" "$got"
else fail=$((fail+1)); printf '  ✗ %-38s expected=unknown got=%s\n' "missing-log" "$got"; fi

echo
if [ "$fail" -ne 0 ]; then echo "✗ classifier: $fail failed, $pass passed"; exit 1; fi
echo "✓ classifier: all $pass cases correct"
