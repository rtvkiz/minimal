#!/bin/bash
# NB: no -o pipefail — `docker run | grep -q` is SIGPIPE-prone (grep closes
# the pipe early, docker exits 141, pipefail blows the script). Capture to
# a variable then grep.
set -eu

echo "Testing helm version..."
VERSION_OUT=$(docker run --rm --entrypoint /usr/bin/helm "$IMAGE" version --short)
echo "$VERSION_OUT"
if ! echo "$VERSION_OUT" | grep -qE '^v3\.[0-9]+\.[0-9]+'; then
  echo "FAIL: expected v3.x.y in helm version output"
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
