#!/usr/bin/env bash
# Scan one language's images with grype, generate a patch block per image,
# and splice it into the corresponding melange.yaml.
#
# Usage:
#   patch-deps.sh '<row-as-json>'
#
# Inputs (env):
#   REGISTRY              container registry hostname (default ghcr.io)
#   GITHUB_REPOSITORY_OWNER  used to build the image reference
#
# Outputs (to $GITHUB_OUTPUT or stdout):
#   has_patches=true|false
#   patched_images=<space-separated list>
#   summary=<markdown bullet list>  (multi-line via heredoc on $GITHUB_OUTPUT)
#
# Required tools: bash, jq, grype, curl, awk, sed.

set -euo pipefail

row="${1:?row JSON required as $1}"
out="${GITHUB_OUTPUT:-/dev/stdout}"

j() { jq -r "$1" <<<"$row"; }

name=$(j '.name')

# Bundled-jar rows (jars baked into a prebuilt distro, not built by a package
# manager) are handled by a dedicated script — the swap mechanics don't fit the
# generic update-template model. It honours the same has_patches/summary output
# contract, so the workflow's PR step is unchanged.
if [ "$(jq -r '.mode // "deps"' <<<"$row")" = "bundled-jar" ]; then
  exec "$(dirname "$0")/patch-bundled-jars.sh" "$row"
fi
artifact_type=$(j '.["artifact-type"]')
update_template=$(j '.["update-template"]')
verify_url_template=$(j '.["verify-url"]')
registry="${REGISTRY:-ghcr.io}"
owner="${GITHUB_REPOSITORY_OWNER:?GITHUB_REPOSITORY_OWNER required}"
marker_id="patch-${name}-deps"

# coord-map is maven-only; expose as a jq lookup later.
has_coord_map=$(jq 'has("coord-map")' <<<"$row")

# --- substitute placeholders in templates ---
render() {
  local tmpl="$1" pkg="$2" ver="$3"
  tmpl="${tmpl//\{pkg\}/$pkg}"
  tmpl="${tmpl//\{ver\}/$ver}"
  if [ "$has_coord_map" = "true" ]; then
    local coord; coord=$(jq -r --arg p "$pkg" '.["coord-map"][$p] // ""' <<<"$row")
    if [ -n "$coord" ]; then
      local gid="${coord%:*}" aid="${coord#*:}"
      local gpath="${gid//.//}"
      tmpl="${tmpl//\{coord\}/$coord}"
      tmpl="${tmpl//\{group-path\}/$gpath}"
      tmpl="${tmpl//\{artifact-id\}/$aid}"
    fi
  fi
  printf '%s' "$tmpl"
}

# --- main per-image loop ---
HAS_PATCHES=false
PATCHED_LIST=""
SUMMARY=""

image_count=$(jq '.images | length' <<<"$row")
for i in $(seq 0 $((image_count - 1))); do
  img_json=$(jq -c ".images[$i]" <<<"$row")
  image=$(jq -r '.name' <<<"$img_json")
  src_root_raw=$(jq -r '.["src-root"]' <<<"$img_json")
  build_marker=$(jq -r '.["build-marker"]' <<<"$img_json")
  # Re-inject the literal melange template ${{package.version}} that we
  # escaped as <<PKG_VERSION>> in the registry. This survives toJson + bash.
  src_root="${src_root_raw//<<PKG_VERSION>>/\${\{package.version\}\}}"

  full_image="${registry}/${owner}/minimal-${image}:latest"
  melange="images/${image}/melange.yaml"

  echo "=== Scanning $image ==="

  # Strip any existing auto-block before rescanning. (For Go this was a known
  # bug — see patch-go-deps.yml — but for bundler/rust/maven the rescan is
  # against the same already-patched image, and existing-pin preservation
  # isn't a documented regression for these languages. Match original.)
  if grep -q "# ${marker_id}: auto-generated" "$melange"; then
    awk -v id="$marker_id" '
      $0 ~ "# " id ": auto-generated" {skip=1}
      $0 ~ "# end-" id {skip=0; next}
      !skip
    ' "$melange" > "${melange}.tmp" && mv "${melange}.tmp" "$melange"
  fi

  fixes=$(grype "$full_image" -o json 2>/dev/null | \
    jq -r --arg t "$artifact_type" '
      [.matches[]
        | select(.artifact.type == $t)
        | select(.vulnerability.fix.versions | length > 0)
        | {pkg: .artifact.name, fix: .vulnerability.fix.versions[0]}
      ]
      | unique_by(.pkg)
      | .[]
      | "\(.pkg)@\(.fix)"
    ' 2>/dev/null | sort -u || true)

  if [ -z "$fixes" ]; then
    echo "  No fixable ${artifact_type} CVEs"
    continue
  fi

  updates=""
  applied=0
  while IFS= read -r pkg_ver; do
    [ -z "$pkg_ver" ] && continue
    pkg="${pkg_ver%@*}"
    ver="${pkg_ver#*@}"

    # Maven-only: skip artifacts without a coord-map entry.
    if [ "$has_coord_map" = "true" ]; then
      coord=$(jq -r --arg p "$pkg" '.["coord-map"][$p] // ""' <<<"$row")
      if [ -z "$coord" ]; then
        echo "  Skipping ${pkg_ver}: no coord-map entry (add to .github/patch-deps.yaml)"
        continue
      fi
    fi

    verify_url=$(render "$verify_url_template" "$pkg" "$ver")
    if ! curl -fs --max-time 10 "$verify_url" >/dev/null 2>&1; then
      echo "  Skipping ${pkg_ver}: not at ${verify_url}"
      continue
    fi

    update_cmd=$(render "$update_template" "$pkg" "$ver")
    updates="${updates}      ${update_cmd}"$'\n'
    applied=$((applied + 1))
  done <<< "$fixes"

  if [ "$applied" -eq 0 ]; then
    echo "  No compatible ${name} patches after filtering"
    continue
  fi

  # Splice the patch block before the build marker line. If the marker is
  # inside a multi-line `- runs: |` block, walk back to that `- runs:` line.
  marker_line=$(grep -n "$build_marker" "$melange" | head -1 | cut -d: -f1 || true)
  if [ -z "$marker_line" ]; then
    echo "  WARN: build marker '$build_marker' not found in $melange"
    continue
  fi
  marker_indent=$(sed -n "${marker_line}p" "$melange" | sed 's/[^ ].*//' | wc -c)
  if [ "$marker_indent" -gt 4 ]; then
    runs_line=$(head -n "$marker_line" "$melange" | grep -n "^  - runs:" | tail -1 | cut -d: -f1 || true)
    [ -n "$runs_line" ] && marker_line=$runs_line
  fi

  {
    head -n $((marker_line - 1)) "$melange"
    printf '  # %s: auto-generated — do not edit manually\n' "$marker_id"
    printf '  - runs: |\n'
    printf '      cd %s\n' "$src_root"
    printf '%s' "$updates"
    printf '  # end-%s\n' "$marker_id"
    tail -n +"$marker_line" "$melange"
  } > "${melange}.tmp"
  mv "${melange}.tmp" "$melange"

  HAS_PATCHES=true
  PATCHED_LIST="${PATCHED_LIST} ${image}"
  SUMMARY="${SUMMARY}- **${image}**: ${applied} dep(s) bumped"$'\n'
  echo "  Patched ${applied} deps"
done

PATCHED_LIST=$(echo "$PATCHED_LIST" | xargs)

if [ "$HAS_PATCHES" = true ]; then
  {
    echo "has_patches=true"
    echo "patched_images=$PATCHED_LIST"
    echo "summary<<EOF"
    printf '%s' "$SUMMARY"
    echo "EOF"
  } >> "$out"
else
  echo "has_patches=false" >> "$out"
  echo "No ${name} dep patches needed"
fi
