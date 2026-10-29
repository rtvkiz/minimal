#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing temporal-ui-server binary runs..."
out=$(docker run --rm "$IMAGE" --help 2>&1 | head -20 || true)
echo "$out" | grep -qiE 'ui-server|temporal|usage|config' \
  || { echo "FAIL: unexpected --help output:"; echo "$out"; exit 1; }

# The whole point of this image: the SvelteKit bundle is embedded in the binary
# via //go:embed. A UI server with no UI would still start and still pass a
# version check, so assert the assets are actually in there.
echo "Testing the embedded web UI assets are present in the binary..."
# Measure the binary itself, not `docker image inspect .Size`: with the
# containerd image store (Docker 29 runners) that reports the COMPRESSED size,
# ~10.7MB for a 26.5MB binary, and failed a build whose bundle was intact.
cid=$(docker create "$IMAGE")
size=$(docker cp "$cid:/usr/bin/temporal-ui-server" - | tar -xOf - | wc -c)
docker rm -f "$cid" >/dev/null
[ "$size" -gt 20000000 ] \
  || { echo "FAIL: binary is only $size bytes — embedded UI assets likely missing"; exit 1; }
echo "binary size ${size} bytes (UI bundle embedded)"

echo "Testing it fails cleanly with no config..."
out=$(docker run --rm "$IMAGE" 2>&1 | head -20 || true)
case "$out" in
  *onfig*|*"no such file"*|*"unable to"*|*"failed to"*|*error*|*Error*|*listen*|*started*) ;;
  *) echo "FAIL: unexpected output with no config:"; echo "$out"; exit 1 ;;
esac

echo "Verifying no shell in the production image..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1; then
  echo "FAIL: /bin/sh present in a production image"; exit 1
fi
echo "No shell (as expected)"

echo "✓ All temporal-ui-server tests passed"
