#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing grype version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE 'Version:[[:space:]]*v?0\.[0-9]'

echo "Testing grype help..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'vulnerabilit|scan|db'

# NB: an actual grype scan requires downloading the vuln DB (network), so it is
# not part of this hermetic smoke test. `grype db status` runs offline and must
# print DB status text (exit code is non-zero when no DB is installed, which is
# expected in a fresh image — we only assert it produces the status line).
echo "Testing grype db status (offline)..."
docker run --rm "$IMAGE" db status 2>&1 | grep -qiE 'status|location|database' \
  || { echo "FAIL: grype db status produced no status output"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All grype tests passed!"
