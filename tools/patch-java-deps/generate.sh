#!/usr/bin/env bash
# Generate the patch-java-deps melange block for one image from its grype report.
#
# Why this exists: images like solr and cassandra ship Apache's *prebuilt*
# tarball, so the bundled JARs are whatever upstream vendored — netty 4.2.6,
# jackson 2.20.0, opennlp 2.5.6. We rebuild nothing, so nothing bumps them, and
# grype is right to flag them. patch-go-deps solves the identical problem for Go
# by pinning deps at build time; this is its Java counterpart, swapping the
# vulnerable JAR for the fixed one from Maven Central.
#
# Usage: generate.sh <grype-report.json>
# Writes the block to stdout. Emits nothing (exit 1) if there is nothing to fix.
set -euo pipefail

REPORT="${1:?usage: generate.sh <grype-report.json>}"
[ -s "$REPORT" ] || { echo "FATAL: $REPORT missing or empty" >&2; exit 1; }

# One row per (group, artifact, installed-version) with the HIGHEST fix version
# across all its CVEs — a single JAR usually has several advisories with
# different fix targets, and only the max clears them all.
rows=$(jq -r '
  [ .matches[]
    | select(.artifact.type == "java-archive")
    | select(.vulnerability.fix.state == "fixed")
    | select(.vulnerability.fix.versions | length > 0)
    | { purl: .artifact.purl,
        old:  .artifact.version,
        path: .artifact.locations[0].path,
        fix:  .vulnerability.fix.versions[] } ]
  | group_by(.purl)
  | .[]
  | { purl: .[0].purl, old: .[0].old, path: .[0].path,
      fixes: [ .[].fix ] | unique }
  | "\(.purl)\t\(.old)\t\(.path)\t\(.fixes | join(","))"
' "$REPORT")

[ -n "$rows" ] || { echo "nothing to patch" >&2; exit 1; }

emit() { printf '      %s\n' "$1"; }

emit '# patch-java-deps: auto-generated — do not edit manually'
emit '#'
emit '# Upstream ships prebuilt JARs; these are the vendored copies grype flags.'
emit '# Each swap replaces one vulnerable JAR with the fixed release from Maven'
emit '# Central. A swap that finds no matching file is a hard error: it means the'
emit '# bundled version moved and this block is stale, which must not be mistaken'
emit '# for "nothing to do".'
emit 'jar_swap() {'
emit '  _g="$1"; _a="$2"; _old="$3"; _new="$4"; _cls="${5:-}"'
emit '  _sfx=""; [ -n "$_cls" ] && _sfx="-$_cls"'
emit '  _url="https://repo1.maven.org/maven2/$(echo "$_g" | tr . /)/$_a/$_new/$_a-$_new$_sfx.jar"'
emit '  _n=0'
emit '  for _f in $(find "$JARROOT" -name "$_a-$_old$_sfx.jar"); do'
emit '    _d=$(dirname "$_f")'
emit '    curl -sSfL --connect-timeout 10 --max-time 120 --retry 3 --retry-delay 5 \'
emit '      "$_url" -o "$_d/$_a-$_new$_sfx.jar"'
emit '    # A truncated or HTML error body would install silently and only fail at'
emit '    # runtime; every JAR is a zip, so check the magic bytes before deleting'
emit '    # the copy we are replacing.'
emit '    case "$(head -c2 "$_d/$_a-$_new$_sfx.jar")" in'
emit '      PK) ;;'
emit '      *) echo "patch-java-deps: $_a-$_new$_sfx.jar is not a zip" >&2; exit 1 ;;'
emit '    esac'
emit '    rm -f "$_f"'
emit '    _n=$((_n + 1))'
emit '  done'
emit '  if [ "$_n" -eq 0 ]; then'
emit '    echo "patch-java-deps: no $_a-$_old$_sfx.jar found under $JARROOT" >&2'
emit '    exit 1'
emit '  fi'
emit '  echo "patch-java-deps: $_a $_old -> $_new ($_n file(s))"'
emit '}'
emit ''

# Align every artifact in a group to the SAME target version. Netty, Jetty and
# Jackson modules are released in lockstep and will throw NoSuchMethodError on a
# mixed classpath, so taking each artifact's own minimum fix would build an image
# that scans clean and crashes on startup.
declare -A GROUP_TARGET=()
while IFS=$'\t' read -r purl old path fixes; do
  [ -n "$purl" ] || continue
  ga=${purl#pkg:maven/}; ga=${ga%@*}
  group=${ga%/*}
  hi=$(printf '%s\n' "${fixes//,/$'\n'}" | sort -V | tail -1)
  cur=${GROUP_TARGET[$group]:-}
  if [ -z "$cur" ] || [ "$(printf '%s\n%s\n' "$cur" "$hi" | sort -V | tail -1)" = "$hi" ]; then
    GROUP_TARGET[$group]=$hi
  fi
done <<< "$rows"

# Confirm the target JAR actually exists before emitting a swap. A version can
# be present in Maven metadata and still publish no jar: org.lz4:lz4-java:1.8.1
# ships only a .pom, so grype advises a fix that cannot be installed. Checking
# here turns that into a recorded skip instead of a 404 at build time.
jar_exists() {
  curl -sfI --connect-timeout 10 --max-time 30 \
    "https://repo1.maven.org/maven2/$(echo "$1" | tr . /)/$2/$3/$2-$3${4:+-$4}.jar" \
    -o /dev/null
}

declare -A OLD_VERSIONS=() OLD_GROUP=() OLD_TARGET=() OLD_PREFIX=()
skipped=0
while IFS=$'\t' read -r purl old path fixes; do
  [ -n "$purl" ] || continue
  # pkg:maven/<group>/<artifact>@<version>
  ga=${purl#pkg:maven/}; ga=${ga%@*}
  group=${ga%/*}; artifact=${ga##*/}
  new=${GROUP_TARGET[$group]}
  # A classifier shows up in the filename but not the purl, e.g.
  # netty-transport-native-epoll-4.2.6.Final-linux-x86_64.jar.
  base=$(basename "$path" .jar)
  cls=""
  case "$base" in
    "$artifact-$old") ;;
    "$artifact-$old-"*) cls=${base#"$artifact-$old-"} ;;
  esac

  if ! jar_exists "$group" "$artifact" "$new" "$cls"; then
    emit "# SKIPPED $artifact $old -> $new: no jar published at that version."
    emit "#   Still vulnerable; needs a VEX entry or an upstream fix."
    echo "skip: $artifact $old -> $new (no jar on Maven Central)" >&2
    skipped=$((skipped + 1))
    continue
  fi

  # Only record the old version once a swap is actually emitted — the sweep and
  # guard below must not trip on a family we deliberately left alone.
  OLD_VERSIONS[$old]=1
  OLD_GROUP[$old]=$group
  OLD_TARGET[$old]=$new
  # A shared version string does not imply a shared family: calcite-core and
  # opentelemetry-semconv are both 1.37.0 and belong to different groups. Record
  # the artifact-id prefix so the sweep touches only real family members.
  pfx=${artifact%%-*}
  case " ${OLD_PREFIX[$old]:-} " in
    *" $pfx "*) ;;
    *) OLD_PREFIX[$old]="${OLD_PREFIX[$old]:-}${OLD_PREFIX[$old]:+ }$pfx" ;;
  esac
  emit "jar_swap $group $artifact $old $new $cls"
done <<< "$rows"

emit ''
emit '# Sweep the rest of each upgraded family. Siblings with no CVE of their own'
emit '# never appear in a scan report — log4j-api, log4j-web and log4j-slf4j2-impl'
emit '# sat at 2.25.3 while log4j-core moved to 2.25.4, and log4j-core against a'
emit '# mismatched log4j-api is a LoggerContext failure at startup. Anything still'
emit '# at the old version is pulled up to the same target.'
emit 'family_sweep() {'
emit '  _g="$1"; _old="$2"; _new="$3"; _p="$4"'
emit '  # Match the family by major.minor SERIES, not by exact version and not by'
emit '  # prefix alone. Exact missed jackson-annotations, which sits at 2.20 while'
emit '  # databind is 2.20.0 — Solr died with NoClassDefFoundError JsonSerializeAs.'
emit '  # Prefix alone was too wide: netty-tcnative-boringssl-static shares the'
emit '  # netty prefix and the io.netty group but versions independently at 2.0.x,'
emit '  # and forcing it to 4.2.16.Final has no release to point at.'
emit '  _series=$(echo "$_old" | cut -d. -f1,2)'
emit '  for _f in $(find "$JARROOT" -name "$_p*.jar"); do'
emit '    _b=$(basename "$_f" .jar)'
emit '    _v="${_b##*-}"'
emit '    # Trailing field is a classifier, not a version (…-linux-x86_64.jar).'
emit '    case "$_v" in [0-9]*) ;; *) continue ;; esac'
emit '    [ "$_v" = "$_new" ] && continue'
emit '    # Different release line under the same prefix — not this family.'
emit '    [ "$(echo "$_v" | cut -d. -f1,2)" = "$_series" ] || continue'
emit '    _a="${_b%-$_v}"'
emit '    _tok=$(echo "$_a" | cut -d- -f2)'
emit '    _found=0'
emit '    # Target: exact, then patch-trimmed (2.21.5 -> 2.21) for artifacts that'
emit '    # release on major.minor only.'
emit '    for _tv in "$_new" "${_new%.*}"; do'
emit '      # Group: as given, then the two split-family shapes (jackson replaces'
emit '      # the last segment, jetty appends).'
emit '      for _cand in "$_g" "${_g%.*}.$_tok" "$_g.$_tok"; do'
emit '        _u="https://repo1.maven.org/maven2/$(echo "$_cand" | tr . /)/$_a/$_tv/$_a-$_tv.jar"'
emit '        if curl -sfI --connect-timeout 10 --max-time 30 "$_u" -o /dev/null; then'
emit '          _found=1; break'
emit '        fi'
emit '      done'
emit '      [ "$_found" -eq 1 ] && break'
emit '    done'
emit '    if [ "$_found" -eq 0 ]; then'
emit '      echo "patch-java-deps: no release of $_a for family target $_new" >&2'
emit '      exit 1'
emit '    fi'
emit '    curl -sSfL --connect-timeout 10 --max-time 120 --retry 3 --retry-delay 5 \'
emit '      "$_u" -o "$(dirname "$_f")/$_a-$_tv.jar"'
emit '    case "$(head -c2 "$(dirname "$_f")/$_a-$_tv.jar")" in'
emit '      PK) ;;'
emit '      *) echo "patch-java-deps: $_a-$_tv.jar is not a zip" >&2; exit 1 ;;'
emit '    esac'
emit '    [ "$_f" = "$(dirname "$_f")/$_a-$_tv.jar" ] || rm -f "$_f"'
emit '    echo "patch-java-deps: swept $_a $_v -> $_tv"'
emit '  done'
emit '}'
for v in "${!OLD_VERSIONS[@]}"; do
  for p in ${OLD_PREFIX[$v]}; do
    emit "family_sweep ${OLD_GROUP[$v]} $v ${OLD_TARGET[$v]} $p"
  done
done

emit ''
emit '# Backstop: report every remaining mismatch in one pass. Exiting at the first'
emit '# one costs a full CI cycle per family to discover the next.'
emit 'stragglers=""'
for v in "${!OLD_VERSIONS[@]}"; do
  for p in ${OLD_PREFIX[$v]}; do
    emit "stragglers=\"\$stragglers\$(find \"\$JARROOT\" -name \"$p*-$v.jar\" -o -name \"$p*-$v-*.jar\")\""
  done
done
emit 'if [ -n "$stragglers" ]; then'
emit '  echo "patch-java-deps: JARs still at a superseded version:" >&2'
emit '  echo "$stragglers" >&2'
emit '  exit 1'
emit 'fi'

emit '# end-patch-java-deps'
