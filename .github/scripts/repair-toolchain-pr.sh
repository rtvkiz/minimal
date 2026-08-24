#!/usr/bin/env bash
#
# Repair a toolchain-bump PR: keep the new toolchain for every image that still
# builds, revert only the images that genuinely cannot, and let the PR merge.
#
# This is the step that makes toolchain pinning self-healing. Without it a
# single incompatible image blocks the bump for all the others and someone has
# to intervene — which is exactly the manual burden pinning was supposed to
# remove.
#
# Reverting one image is just restoring its recipe from main: the bump branch
# differs from main only in toolchain pins, so `git checkout main -- <file>`
# puts that image back on its previous pin and leaves every other image on the
# new one. No version arithmetic, no partial edits.
#
# SAFETY. A revert is silent and durable: an image pinned backwards looks like a
# deliberate decision forever after. So a build failure only authorises a revert
# when classify-build-failure.sh says the compiler rejected the source. Anything
# infrastructural (Wolfi mid-migration index, Sigstore outage, GitHub 429s, a
# mutated upstream tarball — all observed here on 2026-08-19/20) means retry, not
# revert, and the PR is left red for the next run to pick up. Same for anything
# unrecognised: never guess.
#
# Usage: repair-toolchain-pr.sh <failed-run-id> <branch>
set -euo pipefail

RUN_ID="${1:?run id required}"
BRANCH="${2:?branch required}"
REPO="${GITHUB_REPOSITORY:?}"
CLS="$(dirname "$0")/classify-build-failure.sh"

# If more than this share of bumped images fail to compile, the toolchain itself
# is suspect rather than the images. That is a judgment call about whether to
# adopt the release at all, so stop and let a human look instead of reverting
# most of the catalogue automatically.
MAX_REVERT_SHARE=50

echo "Repairing $BRANCH from failed run $RUN_ID"

bumped=$(git diff --name-only "origin/main...HEAD" -- images/ | wc -l)
[ "$bumped" -gt 0 ] || { echo "branch has no image changes; nothing to repair"; exit 0; }
echo "  images bumped on this branch: $bumped"

# Collect every failed job, resolve it to an image, and classify its log.
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# Fetch every failed job.
#
# This query must never fail quietly. An empty result is indistinguishable from
# "nothing failed", and the script would then report a clean, considered
# "no image failed to compile" while having classified nothing at all. That is
# exactly what happened on 2026-08-24: the app token could not read the Actions
# API, gh returned an empty set, and the repair reported no compile failures for
# a build with 11 failed jobs — including trivy, which genuinely could not
# compile. A loud failure is recoverable; a confident wrong answer is not.
# We fire the instant the run completes, and the jobs endpoint is not yet
# consistent for a fresh attempt — it briefly reports no failed jobs at all.
# That is what happened on 2026-08-24: the query came back empty and the repair
# concluded "nothing failed" for a build where trivy could not compile. Retry
# until the API agrees that something failed, then trust it.
n_failed=0
for attempt in 1 2 3 4 5 6; do
  if ! gh api "repos/${REPO}/actions/runs/${RUN_ID}/jobs?per_page=100" --paginate \
        --jq '.jobs[] | select(.conclusion=="failure") | [(.id|tostring), .name] | @tsv' \
        > "$tmp/failed.tsv"; then
    echo "::error::cannot read jobs for run ${RUN_ID} — the token needs actions:read" >&2
    exit 1
  fi
  n_failed=$(wc -l < "$tmp/failed.tsv")
  [ "$n_failed" -gt 0 ] && break
  echo "  jobs endpoint reports 0 failures for a failed run (attempt ${attempt}) — waiting for it to settle"
  sleep 20
done

if [ "$n_failed" -eq 0 ]; then
  # We were triggered by a failed run, so at least one job must have failed.
  # Zero after retries means the query is lying to us, not that the build was
  # fine. Never conclude anything from a query we could not make.
  echo "::error::run ${RUN_ID} concluded 'failure' but reports no failed jobs — refusing to draw any conclusion" >&2
  exit 1
fi
echo "  failed jobs on that run: $n_failed"

# Download one job's log.
#
# Two portability traps, both of which cost a CI cycle each:
#
#  * gh >= 2.76 refuses to emit a response containing terminal escape
#    sequences unless asked, and build logs are full of ANSI colour. Older gh
#    does not know the flag at all. Try with, then without.
#  * the job list and the log download do not necessarily accept the same
#    credential — github.token reads the list but was refused the logs — so
#    try every token we were given.
#
# Never send the error to /dev/null. Hiding it is what made the first four
# failures of this script look like considered answers instead of breakage.
fetch_job_log() {
  local jid="$1" out="$2" err="$3" tok
  for tok in "${GH_TOKEN:-}" "${APP_TOKEN:-}"; do
    [ -n "$tok" ] || continue
    if GH_TOKEN="$tok" gh api --allow-escape-sequences \
         "repos/${REPO}/actions/jobs/${jid}/logs" > "$out" 2>"$err" && [ -s "$out" ]; then
      return 0
    fi
    if GH_TOKEN="$tok" gh api \
         "repos/${REPO}/actions/jobs/${jid}/logs" > "$out" 2>"$err" && [ -s "$out" ]; then
      return 0
    fi
  done
  return 1
}

declare -A VERDICT=()
n_image_jobs=0
n_classified=0
while IFS=$'\t' read -r jid name; do
  [ -n "${jid:-}" ] || continue
  case "$name" in
    melange-build*|build-melange*) ;;
    *) continue ;;                     # summary/cleanup jobs carry no image
  esac
  img=$(printf '%s' "$name" | sed -n 's/^[a-z-]* (\([a-z0-9-]*\),.*/\1/p')
  [ -n "$img" ] || continue
  n_image_jobs=$((n_image_jobs + 1))

  # Job logs are not always served the moment the run completes. The original
  # `|| continue` skipped those jobs silently, so on 2026-08-24 all five of
  # trivy's failed jobs were skipped and the run concluded that no image had
  # failed to compile. Retry, and if a log truly cannot be read say so —
  # an unclassified job must never masquerade as a passing one.
  ok=""
  for a in 1 2 3 4; do
    if fetch_job_log "$jid" "$tmp/$jid.log" "$tmp/$jid.err"; then ok=1; break; fi
    sleep 15
  done
  if [ -z "$ok" ]; then
    echo "::warning::could not fetch logs for job ${jid} (${img}) — leaving it unclassified: $(head -c 200 "$tmp/$jid.err" 2>/dev/null | tr '\n' ' ')"
    continue
  fi
  n_classified=$((n_classified + 1))
  v=$("$CLS" "$tmp/$jid.log")
  echo "  $img ($name): $v"
  # A compile error is decisive even if another job for the same image flaked:
  # once the compiler has rejected the source, infra noise elsewhere is moot.
  if [ "$v" = "build" ]; then VERDICT[$img]="build"
  elif [ -z "${VERDICT[$img]:-}" ]; then VERDICT[$img]="$v"
  fi
done < "$tmp/failed.tsv"

# Failed image jobs we could not read are not evidence of anything. Concluding
# "nothing failed to compile" from zero readable logs is the exact mistake that
# left trivy un-reverted twice.
if [ "$n_image_jobs" -gt 0 ] && [ "$n_classified" -eq 0 ]; then
  echo "::error::${n_image_jobs} image job(s) failed but none could be classified — refusing to draw any conclusion" >&2
  exit 1
fi

REVERT=""; HELD=""
for img in "${!VERDICT[@]}"; do
  if [ "${VERDICT[$img]}" = "build" ]; then REVERT="$REVERT $img"; else HELD="$HELD $img(${VERDICT[$img]})"; fi
done
REVERT=$(echo "$REVERT" | xargs || true)
HELD=$(echo "$HELD" | xargs || true)

if [ -z "$REVERT" ]; then
  echo "No image failed to COMPILE — of $n_failed failed job(s), image verdicts were: ${HELD:-none (no per-image jobs failed)}."
  echo "Leaving the PR red: a retry is the right response to infrastructure, not a revert."
  { echo "repaired=false"; echo "reason=no-build-failures"; } >> "${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

n_revert=$(printf '%s\n' "$REVERT" | wc -w)
share=$(( n_revert * 100 / bumped ))
echo "  compile failures: $n_revert/$bumped (${share}%)"
if [ "$share" -gt "$MAX_REVERT_SHARE" ]; then
  echo "More than ${MAX_REVERT_SHARE}% of bumped images fail to compile — the toolchain"
  echo "release looks bad, not the images. Not auto-reverting; leaving this for review."
  { echo "repaired=false"; echo "reason=too-many-failures"; } >> "${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

for img in $REVERT; do
  f="images/${img}/melange.yaml"
  [ -f "$f" ] || continue
  git checkout origin/main -- "$f"
  echo "  reverted $img to its previous pin"
done

if git diff --quiet "origin/main...HEAD" -- images/ && git diff --quiet -- images/; then
  echo "Every bumped image had to be reverted — nothing advances. Closing the PR."
  { echo "repaired=false"; echo "reason=nothing-advances"; } >> "${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

./scripts/check-toolchain-pins.sh >/dev/null || {
  echo "post-revert check failed — refusing to push a half-rewritten tree" >&2; exit 1; }

{
  echo "repaired=true"
  echo "reverted=$REVERT"
  echo "held=$HELD"
} >> "${GITHUB_OUTPUT:-/dev/null}"
echo "✓ reverted: $REVERT"
