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
# $4 = optional classifier (linux-x86_64, ...) for native/per-platform artifacts
maven_path() {
  local sfx=""
  [ -n "${4:-}" ] && [ "${4:-}" != "-" ] && sfx="-$4"
  printf '%s/%s/%s/%s-%s%s.jar' "$1" "$2" "$3" "$2" "$3" "$sfx"
}
maven_url() { printf 'https://repo1.maven.org/maven2/%s' "$(maven_path "$@")"; }

# Maven Central mirrors, in preference order.
#
# repo1.maven.org and repo.maven.apache.org both resolve into Cloudflare's
# range (2606:4700::/32), so a WAF-level 403 refuses BOTH — they are one host
# for resilience purposes. maven-central.storage-download.googleapis.com is
# Google infrastructure and is the mirror that actually rescues a block.
MAVEN_MIRRORS='https://repo1.maven.org/maven2 https://maven-central.storage-download.googleapis.com/maven2 https://repo.maven.apache.org/maven2'

# Fetch one Maven artifact, rotating mirrors BEFORE widening the wait.
#
# A per-host 403/429 clears in seconds by switching hosts; waiting one out does
# not. Both times we lost, the backoff was working correctly and simply lost the
# race against a block on a single host:
#
#   2026-08-23  opensearch  403, 9 attempts over 4m15s, all to one host
#   2026-08-26  solr        403, 9 attempts over 4m15s, all to one host
#
# So every mirror is tried within the first few seconds, and the backoff only
# grows once all of them have refused — which is the signal that the problem is
# not host-specific.
maven_fetch() {  # $1=path-after-/maven2/  $2=output file
  local path="$1" out="$2" round base
  for round in 1 2 3 4; do
    for base in $MAVEN_MIRRORS; do
      if curl -fsSL --connect-timeout 15 --max-time 300 \
           --retry 2 --retry-all-errors "$base/$path" -o "$out"; then
        return 0
      fi
    done
    [ "$round" -lt 4 ] && sleep $(( round * 30 ))
  done
  echo "maven_fetch: all mirrors refused $path" >&2
  return 1
}
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
  LIFT_DECLINED=""
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
    maven_fetch "$(maven_path "$gpath" "$artifact" "$fixv")" "$tmp"
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
      while IFS='|' read -r artifact gpath inst fixv sha cls; do
        [ -n "$artifact" ] || continue
        [ "${cls:--}" = "-" ] || continue
        pfx="${artifact%%-*}"
        series="$(printf '%s' "$inst" | cut -d. -f1,2)"
        group="${gpath//\//.}"
        # Same group, same prefix, same major.minor series, wrong version.
        while IFS=$'\t' read -r sib sibver sibgroup; do
          [ -n "$sib" ] || continue
          [ "$sib" = "$artifact" ] && continue
          [ -n "${seen2[$sib]:-}" ] && continue
          [ "$sibver" = "$fixv" ] && continue
          case "$sib" in "$pfx"*) ;; *) continue ;; esac
          [ "$(printf '%s' "$sibver" | cut -d. -f1,2)" = "$series" ] || continue
          # Resolve each sibling under ITS OWN Maven group, not the flagged
          # artifact's.
          #
          # Families span groups: Jackson lives in .core, .dataformat,
          # .datatype, .module and .jakarta.rs; Jetty in org.eclipse.jetty and
          # org.eclipse.jetty.ee10. The lift used to search only the flagged
          # artifact's group while the straggler guard checks by NAME PREFIX
          # across the whole jar root — so the guard kept finding siblings the
          # lift structurally could not reach, and failed the build over them
          # (kafka/cassandra, 2026-08-27..28: jackson-dataformat-csv,
          # jackson-datatype-jdk8, jackson-module-blackbird, jetty-ee10-servlet
          # all exist at the target version and were simply never considered).
          sibgpath=$(printf '%s' "${sibgroup:-$group}" | tr . /)
          published "$sibgpath" "$sib" "$fixv" || {
            # Not every module in a family publishes every patch release —
            # jackson-annotations stops at 2.21 while jackson-databind goes to
            # 2.21.5. Declining is correct, but the straggler guard below must
            # be told, or it fails the build for the very artifact we just
            # decided (rightly) to leave alone.
            echo "  family lift: $sib has no $fixv under $group, leaving it"
            LIFT_DECLINED="${LIFT_DECLINED}${sib}"$'\n'
            continue; }
          tmp=$(mktemp)
          maven_fetch "$(maven_path "$sibgpath" "$sib" "$fixv")" "$tmp"
          sha2=$(sha256sum "$tmp" | awk '{print $1}'); rm -f "$tmp"
          SWAPS="${SWAPS}${sib}|${sibgpath}|${sibver}|${fixv}|${sha2}|-"$'\n'
          seen2[$sib]=1
          echo "  family lift: $sib $sibver -> $fixv (no CVE of its own)"
        done < <(jq -r '
            .artifacts[]? | select(.type == "java-archive")
            | select((.purl // "") | startswith("pkg:maven/"))
            | [.name, .version, (.purl | split("/")[1])] | @tsv' "$inv" 2>/dev/null)
      done <<< "$SWAPS"
      # --- classifier variants ------------------------------------------------
      # Native artifacts ship one jar per platform
      # (netty-codec-native-quic-<ver>-linux-x86_64.jar). A plain swap matches
      # only the classifier-less file, so those stayed on the old version — a
      # genuinely mixed netty that the sibling guard then failed the build over
      # (opensearch, netty 4.2.16 -> 4.2.17). Central publishes every classifier
      # artifact, so discover which ones this image actually ships from syft's
      # location paths and pin one swap each.
      CLS_ADD=""
      while IFS='|' read -r artifact gpath inst fixv sha cls; do
        [ -n "$artifact" ] || continue
        [ "${cls:--}" = "-" ] || continue
        while read -r c; do
          [ -n "$c" ] || continue
          published "$gpath" "$artifact" "$fixv" "$c" || {
            echo "  classifier: $artifact $fixv has no -$c on Central, leaving it"; continue; }
          tmp=$(mktemp)
          maven_fetch "$(maven_path "$gpath" "$artifact" "$fixv" "$c")" "$tmp"
          sha3=$(sha256sum "$tmp" | awk '{print $1}'); rm -f "$tmp"
          CLS_ADD="${CLS_ADD}${artifact}|${gpath}|${inst}|${fixv}|${sha3}|${c}"$'\n'
          echo "  classifier: $artifact $inst -> $fixv ($c)"
        done < <(jq -r --arg n "$artifact" '
            .artifacts[]? | select(.name == $n) | .locations[]?.path' "$inv" 2>/dev/null \
          | sed 's|.*/||' \
          | sed -n "s/^.*${artifact}-${inst}-\(.*\)\.jar$/\1/p" | sort -u)
      done <<< "$SWAPS"
      SWAPS="${SWAPS}${CLS_ADD}"
    else
      echo "  WARN: syft inventory failed; siblings without advisories may be missed"
    fi
    rm -f "$inv"
    unset seen2
  else
    echo "  WARN: syft not installed; cannot lift families, only guard them"
  fi

  # --- sticky merge with the swaps already in the recipe ----------------------
  # The scan reads the PUBLISHED image, which was built WITH the previous block
  # applied. So a swap that worked makes its own CVE disappear, the next scan
  # emits nothing for it, and regenerating from the scan alone DELETES the swap
  # that was holding the fix. The next build then ships the pristine upstream
  # jar again and the CVE returns — an oscillation with a live vulnerability
  # window on every cycle, not the harmless "re-flagged next scan" the old
  # comment claimed. It removed 21 netty/micrometer/postgresql swaps from
  # keycloak in #560 exactly this way.
  #
  # Fix: a swap is never dropped because its CVE went quiet. Union the existing
  # block with this scan's findings, keeping the HIGHER fix version per
  # artifact so a genuinely newer fix still supersedes an old pin. Retained
  # swaps are safe: rename matches the exact old filename and no-ops once
  # upstream ships the fix, and keep-filename is version-guarded at build time
  # (see _swap) so it can never write an older jar over a newer one.
  if grep -q "# ${marker_id}: auto-generated" "$melange"; then
    PRIOR=$(awk -v id="$marker_id" '
      $0 ~ "# " id ": auto-generated" {inb=1; next}
      $0 ~ "# end-" id {inb=0}
      inb && $1 == "_swap" { print $2"|"$3"|"$4"|"$5"|"$6"|"($8==""?"-":$8) }
    ' "$melange")
    if [ -n "$PRIOR" ]; then
      scan_n=$(printf '%s' "$SWAPS" | grep -c . || true)
      declare -A BEST=()
      # Scan results first, then prior: whichever carries the higher fix version
      # wins, so a newer fix supersedes an old pin and a pin nobody re-flagged
      # is still carried forward.
      while IFS='|' read -r a g i f h c; do
        [ -n "$a" ] || continue
        c="${c:--}"
        # Key on artifact AND classifier: netty-codec-native-quic and its
        # -linux-x86_64 variant are different files, not duplicates of each other.
        k="${a}@${c}"
        cur="${BEST[$k]:-}"
        if [ -z "$cur" ]; then BEST[$k]="${a}|${g}|${i}|${f}|${h}|${c}"; continue; fi
        cur_f=$(printf '%s' "$cur" | cut -d'|' -f4)
        if ver_gt "$f" "$cur_f"; then BEST[$k]="${a}|${g}|${i}|${f}|${h}|${c}"; fi
      done <<< "$(printf '%s\n%s\n' "$SWAPS" "$PRIOR" | grep -v '^$')"
      SWAPS=""
      for k in "${!BEST[@]}"; do SWAPS="${SWAPS}${BEST[$k]}"$'\n'; done
      SWAPS=$(printf '%s' "$SWAPS" | grep -v '^$' | sort)
      kept_n=$(printf '%s' "$SWAPS" | grep -c . || true)
      echo "  sticky merge: ${scan_n} from scan + prior block -> ${kept_n} swap(s)"
      unset BEST
    fi
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
    printf '      #\n'
    printf '      # Mirrors are rotated BEFORE the wait is widened. repo1.maven.org and\n'
    printf '      # repo.maven.apache.org both sit behind Cloudflare, so a WAF 403 refuses\n'
    printf '      # both; the googleapis mirror is separate infrastructure. Waiting a single\n'
    printf '      # host out does not work — opensearch (2026-08-23) and solr (2026-08-26)\n'
    printf '      # each burned 9 attempts over 4m15s against one host and still failed.\n'
    printf '      _BJ_MIRRORS="https://repo1.maven.org/maven2 https://maven-central.storage-download.googleapis.com/maven2 https://repo.maven.apache.org/maven2"\n'
    printf '      _bj_fetch() {  # $1=path-after-/maven2/  $2=output\n'
    printf '        for _r in 1 2 3 4; do\n'
    printf '          for _b in $_BJ_MIRRORS; do\n'
    printf '            if curl -fsSL --connect-timeout 15 --max-time 300 \\\n'
    printf '                 --retry 2 --retry-all-errors "$_b/$1" -o "$2"; then return 0; fi\n'
    printf '          done\n'
    printf '          [ "$_r" -lt 4 ] && sleep $(( _r * 30 ))\n'
    printf '        done\n'
    printf '        echo "bundled-jar: all Maven mirrors refused $1" >&2; return 1\n'
    printf '      }\n'
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
      # Version guard for keep-filename. The block is now sticky (a swap is not
      # dropped just because its CVE went quiet), and keep-filename matches ANY
      # version of the artifact — so once upstream ships a jar NEWER than our
      # pin, an unguarded swap would overwrite it with the older one. Read what
      # the jar actually reports and skip when it is already >= the fix.
      printf '      _jarver() {  # echo the version a jar reports, or empty\n'
      printf '        _v=$(unzip -p "$1" "META-INF/maven/*/*/pom.properties" 2>/dev/null | sed -n "s/^version=//p" | head -1 | tr -d "\\r")\n'
      printf '        [ -n "$_v" ] || _v=$(unzip -p "$1" META-INF/MANIFEST.MF 2>/dev/null | sed -n "s/^Implementation-Version: //p" | head -1 | tr -d "\\r")\n'
      printf '        printf "%%s" "$_v"\n'
      printf '      }\n'
      printf '      _vge() {  # is $1 >= $2 ?\n'
      printf '        [ -n "$1" ] || return 1\n'
      printf '        awk -v a="$1" -v b="$2" \x27BEGIN{\n'
      printf '          na=split(a,A,/[._-]/); nb=split(b,B,/[._-]/); n=(na>nb?na:nb);\n'
      printf '          for(i=1;i<=n;i++){\n'
      printf '            if(A[i]~/^[0-9]+$/ && B[i]~/^[0-9]+$/){\n'
      printf '              if(A[i]+0!=B[i]+0) exit !((A[i]+0)>(B[i]+0));\n'
      printf '            } else if(A[i]!=B[i]) exit !(A[i]>B[i]); }\n'
      printf '          exit 0}\x27\n'
      printf '      }\n'
    fi
    printf '      _swap() {  # $1=artifact $2=group-path $3=oldver $4=newver $5=sha256 $6=mode $7=classifier|-\n'
    printf '        # $7 is a per-platform classifier (linux-x86_64, ...) or "-" for the plain\n'
    printf '        # jar. Native artifacts ship one jar per platform and the plain match skips\n'
    printf '        # them, which left a mixed netty in opensearch. Central publishes each\n'
    printf '        # classifier artifact, so they are pinned individually.\n'
    printf '        _c=""; [ "$7" = "-" ] || _c="-$7"\n'
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
    printf '          if [ -n "$_c" ]; then found=$(find "${{targets.destdir}}/%s" -name "*$1-[0-9]*$_c.jar")\n' "$jar_root"
    printf '          else found=$(find "${{targets.destdir}}/%s" -name "*$1-[0-9]*.jar" ! -name "*$1-[0-9]*-*.jar"); fi\n' "$jar_root"
    printf '        else\n'
    printf '          found=$(find "${{targets.destdir}}/%s" -name "*$1-$3$_c.jar")\n' "$jar_root"
    printf '        fi\n'
    printf '        [ -n "$found" ] || { echo "  $1 $3$_c not present (upstream may already ship >=$4)"; return 0; }\n'
    printf '        _bj_fetch "$2/$1/$4/$1-$4$_c.jar" /tmp/_bj.jar\n'
    printf '        echo "$5  /tmp/_bj.jar" | sha256sum -c -\n'
    # Stamp AFTER the checksum so what we verify is the pristine Central artifact.
    if [ "$strategy" = "keep-filename" ]; then
      printf '        _stamp /tmp/_bj.jar "$2" "$1" "$4"\n'
    fi
    printf '        for f in $found; do\n'
    printf '          if [ "$6" = "keep-filename" ]; then\n'
    printf '            _have=$(_jarver "$f")\n'
    printf '            if _vge "$_have" "$4"; then echo "  $1 already at $_have (>= $4), leaving it"; continue; fi\n'
    printf '            cp /tmp/_bj.jar "$f"\n'
    printf '          else cp /tmp/_bj.jar "$(dirname "$f")/$1-$4$_c.jar"; rm -f "$f"; fi\n'
    printf '          echo "  patched $1 $3 -> $4 ($6$_c)"\n'
    printf '        done\n'
    printf '        rm -f /tmp/_bj.jar\n'
    printf '      }\n'
    while IFS='|' read -r artifact gpath inst fixv sha cls; do
      [ -n "$artifact" ] || continue
      printf '      _swap %s %s %s %s %s %s %s\n' "$artifact" "$gpath" "$inst" "$fixv" "$sha" "$strategy" "${cls:--}"
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
      while IFS='|' read -r artifact gpath inst fixv sha cls; do
        [ -n "$artifact" ] || continue
        [ "${cls:--}" = "-" ] || continue   # classifier rows share the plain row's guard
        pfx="${artifact%%-*}"
        series="$(printf '%s' "$inst" | cut -d. -f1,2)"
        key="${pfx}|${series}|${fixv}"
        [ -n "${guarded[$key]:-}" ] && continue
        guarded[$key]=1
        # Artifacts the family lift declined are not stragglers — no such
        # version exists to lift them to. Excluding them keeps the guard and
        # the lift agreeing; without this they contradict each other and the
        # build fails on a correct decision (kafka/cassandra, 2026-08-27).
        _excl=""
        while IFS= read -r _d; do
          [ -n "$_d" ] || continue
          _excl="${_excl} ! -name \"${_d}-*.jar\""
        done <<< "$(printf '%s' "$LIFT_DECLINED" | sort -u)"
        printf '      find "${{targets.destdir}}/%s" \\( -name "%s*-%s.*.jar" -o -name "%s*-%s.jar" \\) ! -name "*-%s.jar" ! -name "*-%s-*.jar"%s >> "$_strag" 2>/dev/null || true\n' \
          "$jar_root" "$pfx" "$series" "$pfx" "$series" "$fixv" "$fixv" "$_excl"
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
