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
preserve_pins=$(jq -r '.["preserve-pins"] // false' <<<"$row")
family_count=$(jq '.families // [] | length' <<<"$row")
if [ "$family_count" -gt 0 ] && [ "$artifact_type" != "python" ]; then
  echo "ERROR: families are only implemented for artifact-type python (row ${name})" >&2
  exit 1
fi

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

# --- recover pkg@ver pairs from an existing auto-block ---
# Turns update-template into a regex ({pkg}/{ver} become captures) and applies
# it to each line between the block markers. Needs a {pkg} placeholder, so the
# maven row ({coord}) cannot opt into preserve-pins.
existing_pins() {
  local melange="$1"
  awk -v id="$marker_id" '
    $0 ~ "# " id ": auto-generated" {inblk=1; next}
    $0 ~ "# end-" id {inblk=0}
    inblk
  ' "$melange" | jq -R -r --arg t "$update_template" '
    ($t
      | gsub("\\{pkg\\}"; "\u0001") | gsub("\\{ver\\}"; "\u0002")
      | gsub("(?<c>[.*+?()\\[\\]{}|^$\\\\])"; "\\\(.c)")
      | gsub("\u0001"; "(?<pkg>[^\\s\"'"'"'=]+)")
      | gsub("\u0002"; "(?<ver>[^\\s\"'"'"']+)")) as $re
    | capture($re)? | "\(.pkg)@\(.ver)"
  ' | sort -u
}

# --- merge fresh grype fixes with preserved pins (higher version wins) ---
# grype scans the already-patched :latest image, so it stops reporting the
# CVEs the current block is fixing. Dropping those pins would revert them on
# the next rebuild (#991 dropped mako this way; the Go row hit the same bug,
# see patch-go-deps.yml "Preserve existing pins").
merge_pins() {
  local fresh="$1" kept="$2"
  printf '%s\n%s\n' "$fresh" "$kept" | grep -v '^$' \
    | sort -t@ -k1,1 -k2,2V | awk -F@ '{last[$1]=$0} END {for (p in last) print last[p]}' \
    | sort
}

pep503() { tr '[:upper:]_.' '[:lower:]--' <<<"$1"; }

# --- expand python families to their full lockstep set ---
# A family is every installed package under `prefix` that ships on the same
# version as `anchor` (opentelemetry-api/sdk/proto/exporter-* all release as
# one number). Bumping one member with --no-deps leaves the others importing
# symbols the new one removed (#994: ImportError _ExtendedAttributes). After
# moving the lockstep set, exact `==` pins that those releases declare on other
# `prefix` packages are followed transitively via PyPI (sdk 1.45.1 pins
# semantic-conventions==0.66b1; exporter-otlp-proto-grpc 1.45.1 pins
# exporter-otlp-common==0.66b1, a package the old release did not need).
# Args: fixes list, syft installed list ("name version" per line).
# Prints the new fixes list on stdout (progress goes to stderr). On any
# inconsistency the family bump is skipped (with a warning) rather than
# shipping a partial one.
expand_families() {
  local fixes="$1" installed="$2" f
  for f in $(seq 0 $((family_count - 1))); do
    local prefix anchor anchor_inst target members
    prefix=$(jq -r ".families[$f].prefix" <<<"$row")
    anchor=$(jq -r ".families[$f].anchor" <<<"$row")
    members=$(awk -F@ -v p="$prefix" 'index($1, p) == 1' <<<"$fixes")
    [ -z "$members" ] && continue
    anchor_inst=$(awk -v a="$anchor" '$1 == a {print $2; exit}' <<<"$installed")
    if [ -z "$anchor_inst" ]; then
      echo "  family ${prefix}*: anchor ${anchor} not installed; leaving members as reported" >&2
      continue
    fi

    # Lockstep cohort = installed prefix packages on the anchor's version.
    local cohort
    cohort=$(awk -v p="$prefix" -v v="$anchor_inst" 'index($1, p) == 1 && $2 == v {print $1}' <<<"$installed" | sort -u)

    # Target = highest requested version among the anchor and cohort members.
    target=$(while IFS=@ read -r p v; do
      grep -qxF "$p" <<<"$cohort" && echo "$v"
    done <<<"$members" | sort -V | tail -1)
    if [ -z "$target" ] || [ "$target" = "$anchor_inst" ]; then
      echo "  family ${prefix}*: no lockstep bump requested; leaving members as reported" >&2
      continue
    fi

    local -A want=()
    local queue=() ok=true p v
    for p in $cohort; do want[$p]="$target"; queue+=("$p"); done
    while [ "${#queue[@]}" -gt 0 ]; do
      p="${queue[0]}"; queue=("${queue[@]:1}")
      local meta
      if ! meta=$(curl -fs --max-time 10 "https://pypi.org/pypi/${p}/${want[$p]}/json"); then
        echo "  family ${prefix}*: ${p}==${want[$p]} not on PyPI; skipping family" >&2
        ok=false; break
      fi
      while IFS=' ' read -r dp dv; do
        dp=$(pep503 "$dp")
        if [ -n "${want[$dp]:-}" ]; then
          if [ "${want[$dp]}" != "$dv" ]; then
            echo "  family ${prefix}*: ${p}==${want[$p]} pins ${dp}==${dv}, conflicts with ${want[$dp]}; skipping family" >&2
            ok=false; break 2
          fi
          continue
        fi
        want[$dp]="$dv"; queue+=("$dp")
      done < <(jq -r --arg pfx "$prefix" '
        .info.requires_dist // [] | .[]
        | select(contains(";") | not)
        | capture("^(?<n>[A-Za-z0-9._-]+)\\s*==\\s*(?<v>[^\\s,;]+)$")?
        | select((.n | ascii_downcase | gsub("[._]"; "-")) | startswith($pfx))
        | "\(.n) \(.v)"
      ' <<<"$meta")
    done

    fixes=$(awk -F@ -v p="$prefix" 'index($1, p) != 1' <<<"$fixes")
    if [ "$ok" = true ]; then
      for p in "${!want[@]}"; do fixes=$(printf '%s\n%s@%s' "$fixes" "$p" "${want[$p]}"); done
      echo "  family ${prefix}*: ${anchor} ${anchor_inst} -> ${target} (${#want[@]} packages)" >&2
    else
      # Keep pins the image already carries (preserved from the last block)
      # so a failed expansion doesn't also revert the previous good bump.
      local held
      held=$(while IFS=@ read -r p v; do
        awk -v n="$p" -v v="$v" '$1 == n && $2 == v {found=1} END {exit !found}' <<<"$installed" && echo "${p}@${v}"
      done <<<"$members")
      fixes=$(printf '%s\n%s' "$fixes" "$held")
      echo "  WARN: family ${prefix}* bump skipped this run; already-applied pins kept" >&2
    fi
    unset want
  done
  grep -v '^$' <<<"$fixes" | sort -u || true
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
  # preserve-pins rows instead keep the block untouched until a replacement is
  # ready, and carry its pins forward (see merge_pins).
  kept=""
  if [ "$preserve_pins" = "true" ]; then
    kept=$(existing_pins "$melange")
  elif grep -q "# ${marker_id}: auto-generated" "$melange"; then
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

  if [ -n "$kept" ]; then
    while IFS= read -r ep; do echo "  preserving existing pin: $ep"; done <<<"$kept"
    fixes=$(merge_pins "$fixes" "$kept")
  fi

  if [ -z "$fixes" ]; then
    echo "  No fixable ${artifact_type} CVEs"
    continue
  fi

  if [ "$family_count" -gt 0 ]; then
    installed=$(syft "$full_image" -o json -q 2>/dev/null \
      | jq -r --arg t "$artifact_type" '.artifacts[] | select(.type == $t) | "\(.name | ascii_downcase | gsub("[._]"; "-")) \(.version)"' \
      | sort -u || true)
    fixes=$(expand_families "$fixes" "$installed")
  fi

  # Nothing new beyond what the block already pins: leave the file untouched.
  if [ -n "$kept" ] && [ "$fixes" = "$kept" ]; then
    echo "  Existing block already current"
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

  # preserve-pins rows deferred the strip until a replacement block existed.
  if [ "$preserve_pins" = "true" ] && grep -q "# ${marker_id}: auto-generated" "$melange"; then
    awk -v id="$marker_id" '
      $0 ~ "# " id ": auto-generated" {skip=1}
      $0 ~ "# end-" id {skip=0; next}
      !skip
    ' "$melange" > "${melange}.tmp" && mv "${melange}.tmp" "$melange"
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
