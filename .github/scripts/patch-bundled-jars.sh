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
#                  reference stays valid. Scanners read the version from the
#                  jar's internal META-INF/maven/**/pom.properties, so the CVE
#                  clears even though the filename still says the old version —
#                  but ONLY for jars that ship one. syft's precedence is
#                  pom.properties > filename > MANIFEST.MF, so a jar without it
#                  (micrometer-core, postgresql) kept reporting the old version
#                  forever despite being genuinely patched on disk. _stamp()
#                  writes the true coordinates into such jars for that reason.
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
  melange="images/${image}/melange.yaml"
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
  # Group comes from grype's purl (pkg:maven/<group>/<artifact>@<ver>), so a
  # new artifact needs no hand-written coord-map entry. coord-map remains an
  # override for the rare artifact whose purl is missing or wrong.
  #
  # This was the real blocker: the map had exactly one entry (jackson-databind),
  # so every other fixable jar was skipped with "no coord-map entry" — flink
  # shipped log4j 2.25.3 with six advisories for that reason alone.
  fixes=$(jq -r '
      [ .matches[]
        | select(.artifact.type == "java-archive")
        | select((.vulnerability.fix.versions | length) > 0)
        | { name: .artifact.name, installed: .artifact.version,
            fix: .vulnerability.fix.versions[0], purl: (.artifact.purl // "") }
      ] | unique_by(.name + .installed + .fix) | .[]
        | "\(.name)\t\(.installed)\t\(.fix)\t\(.purl)"
    ' "$scan_json" 2>/dev/null | sort -t"$(printf '\t')" -k1,1 -k3,3rV || true)
  rm -f "$scan_json"
  # Highest fix version per artifact is tried first; the loop takes the first
  # one that is actually published, so we land on the newest available fix.

  [ -n "$fixes" ] || { echo "  No fixable bundled-jar CVEs"; continue; }

  # Align every artifact in a group to that group's HIGHEST fix version before
  # resolving. Netty, Jetty, Jackson and Log4j release in lockstep and throw
  # NoSuchMethodError / NoClassDefFoundError on a mixed classpath, so taking
  # each artifact's own minimum fix builds an image that scans clean and will
  # not start. Solr proved this: log4j-core at 2.25.4 beside log4j-api at
  # 2.25.5 is exactly the pair that broke it.
  declare -A GROUP_MAX=()
  while IFS=$'\t' read -r a_ i_ f_ p_; do
    [ -n "$a_" ] || continue
    c_=$(jq -r --arg a "$a_" '.["coord-map"][$a] // ""' <<<"$row")
    if [ -n "$c_" ]; then g_="${c_%:*}"; else ga_="${p_#pkg:maven/}"; ga_="${ga_%@*}"; g_="${ga_%/*}"; fi
    [ -n "$g_" ] || continue
    cur_="${GROUP_MAX[$g_]:-}"
    if [ -z "$cur_" ] || ver_gt "$f_" "$cur_"; then GROUP_MAX[$g_]="$f_"; fi
  done <<< "$fixes"

  # Resolve each fix to the newest *published* version that clears it, pin sha256.
  # SWAPS lines: "artifact|group-path|installed|newver|sha256"
  SWAPS=""
  declare -A seen=()
  while IFS=$'\t' read -r artifact installed fix purl; do
    [ -n "$artifact" ] || continue
    [ -n "${seen[$artifact]:-}" ] && continue   # one swap per artifact (newest fix wins below)
    coord=$(jq -r --arg a "$artifact" '.["coord-map"][$a] // ""' <<<"$row")
    if [ -n "$coord" ]; then
      group="${coord%:*}"
    else
      # pkg:maven/<group>/<artifact>@<version>
      ga="${purl#pkg:maven/}"; ga="${ga%@*}"; group="${ga%/*}"
    fi
    [ -n "$group" ] && [ "$group" != "$artifact" ] \
      || { echo "  skip $artifact: no group from coord-map or purl ($purl)"; continue; }
    gpath="${group//.//}"
    inst="${installed#v}"; fixv="${fix#v}"
    # Lift to the group target so the whole family lands on one version.
    gmax="${GROUP_MAX[$group]:-}"
    if [ -n "$gmax" ] && ver_gt "${gmax#v}" "$fixv"; then
      echo "  $artifact: raising $fixv -> ${gmax#v} to match the $group family"
      fixv="${gmax#v}"
    fi

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
  unset seen GROUP_MAX

  # --- family lift ------------------------------------------------------------
  # Alignment above only reaches artifacts that APPEAR in the scan report. A
  # sibling with no advisory of its own never appears, so it is never swapped
  # and silently stays on the old version — opensearch lifted log4j-api to
  # 2.25.5 while log4j-core and log4j-jul sat at 2.25.4, which is the mixed
  # classpath that stops the JVM at startup.
  #
  # syft lists every package, not just vulnerable ones, so the rest of each
  # upgraded family can be pulled up too — resolved and sha256-pinned exactly
  # like any other swap, never guessed.
  if command -v syft >/dev/null 2>&1; then
    # Declared here, not with `seen` above: that one is unset before this block
    # runs, and under `set -u` indexing an unset associative array aborts the
    # script ("httpcore5: unbound variable") rather than reading as empty.
    declare -A seen2=()
    # Pre-seed with everything already swapped above. Without this a sibling that
    # DID have its own advisory gets re-emitted as a "lift" while walking another
    # row of the same family (the `$sib` = `$artifact` test below only skips the
    # row's own artifact), producing a duplicate _swap line — and for
    # keep-filename images the duplicate lands *after* the more specific
    # artifact's swap and clobbers it.
    while IFS='|' read -r a_ _rest; do
      [ -n "$a_" ] && seen2[$a_]=1
    done <<< "$SWAPS"
    inv=$(mktemp)
    if syft "$full_image" -o json >"$inv" 2>/dev/null; then
      while IFS='|' read -r artifact gpath inst fixv sha; do
        [ -n "$artifact" ] || continue
        pfx="${artifact%%-*}"
        series="$(printf '%s' "$inst" | cut -d. -f1,2)"
        group="${gpath//\//.}"
        # Same group, same prefix, same major.minor series, wrong version.
        while IFS=$'\t' read -r sib sibver; do
          [ -n "$sib" ] || continue
          [ "$sib" = "$artifact" ] && continue
          [ -n "${seen2[$sib]:-}" ] && continue
          [ "$sibver" = "$fixv" ] && continue
          case "$sib" in "$pfx"*) ;; *) continue ;; esac
          [ "$(printf '%s' "$sibver" | cut -d. -f1,2)" = "$series" ] || continue
          published "$gpath" "$sib" "$fixv" || {
            echo "  family lift: $sib has no $fixv under $group, leaving it"; continue; }
          tmp=$(mktemp)
          curl -fsSL --retry 5 --retry-all-errors "$(maven_url "$gpath" "$sib" "$fixv")" -o "$tmp"
          sha2=$(sha256sum "$tmp" | awk '{print $1}'); rm -f "$tmp"
          SWAPS="${SWAPS}${sib}|${gpath}|${sibver}|${fixv}|${sha2}"$'\n'
          seen2[$sib]=1
          echo "  family lift: $sib $sibver -> $fixv (no CVE of its own)"
        done < <(jq -r --arg g "$group" '
            .artifacts[]? | select(.type == "java-archive")
            | select((.purl // "") | test("pkg:maven/" + ($g | gsub("\\."; "\\.")) + "/"))
            | [.name, .version] | @tsv' "$inv" 2>/dev/null)
      done <<< "$SWAPS"
    else
      echo "  WARN: syft inventory failed; siblings without advisories may be missed"
    fi
    rm -f "$inv"
    unset seen2
  else
    echo "  WARN: syft not installed; cannot lift families, only guard them"
  fi

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
    if [ "$strategy" = "keep-filename" ]; then
      printf '      _stamp() {  # $1=jarfile $2=group-path $3=artifact $4=newver\n'
      printf '        # keep-filename leaves the old version in the filename, so a scanner only\n'
      printf '        # sees the real version if the jar carries META-INF/maven/**/pom.properties\n'
      printf '        # (syft precedence: pom.properties > filename > MANIFEST.MF). Jars that ship\n'
      printf '        # none — micrometer-core, postgresql — reported the OLD version forever\n'
      printf '        # while being genuinely patched on disk. Write the true coordinates so the\n'
      printf '        # SBOM and the scan match what the bytes actually are.\n'
      printf '        command -v zip >/dev/null 2>&1 || { echo "  WARN: no zip in build env; $3 keeps scanning as its old version"; return 0; }\n'
      printf '        unzip -l "$1" 2>/dev/null | grep -q "META-INF/maven/.*/pom.properties" && return 0\n'
      printf '        # Never touch a signed jar: an added entry can trip jarsigner verification.\n'
      printf '        unzip -l "$1" 2>/dev/null | grep -qE "META-INF/.*[.](SF|DSA|RSA|EC)$" && { echo "  $3 is signed, not stamping"; return 0; }\n'
      printf '        _g=$(echo "$2" | tr / .)\n'
      printf '        _d=$(mktemp -d) || return 0\n'
      printf '        mkdir -p "$_d/META-INF/maven/$_g/$3"\n'
      printf '        { echo "groupId=$_g"; echo "artifactId=$3"; echo "version=$4"; } > "$_d/META-INF/maven/$_g/$3/pom.properties"\n'
      printf '        ( cd "$_d" && zip -q "$1" "META-INF/maven/$_g/$3/pom.properties" )\n'
      printf '        rm -rf "$_d"\n'
      printf '        echo "  stamped $3 $4 pom.properties (jar ships none)"\n'
      printf '      }\n'
    fi
    printf '      _swap() {  # $1=artifact $2=group-path $3=oldver $4=newver $5=sha256 $6=mode\n'
    printf '        # rename: jar filename carries the version, match it exactly. keep-filename:\n'
    printf '        # filename stays the upstream version while contents change, so match any\n'
    printf '        # version of the artifact and overwrite in place. Two anchors on that\n'
    printf '        # match, both load-bearing: [0-9] pins the start of the version segment,\n'
    printf '        # or netty-codec matches netty-codec-http-*.jar and overwrites the http\n'
    printf '        # codec with the plain codec jar (keycloak died with NoClassDefFoundError\n'
    printf '        # FullHttpResponse); the ! -name excludes classifier jars\n'
    printf '        # (netty-transport-native-epoll-<v>-linux-x86_64.jar), whose content is\n'
    printf '        # NOT what $1-$4.jar holds — overwriting them drops the bundled .so.\n'
    printf '        if [ "$6" = "keep-filename" ]; then\n'
    printf '          found=$(find "${{targets.destdir}}/%s" -name "*$1-[0-9]*.jar" ! -name "*$1-[0-9]*-*.jar")\n' "$jar_root"
    printf '        else\n'
    printf '          found=$(find "${{targets.destdir}}/%s" -name "*$1-$3.jar")\n' "$jar_root"
    printf '        fi\n'
    printf '        [ -n "$found" ] || { echo "  $1 $3 not present (upstream may already ship >=$4)"; return 0; }\n'
    printf '        curl -fsSL --retry 5 --retry-all-errors \\\n'
    printf '          "https://repo1.maven.org/maven2/$2/$1/$4/$1-$4.jar" -o /tmp/_bj.jar\n'
    printf '        echo "$5  /tmp/_bj.jar" | sha256sum -c -\n'
    # Stamp AFTER the checksum so what we verify is the pristine Central artifact.
    if [ "$strategy" = "keep-filename" ]; then
      printf '        _stamp /tmp/_bj.jar "$2" "$1" "$4"\n'
    fi
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
    # Sibling guard. A family member with no CVE of its own never appears in a
    # scan report, so it is never swapped and silently stays behind — that is
    # how solr ended up with log4j-core 2.25.4 beside log4j-api 2.25.3 and died
    # at startup with NoClassDefFoundError. Fail the build and name the file
    # instead of shipping a mixed classpath. Scoped to the artifact prefix and
    # the old major.minor series so unrelated jars that merely share a version
    # string are left alone (calcite-core and opentelemetry-semconv were both
    # 1.37.0).
    # The `! -name "*-$fixv.jar"` exclusion is load-bearing: the series is the
    # major.minor of the OLD version, and nearly every fix is a patch-level bump
    # inside that same series (5.4 -> 5.4.3, 2.25.4 -> 2.25.5), so without it the
    # guard matches the jars _swap just wrote and fails every build.
    if [ "$strategy" != "keep-filename" ]; then
      printf '      _strag=/tmp/_bj_stragglers; : > "$_strag"\n'
      declare -A guarded=()
      while IFS='|' read -r artifact gpath inst fixv sha; do
        [ -n "$artifact" ] || continue
        pfx="${artifact%%-*}"
        series="$(printf '%s' "$inst" | cut -d. -f1,2)"
        key="${pfx}|${series}|${fixv}"
        [ -n "${guarded[$key]:-}" ] && continue
        guarded[$key]=1
        printf '      find "${{targets.destdir}}/%s" \\( -name "%s*-%s.*.jar" -o -name "%s*-%s.jar" \\) ! -name "*-%s.jar" >> "$_strag" 2>/dev/null || true\n' \
          "$jar_root" "$pfx" "$series" "$pfx" "$series" "$fixv"
      done <<< "$SWAPS"
      unset guarded
      printf '      if [ -s "$_strag" ]; then\n'
      printf '        echo "patch-bundled-jars: jars left on a superseded version:" >&2\n'
      printf '        sort -u "$_strag" >&2\n'
      printf '        rm -f "$_strag"; exit 1\n'
      printf '      fi\n'
      printf '      rm -f "$_strag"\n'
    fi
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
