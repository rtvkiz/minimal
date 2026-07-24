#!/usr/bin/env bash
# Patch CVEs in *bundled* Java jars that ship inside prebuilt distributions
# (opensearch, keycloak, ...), which the maven dependency patcher can't reach
# because there is no `mvn` build to override — the jars are baked into the
# upstream tarball/war.
#
# For each configured image it scans the published image with grype, finds
# java-archive CVEs whose fix is an actually-published Maven Central artifact,
# computes the fix jar's sha256, and splices a sha-pinned "jar swap" block into
# the image's melange.yaml (regenerated under auto-generated markers, like the
# Go patcher). A scheduled run picks up newer fix versions automatically.
#
# Usage:   patch-bundled-jars.sh '<row-as-json>'
# Output (to $GITHUB_OUTPUT or stdout): has_patches / patched_images / summary
#
# Row schema (see .github/patch-deps.yaml, mode: bundled-jar):
#   mode: bundled-jar
#   coord-map: { <grype-artifact-name>: <group:artifact> }   # maven coordinates
#   images:
#     - name: opensearch
#       jar-root: usr/share/opensearch        # where to search for jars
#       policy: auto                           # default; report-only never patches
#       strategy: rename                       # rename jar to the new version
#       splice-before: "  # Verify"            # melange line to insert before
#     - name: keycloak
#       jar-root: opt/keycloak
#       strategy: keep-filename                # overwrite contents, keep name
#       splice-before: "      # Ensure scripts are executable"
#
# Strategies:
#   rename         directory-classpath images (opensearch) — install the new
#                  jar under its real <artifact>-<newver>.jar name, drop the old.
#   keep-filename  exact-filename classpaths (keycloak/Quarkus) — overwrite the
#                  jar contents in place, keep the old filename so the classpath
#                  reference stays valid (grype reads the version from the jar's
#                  internal pom.properties, so the CVE still clears).
set -euo pipefail

row="${1:?row JSON required as $1}"
out="${GITHUB_OUTPUT:-/dev/stdout}"
registry="${REGISTRY:-ghcr.io}"
owner="${GITHUB_REPOSITORY_OWNER:?GITHUB_REPOSITORY_OWNER required}"
marker_id="patch-bundled-jars"

j() { jq -r "$1" <<<"$row"; }

# repo1.maven.org HEAD probe — only treat a grype fix version as usable once the
# jar is actually published (grype cites advisory fix versions ahead of release,
# e.g. jackson 2.21.5 before it hits Central — fetching it would 404 the build).
# Maven layout: /<group-path>/<artifact>/<version>/<artifact>-<version>.jar
# $1=group-path $2=artifact $3=version
maven_url() { printf 'https://repo1.maven.org/maven2/%s/%s/%s/%s-%s.jar' "$1" "$2" "$3" "$2" "$3"; }
published() { curl -fsSLI -o /dev/null --connect-timeout 20 --retry 2 --retry-all-errors "$(maven_url "$@")"; }

# Numeric major.minor.patch compare: is $1 strictly greater than $2 ?
ver_gt() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]; }

HAS_PATCHES=false
PATCHED_LIST=""
SUMMARY=""
HAS_REPORTS=false
REPORT_SUMMARY=""

image_count=$(jq '.images | length' <<<"$row")
for i in $(seq 0 $((image_count - 1))); do
  img_json=$(jq -c ".images[$i]" <<<"$row")
  image=$(jq -r '.name' <<<"$img_json")
  jar_root=$(jq -r '.["jar-root"]' <<<"$img_json")
  policy=$(jq -r '.policy // "auto"' <<<"$img_json")
  strategy=$(jq -r '.strategy' <<<"$img_json")
  splice_before=$(jq -r '.["splice-before"]' <<<"$img_json")
  melange="${image}/melange.yaml"
  full_image="${registry}/${owner}/minimal-${image}:latest"

  echo "=== Scanning $image (bundled jars) ==="
  [ -f "$melange" ] || { echo "  WARN: $melange not found"; continue; }

  case "$policy" in
    auto|report-only) ;;
    *) echo "  WARN: unknown policy '$policy' (refusing to patch)"; continue ;;
  esac

  scan_json=$(mktemp)
  if ! grype "$full_image" -o json >"$scan_json" 2>/dev/null; then
    echo "  WARN: grype scan failed"
    rm -f "$scan_json"
    continue
  fi

  # Report-only is the safe onboarding state for API-coupled distributions.
  # Surface every fixable Java archive, including artifacts not yet present in
  # coord-map, but never rewrite melange.yaml or create a patch PR for them.
  if [ "$policy" = "report-only" ]; then
    report_count=$(jq '[.matches[]
        | select(.artifact.type == "java-archive")
        | select((.vulnerability.fix.versions | length) > 0)
        | {name: .artifact.name, installed: .artifact.version, fix: .vulnerability.fix.versions[0]}]
        | unique_by(.name + .installed + .fix) | length' "$scan_json")
    if [ "$report_count" -gt 0 ]; then
      report_names=$(jq -r '[.matches[]
          | select(.artifact.type == "java-archive")
          | select((.vulnerability.fix.versions | length) > 0)
          | .artifact.name] | unique | sort | join(", ")' "$scan_json")
      echo "  REPORT ONLY: $report_count fixable finding(s): $report_names"
      HAS_REPORTS=true
      REPORT_SUMMARY="${REPORT_SUMMARY}- **${image}** (${report_count} fixable finding(s)): ${report_names}"$'\n'
    else
      echo "  No fixable bundled-jar CVEs"
    fi
    rm -f "$scan_json"
    continue
  fi

  # grype → "artifact<TAB>installed<TAB>fix" for java-archive matches whose
  # artifact is in coord-map and that actually have a fix version.
  fixes=$(jq -r --argjson cm "$(jq -c '.["coord-map"]' <<<"$row")" '
      [ .matches[]
        | select(.artifact.type == "java-archive")
        | select(.artifact.name as $n | $cm | has($n))
        | select((.vulnerability.fix.versions | length) > 0)
        | { name: .artifact.name, installed: .artifact.version, fix: .vulnerability.fix.versions[0] }
      ] | unique_by(.name + .installed + .fix) | .[] | "\(.name)\t\(.installed)\t\(.fix)"
    ' "$scan_json" 2>/dev/null | sort -t"$(printf '\t')" -k1,1 -k3,3rV || true)
  rm -f "$scan_json"
  # Highest fix version per artifact is tried first; the loop takes the first
  # one that is actually published, so we land on the newest available fix.

  [ -n "$fixes" ] || { echo "  No fixable bundled-jar CVEs"; continue; }

  # Resolve each fix to the newest *published* version that clears it, pin sha256.
  # SWAPS lines: "artifact|group-path|installed|newver|sha256"
  SWAPS=""
  declare -A seen=()
  while IFS=$'\t' read -r artifact installed fix; do
    [ -n "$artifact" ] || continue
    [ -n "${seen[$artifact]:-}" ] && continue   # one swap per artifact (newest fix wins below)
    coord=$(jq -r --arg a "$artifact" '.["coord-map"][$a] // ""' <<<"$row")
    [ -n "$coord" ] || { echo "  skip $artifact: no coord-map entry"; continue; }
    group="${coord%:*}"; gpath="${group//.//}"
    inst="${installed#v}"; fixv="${fix#v}"

    # Refuse a major-version jump — bundled deps are API-coupled to the distro
    # (e.g. jline 3.x -> 4.x would break kafka). Only same-major bumps.
    if [ "${inst%%.*}" != "${fixv%%.*}" ]; then
      echo "  skip $artifact $inst -> $fixv: major version jump (compat risk)"; continue
    fi
    if ! ver_gt "$fixv" "$inst"; then
      echo "  skip $artifact: fix $fixv not newer than installed $inst"; continue
    fi
    if ! published "$gpath" "$artifact" "$fixv"; then
      echo "  skip $artifact $fixv: not yet published on Maven Central"; continue
    fi
    echo "  fetching $artifact $fixv for sha256..."
    tmp=$(mktemp)
    curl -fsSL --retry 5 --retry-all-errors "$(maven_url "$gpath" "$artifact" "$fixv")" -o "$tmp"
    sha=$(sha256sum "$tmp" | awk '{print $1}'); rm -f "$tmp"
    SWAPS="${SWAPS}${artifact}|${gpath}|${inst}|${fixv}|${sha}"$'\n'
    seen[$artifact]=1
    echo "  -> $artifact $inst -> $fixv ($sha)"
  done <<< "$fixes"
  unset seen

  [ -n "$SWAPS" ] || { echo "  Nothing to patch after filtering"; continue; }

  # --- regenerate the auto-block ---------------------------------------------
  # Strip any prior auto-block so we always emit a fresh, fully version-pinned
  # one (the swap is idempotent and only acts on the named old version, so a
  # rebuild can't lose a fix: a still-vulnerable jar is re-flagged next scan).
  if grep -q "# ${marker_id}: auto-generated" "$melange"; then
    awk -v id="$marker_id" '
      $0 ~ "# " id ": auto-generated" {skip=1}
      $0 ~ "# end-" id {skip=0; next}
      !skip
    ' "$melange" > "${melange}.tmp" && mv "${melange}.tmp" "$melange"
  fi

  marker_line=$(grep -nF "$splice_before" "$melange" | head -1 | cut -d: -f1 || true)
  [ -n "$marker_line" ] || { echo "  WARN: splice-before anchor not found in $melange"; continue; }

  count=0
  {
    head -n $((marker_line - 1)) "$melange"
    printf '  # %s: auto-generated — do not edit manually\n' "$marker_id"
    printf '  - runs: |\n'
    printf '      # Bundled-jar CVE fixes, sha256-pinned. Regenerated from grype by\n'
    printf '      # .github/scripts/patch-bundled-jars.sh — do not edit by hand.\n'
    printf '      _swap() {  # $1=artifact $2=group-path $3=oldver $4=newver $5=sha256 $6=mode\n'
    printf '        # rename: jar filename carries the version, match it exactly. keep-filename:\n'
    printf '        # filename stays the upstream version while contents change, so match any\n'
    printf '        # version of the artifact and overwrite in place.\n'
    printf '        if [ "$6" = "keep-filename" ]; then\n'
    printf '          found=$(find "${{targets.destdir}}/%s" -name "*$1-*.jar")\n' "$jar_root"
    printf '        else\n'
    printf '          found=$(find "${{targets.destdir}}/%s" -name "*$1-$3.jar")\n' "$jar_root"
    printf '        fi\n'
    printf '        [ -n "$found" ] || { echo "  $1 $3 not present (upstream may already ship >=$4)"; return 0; }\n'
    printf '        curl -fsSL --retry 5 --retry-all-errors \\\n'
    printf '          "https://repo1.maven.org/maven2/$2/$1/$4/$1-$4.jar" -o /tmp/_bj.jar\n'
    printf '        echo "$5  /tmp/_bj.jar" | sha256sum -c -\n'
    printf '        for f in $found; do\n'
    printf '          if [ "$6" = "keep-filename" ]; then cp /tmp/_bj.jar "$f";\n'
    printf '          else cp /tmp/_bj.jar "$(dirname "$f")/$1-$4.jar"; rm -f "$f"; fi\n'
    printf '          echo "  patched $1 $3 -> $4 ($6)"\n'
    printf '        done\n'
    printf '        rm -f /tmp/_bj.jar\n'
    printf '      }\n'
    while IFS='|' read -r artifact gpath inst fixv sha; do
      [ -n "$artifact" ] || continue
      printf '      _swap %s %s %s %s %s %s\n' "$artifact" "$gpath" "$inst" "$fixv" "$sha" "$strategy"
      count=$((count + 1))
    done <<< "$SWAPS"
    printf '  # end-%s\n' "$marker_id"
    tail -n +"$marker_line" "$melange"
  } > "${melange}.tmp"
  mv "${melange}.tmp" "$melange"

  HAS_PATCHES=true
  PATCHED_LIST="${PATCHED_LIST} ${image}"
  n=$(printf '%s' "$SWAPS" | grep -c .)
  SUMMARY="${SUMMARY}- **${image}**: ${n} bundled jar(s) pinned"$'\n'
  echo "  Patched $image"
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
  echo "No bundled-jar patches needed"
fi

if [ "$HAS_REPORTS" = true ]; then
  {
    echo "has_reports=true"
    echo "report_summary<<EOF"
    printf '%s' "$REPORT_SUMMARY"
    echo "EOF"
  } >> "$out"
else
  echo "has_reports=false" >> "$out"
fi
