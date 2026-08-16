#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing syft version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE 'Version:[[:space:]]*v?1\.[0-9]'

echo "Testing syft help..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'scan|packages|sbom'

echo "Testing syft scan (fully offline, catalogs its own binary)..."
# syft cataloging a local Go binary needs no network; the binary embeds its
# module graph, so the SBOM must contain an artifacts array.
docker run --rm "$IMAGE" scan file:/usr/bin/syft -o json 2>/dev/null | grep -q '"artifacts"'

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All syft tests passed!"
