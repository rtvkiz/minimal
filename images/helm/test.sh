#!/bin/bash
# NB: no -o pipefail — `docker run | grep -q` is SIGPIPE-prone (grep closes
# the pipe early, docker exits 141, pipefail blows the script). Capture to
# a variable then grep.
set -eu

echo "Testing helm version..."
VERSION_OUT=$(docker run --rm --entrypoint /usr/bin/helm "$IMAGE" version --short)
echo "$VERSION_OUT"
# Assert the binary reports exactly the version the recipe built, rather than a
# hardcoded major. Two reasons: the catalog tracks upstream across majors, so a
# literal ^v3 assertion breaks on every major bump; and comparing against the
# recipe also catches a broken -X ldflags path (helm 4 moved the module to
# helm.sh/helm/v4 — a stale v3 path stamps nothing and `version --short`
# silently reports an empty version, which ^v3 would have caught only by luck).
EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')
if [ -z "$EXPECTED" ]; then
  echo "FAIL: could not read version from melange.yaml"
  exit 1
fi
if ! echo "$VERSION_OUT" | grep -qE "^v${EXPECTED//./\\.}([+.-]|$)"; then
  echo "FAIL: expected v${EXPECTED} in helm version output, got: ${VERSION_OUT}"
  exit 1
fi

echo "Testing helm create + lint roundtrip..."
# Helm writes the chart to cwd. Use a host bind-mount so create and lint
# (two separate ephemeral containers) share the workdir. Run as host uid so
# files end up owned by the test runner — cleanup works without root and CI
# doesn't have to chmod -R afterwards.
TMP_VOL=$(mktemp -d)
trap 'rm -rf "$TMP_VOL"' EXIT
HOST_UID=$(id -u)
HOST_GID=$(id -g)
docker run --rm --user "${HOST_UID}:${HOST_GID}" --workdir /work --network none \
  -v "$TMP_VOL:/work" \
  --entrypoint /usr/bin/helm "$IMAGE" create smoke-chart >/dev/null
docker run --rm --user "${HOST_UID}:${HOST_GID}" --workdir /work --network none \
  -v "$TMP_VOL:/work" \
  --entrypoint /usr/bin/helm "$IMAGE" lint smoke-chart
echo "helm create + lint OK"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All helm tests passed!"
