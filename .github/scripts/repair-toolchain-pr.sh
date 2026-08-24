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
if ! gh api "repos/${REPO}/actions/runs/${RUN_ID}/jobs?per_page=100" --paginate \
      --jq '.jobs[] | select(.conclusion=="failure") | [(.id|tostring), .name] | @tsv' \
      > "$tmp/failed.tsv"; then
  echo "::error::cannot read jobs for run ${RUN_ID} — the token needs actions:read" >&2
  exit 1
fi

n_failed=$(wc -l < "$tmp/failed.tsv")
if [ "$n_failed" -eq 0 ]; then
  # We were triggered by a failed run, so at least one job must have failed.
  # Zero means the query is lying to us, not that the build was fine.
  echo "::error::run ${RUN_ID} concluded 'failure' but reports no failed jobs — refusing to draw any conclusion" >&2
  exit 1
fi
echo "  failed jobs on that run: $n_failed"

declare -A VERDICT=()
while IFS=$'\t' read -r jid name; do
  [ -n "${jid:-}" ] || continue
  case "$name" in
    melange-build*|build-melange*) ;;
    *) continue ;;                     # summary/cleanup jobs carry no image
  esac
  img=$(printf '%s' "$name" | sed -n 's/^[a-z-]* (\([a-z0-9-]*\),.*/\1/p')
  [ -n "$img" ] || continue
  gh api "repos/${REPO}/actions/jobs/${jid}/logs" > "$tmp/$jid.log" 2>/dev/null || continue
  v=$("$CLS" "$tmp/$jid.log")
  echo "  $img ($name): $v"
  # A compile error is decisive even if another job for the same image flaked:
  # once the compiler has rejected the source, infra noise elsewhere is moot.
  if [ "$v" = "build" ]; then VERDICT[$img]="build"
  elif [ -z "${VERDICT[$img]:-}" ]; then VERDICT[$img]="$v"
  fi
done < "$tmp/failed.tsv"

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
