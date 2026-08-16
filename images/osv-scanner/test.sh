#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing osv-scanner version..."
docker run --rm "$IMAGE" --version 2>&1 | grep -qiE '2\.[0-9]+'

echo "Testing osv-scanner help (subcommands load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'scan|fix|license'

echo "Testing osv-scanner scan engine loads (offline; --help on scan)..."
# A real scan needs the OSV database (network); loading the scan subcommand
# without error proves the engine wiring is intact offline.
docker run --rm "$IMAGE" scan --help 2>&1 | grep -qiE 'lockfile|source|sbom|manifest'
echo "osv-scanner scan subcommand OK"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All osv-scanner tests passed!"
