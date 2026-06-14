#!/usr/bin/env bash
# Create a branch, commit the in-tree edits, push, open a PR, and enable auto-merge.
#
# Usage:
#   open-pr.sh '<row-as-json>' <current_version> <new_version>
#
# Assumes the working tree already contains the edits (apply-update.sh ran).
# Requires: git, gh, GH_TOKEN env, and a git identity already configured.

set -euo pipefail

row="${1:?row JSON required}"
current="${2:?current_version required}"
new="${3:?new_version required}"

j() { jq -r "$1" <<<"$row"; }
name=$(j '.name')
files=$(jq -r '.files[] | if type == "string" then . else .path end' <<<"$row" | paste -sd, -)
releases=$(j '.links.releases // empty')
notes_tmpl=$(j '.links.notes // empty')
notes_url="${notes_tmpl//\{version\}/$new}"
image_name="minimal-$name"
# Image-name overrides (e.g. distribution → registry, redis → redis-slim).
# NB: hyphenated keys MUST be bracket-quoted in jq — `.image-name` is
# parsed as subtraction (`.image - name`) and fails to compile.
override=$(j '.["image-name"] // empty')
[ -n "$override" ] && image_name="$override"

branch="update-${name}-${new}"
title="chore(${name}): bump to ${new}"

git checkout -b "$branch"
git add -A
git commit -m "$title"
git push --force -u origin "$branch"

body=$(cat <<EOF
## Summary

Updates ${name} from \`${current}\` to \`${new}\`.

## Changes

- \`${files}\` — version, checksum(s), epoch reset

## Image Tag

Once merged, this will publish: \`ghcr.io/rtvkiz/${image_name}:${new}-r0\`

## Links
${releases:+- [Releases](${releases})}
${notes_url:+- [Release notes for ${new}](${notes_url})}

---

This PR was automatically created by the [update-versions](${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-rtvkiz/minimal}/actions/workflows/update-versions.yml) workflow.
EOF
)

# Ensure the per-image label exists before referencing it. `gh pr create`
# aborts the *entire* PR creation (not just labeling) if --label names a
# label the repo doesn't have — which is exactly what happens the first time
# a newly-added image gets a version bump (alertmanager hit this: branch
# pushed, no PR, run failed). Create-if-missing only: gh exits non-zero when
# the label already exists, which `|| true` swallows, so existing labels'
# color/description are never overwritten (no --force).
gh label create "$name" \
  --color ededed \
  --description "Updates to the ${name} image" 2>/dev/null || true

pr_url=$(gh pr create \
  --title "$title" \
  --label dependencies --label "$name" \
  --body "$body")

echo "Created PR: $pr_url"
gh pr merge "$pr_url" --auto --squash --delete-branch
