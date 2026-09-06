#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing syncthing version..."
sv=$(docker run --rm --entrypoint /usr/bin/syncthing "$IMAGE" --version 2>&1)
echo "$sv" | grep -qE 'syncthing v2\.[0-9]+' || { echo "unexpected version: $sv"; exit 1; }

echo "Verifying the self-updater is compiled out..."
# Built with -tags noupgrade, matching upstream's container build. A hardened
# read-only image must never be able to replace its own binary.
echo "$sv" | grep -q 'noupgrade' || { echo "FAIL: noupgrade tag missing: $sv"; exit 1; }

echo "Testing syncthing subcommands are wired..."
docker run --rm --entrypoint /usr/bin/syncthing "$IMAGE" --help 2>&1 | grep -qE 'serve|generate|cli'

echo "Testing syncthing serves its REST API..."
# Full round-trip: boot the daemon, let it generate its device certificate and
# open the SQLite index database under /var/syncthing, then answer on the GUI
# port. Exercises the writable state dirs, the pure-Go SQLite driver and the
# generated web assets — not just that the binary parses a flag.
CID=$(docker run -d --rm -p 18384:8384 "$IMAGE")
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT

ok=""
for _ in $(seq 1 45); do
  if curl -fsS --max-time 3 http://127.0.0.1:18384/rest/noauth/health 2>/dev/null | grep -q 'OK'; then
    ok=1; break
  fi
  sleep 1
done
[ -n "$ok" ] || { echo "FAIL: syncthing did not serve /rest/noauth/health"; docker logs "$CID" 2>&1 | tail -30; exit 1; }
echo "syncthing REST health OK"

echo "Verifying the web GUI assets were generated into the binary..."
# lib/api/auto/gui.files.go is .gitignore'd upstream and regenerated at build
# time; skip that step and the daemon still boots but serves nothing. The
# noassets.go fallback returns 404 here, so this asserts the generator ran.
gui=$(curl -fsS --max-time 5 http://127.0.0.1:18384/ 2>/dev/null || true)
echo "$gui" | grep -qi '<html' || { echo "FAIL: GUI assets missing (noassets fallback?)"; exit 1; }
echo "GUI assets OK"

echo "Verifying /var/syncthing is writable by nonroot..."
docker logs "$CID" 2>&1 | grep -qiE 'permission denied' \
  && { echo "FAIL: permission denied writing /var/syncthing"; exit 1; } || echo "/var/syncthing writable OK"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All syncthing tests passed!"
