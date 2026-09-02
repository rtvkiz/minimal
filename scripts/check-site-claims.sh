#!/usr/bin/env bash
#
# Verify the factual claims on minimalcontainers.com against this repo and,
# optionally, against the outside world.
#
# WHY THIS EXISTS. Site claims drift silently and in both directions. Commit
# 4a469d65 had to retract four of our own overstatements. Later, /about still
# said Docker Hardened had "Hundreds" of images months after Docker released
# 1,000+ free under Apache-2.0 — understating a competitor under a footnote that
# said the table had been verified. And a Bitnami replacement page shipped
# claiming bitnami/helm exists; it 404s.
#
# None of those were caught by a build. A page renders identically whether its
# numbers are right or wrong, so nothing failed until a human re-read it. This
# is the checker that re-reads it.
#
# Two modes, matching the other gates in this repo:
#   (default)  assert  — exit non-zero on any hard failure. For CI.
#   --report           — print findings and always exit 0. For a human sweep.
#
# Network checks (competitor repositories) are skipped unless --online is given,
# so CI stays hermetic by default and does not fail on someone else's outage.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

MODE=assert
ONLINE=0
for a in "$@"; do
  case "$a" in
    --report) MODE=report ;;
    --online) ONLINE=1 ;;
    *) echo "usage: $0 [--report] [--online]" >&2; exit 2 ;;
  esac
done

fail=0
pass=0
note() { printf '  \033[33m!\033[0m %s\n' "$1"; fail=$((fail+1)); }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass+1)); }

SITE=site/src

echo "Checking site claims against the repo…"

# --- 1. Counts the site states must match catalog.json ----------------------
# The templates read images.json, so a hard-coded count in prose is the risk.
CAT_IMAGES=$(jq '.images | length' catalog.json)
CAT_CATS=$(jq '.categories | length' catalog.json)
for n in $(grep -rhoE '\b(1[0-9]{2})\b images' "$SITE"/pages | grep -oE '^[0-9]+' | sort -u); do
  if [ "$n" != "$CAT_IMAGES" ]; then
    note "a page hard-codes '$n images' but catalog.json has $CAT_IMAGES"
  fi
done
ok "hard-coded image counts agree with catalog.json ($CAT_IMAGES)"
[ "$CAT_CATS" -gt 0 ] && ok "catalog declares $CAT_CATS categories"

# --- 2. Rebuild cadence -----------------------------------------------------
# "rebuilt every 6 hours" appears in meta descriptions on every image page.
CRON=$(grep -oE "cron: *'[^']+'" .github/workflows/build.yml | head -1 | grep -oE "'[^']+'" | tr -d "'")
CLAIMED_H=$(grep -rhoE 'every [0-9]+ hours' "$SITE" | grep -oE '[0-9]+' | sort -u | head -1)
CRON_H=$(printf '%s' "$CRON" | awk '{print $2}' | grep -oE '[0-9]+$')
if [ -n "$CLAIMED_H" ] && [ "$CLAIMED_H" != "${CRON_H:-}" ]; then
  note "site claims a ${CLAIMED_H}h rebuild cadence but build.yml cron is '$CRON'"
else
  ok "rebuild cadence claim (${CLAIMED_H}h) matches build.yml cron '$CRON'"
fi

# --- 3. Claims we retracted and must not reintroduce ------------------------
# Each of these was removed for a stated reason. Reintroducing one is a
# regression, not a new decision.
#   reproducible   — SOURCE_DATE_EPOCH alone proves nothing; nothing verifies it
#   Build L3       — needs a reusable workflow; this repo has none
#   no rate limits — GHCR does apply limits; only the Docker Hub claim is safe
if grep -rniE '\breproducib' "$SITE" >/dev/null 2>&1; then
  note "'reproducible' is back on the site — retracted in 4a469d65, still unverified"
else
  ok "no unproven reproducibility claim"
fi
# Only an ASSERTION about our own level matters. "Docker: yes (L3)" and "if you
# need L3, use a vendor" are both correct and must not trip this.
if grep -rnE '(Minimal|we|this project) [a-z ]{0,20}publish[a-z]* [^.<]{0,20}SLSA[^.<]{0,20}L(evel )?3' "$SITE" >/dev/null 2>&1; then
  note "SLSA L3 asserted for Minimal; this repo publishes Build L2 (no reusable workflow)"
elif grep -rnE '(Minimal|we|this project) [a-z ]{0,20}publish[a-z]* [^.<]{0,20}SLSA' "$SITE" >/dev/null 2>&1; then
  ok "SLSA level asserted for Minimal is L2"
elif grep -rn 'Build L2' "$SITE" >/dev/null 2>&1; then
  ok "SLSA level stated for Minimal is Build L2"
else
  note "the site states no SLSA level at all — it publishes Build L2 provenance"
fi
if grep -rnE 'no rate limits' "$SITE" >/dev/null 2>&1; then
  note "'no rate limits' — GHCR applies limits; claim only 'no Docker Hub pull limits'"
else
  ok "rate-limit claim is scoped to Docker Hub"
fi

# --- 4. Competitor claims must carry a review date --------------------------
# A dated claim can be re-checked. An undated one silently rots, which is
# exactly how the Docker Hardened row went stale.
STALE_DAYS=${STALE_DAYS:-120}
now=$(date +%s)
for f in "$SITE"/pages/compare/*.astro "$SITE"/pages/about.astro; do
  [ -f "$f" ] || continue
  # A page may carry its date literally, or inject it from a dated dataset
  # (comparison.json scanDate, bitnami-map.json verified). Resolve both — a
  # template variable is still a date shown to the reader.
  d=$(grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' "$f" | sort | tail -1)
  if [ -z "$d" ] && grep -q 'data\.scanDate' "$f"; then
    d=$(jq -r '.scanDate' "$SITE"/data/comparison.json)
  fi
  # Accept whatever field the dataset uses for its own date; the page renaming
  # map.verified -> map.generated must not read as "undated".
  if [ -z "$d" ] && grep -qE 'map\.(verified|generated)' "$f"; then
    d=$(jq -r '.generated // .verified // empty' "$SITE"/data/bitnami-map.json)
  fi
  if [ -z "$d" ]; then
    note "$(basename "$f") makes competitor claims with no review date"
    continue
  fi
  age=$(( (now - $(date -d "$d" +%s 2>/dev/null || echo "$now")) / 86400 ))
  if [ "$age" -gt "$STALE_DAYS" ]; then
    note "$(basename "$f") last reviewed $d (${age}d ago, limit ${STALE_DAYS}d) — re-verify competitor facts"
  else
    ok "$(basename "$f") reviewed $d (${age}d ago)"
  fi
done

# --- 5. Competitor repositories we name must exist (network) ----------------
if [ "$ONLINE" = 1 ]; then
  echo "Checking named competitor repositories…"
  miss=0
  while read -r b; do
    code=$(curl -s -m 15 -o /dev/null -w '%{http_code}' "https://hub.docker.com/v2/repositories/bitnami/$b/" || echo 000)
    case "$code" in
      200) ;;
      000) echo "    (skipped $b — network unreachable)" ;;
      *)   note "bitnami/$b returns HTTP $code — the Bitnami page claims it exists"; miss=$((miss+1)) ;;
    esac
  done < <(jq -r '.pairs[].bitnami' "$SITE"/data/bitnami-map.json)
  [ "$miss" -eq 0 ] && ok "every bitnami/<name> named on the site resolves"
else
  echo "  (competitor repository checks skipped — pass --online to run them)"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "✓ site claims: $pass checks passed"
  exit 0
fi
echo "✗ site claims: $fail finding(s), $pass passed"
[ "$MODE" = report ] && exit 0
exit 1
