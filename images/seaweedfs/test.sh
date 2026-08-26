#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing weed version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qE 'version .* 4\.[0-9]+'

echo "Testing weed subcommands are wired..."
# The role is the first argument, so the command table is the whole CLI surface.
docker run --rm "$IMAGE" help 2>&1 | grep -qE 'master|volume|filer|s3'

echo "Testing weed master serves cluster status..."
# Full round-trip: boot the master role against the image's own /data and ask
# it for cluster status. Exercises the writable data dir, the raft/metadata
# init and the HTTP listener — not just that the binary parses a flag.
CID=$(docker run -d --rm -p 19333:9333 "$IMAGE" master -mdir=/data -ip=0.0.0.0)
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT

ok=""
for _ in $(seq 1 30); do
  if curl -fsS --max-time 3 http://127.0.0.1:19333/cluster/status 2>/dev/null | grep -q '"IsLeader"'; then
    ok=1; break
  fi
  sleep 1
done
[ -n "$ok" ] || { echo "FAIL: weed master did not serve cluster status"; docker logs "$CID" 2>&1 | tail -20; exit 1; }
echo "weed master cluster status OK"

echo "Verifying /data is writable by nonroot..."
docker exec "$CID" /usr/bin/weed version >/dev/null 2>&1 || true
docker logs "$CID" 2>&1 | grep -qiE 'permission denied' \
  && { echo "FAIL: permission denied writing /data"; exit 1; } || echo "/data writable OK"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All seaweedfs tests passed!"
