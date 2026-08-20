#!/usr/bin/env bash
#
# Decide WHY a melange/apko build job failed: did the change under test actually
# break the image, or did an upstream service misbehave?
#
# This distinction is the whole safety property of automated toolchain repair.
# The repair step reverts an image's pin when the image cannot build on a new
# toolchain — but a revert is silent and durable, so reverting because Sigstore
# was down would leave an image pinned backwards for no reason and looking
# deliberate. Getting this wrong is worse than not repairing at all.
#
# So: only a genuine BUILD failure authorises a revert. Anything that smells of
# infrastructure returns "transient" (retry later), and anything unrecognised
# returns "unknown" (leave the PR red for a human). Conservative by construction
# — the failure modes are asymmetric.
#
# The transient signatures are not hypothetical. Every one below was observed
# breaking this repo's CI on 2026-08-19/20, none caused by a code change:
#   Wolfi mid-migration index   nothing provides "glibc-2.43"
#   Wolfi index                 unable to build guest: resolving apk packages
#   Sigstore Fulcio             connection reset by peer
#   GitHub                      429 Too Many Requests
#   upstream tarball mutated    <file>: FAILED  (sha256sum -c)
#   generic network             curl (22)/(35), i/o timeout, TLS handshake
#
# Usage:  classify-build-failure.sh <logfile>
# Echoes exactly one of: build | transient | unknown   (exit 0)
set -euo pipefail

log="${1:?usage: classify-build-failure.sh <logfile>}"
[ -r "$log" ] || { echo "unknown"; exit 0; }

# --- transient: upstream/infrastructure, never the image's fault -------------
# Checked FIRST. A toolchain bump can surface a compile error in the same job
# where the network also flaked; if anything infrastructural is present we
# refuse to claim the image is incompatible.
if grep -qaE \
  'nothing provides|unable to build guest|resolving apk packages|solving ".*" constraint' "$log" \
  || grep -qaE '(HTTP|status code|returned error:|^|[^0-9.])429 |429 Too Many Requests|Too Many Requests|rate limit' "$log" \
  || grep -qaE 'fulcio\.sigstore\.dev|rekor\.sigstore\.dev|signing bundle|error signing' "$log" \
  || grep -qaE 'connection reset by peer|i/o timeout|TLS handshake|unexpected EOF|no such host' "$log" \
  `# Go module proxy: HTTP/2 stream resets mid-download. Observed 2026-08-20` \
  `# taking out jaeger, otelcol, gitea and openbao in one scheduled run.` \
  || grep -qaE 'proxy\.golang\.org.*(stream error|INTERNAL_ERROR|unexpected EOF|timeout)|stream error: stream ID [0-9]+' "$log" \
  || grep -qaE 'go: .*: (Get|read) "https?://[^"]*": ' "$log" \
  || grep -qaE 'curl: \((22|35|52|56|92)\)|Recv failure|Could not resolve host' "$log" \
  `# sha256sum -c prints "<file>: FAILED"; melange prefixes it with a timestamp,` \
  `# so this cannot be anchored at line start.` \
  || grep -qaE '[^ ]+: FAILED([[:space:]]|$)|sha256sum: WARNING|checksum mismatch' "$log" \
  || grep -qaE 'no space left on device|Cannot allocate memory|signal: killed' "$log" ; then
  echo "transient"; exit 0
fi

# --- build: the compiler rejected the source ---------------------------------
# Go's compile diagnostics are "<file>:<line>:<col>: <message>". Requiring the
# file:line:col shape keeps this from matching prose that merely says "error".
if grep -qaE '^[^ ]+\.go:[0-9]+:[0-9]+: ' "$log" \
  || grep -qaE 'undefined: |not enough arguments in call to |cannot use .* as .* value' "$log" \
  || grep -qaE 'declared and not used|imported and not used' "$log" \
  || grep -qaE 'error\[E[0-9]+\]:' "$log" `# rustc` \
  || grep -qaE '^error: could not compile' "$log" \
  || grep -qaE 'requires [^ ]+@[^ ,]+, not |module .* found .*but does not contain package' "$log" ; then
  echo "build"; exit 0
fi

# Anything else: do not guess.
echo "unknown"
