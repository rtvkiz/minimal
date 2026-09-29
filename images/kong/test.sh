#!/bin/bash
# Smoke test for minimal-kong (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing kong version..."
v=$(docker run --rm --entrypoint /usr/local/bin/kong "$IMAGE" version 2>&1 || true)
echo "$v" | grep -qiE '[0-9]+\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected version output: $v"; exit 1; }

echo "Testing kong subcommands load..."
h=$(docker run --rm --entrypoint /usr/local/bin/kong "$IMAGE" 2>&1 || true)
echo "$h" | grep -qi 'start' || { echo "FAIL: usage output missing subcommands: $h"; exit 1; }

echo "Testing kong starts DB-less and reports healthy (offline)..."
cid=$(docker run -d "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 20); do
  if docker exec "$cid" /usr/local/bin/kong health >/dev/null 2>&1; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: kong did not report healthy"; docker logs "$cid" 2>&1 | tail -30; exit 1; }

health=$(docker exec "$cid" /usr/local/bin/kong health 2>&1)
echo "$health" | grep -qi 'healthy' || { echo "FAIL: unexpected health output: $health"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying shell is busybox only (kong's ulimit-shellout exception, no bash/apk)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo shell-ok" 2>&1 | grep -q 'shell-ok' \
  || { echo "FAIL: expected busybox /bin/sh to be present"; exit 1; }
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo x" >/dev/null 2>&1 \
  && { echo "FAIL: bash found — restraint guard violated"; exit 1; } \
  || echo "No bash (as expected)"
docker run --rm --entrypoint /sbin/apk "$IMAGE" --version >/dev/null 2>&1 \
  && { echo "FAIL: apk found — restraint guard violated"; exit 1; } \
  || echo "No apk (as expected)"

echo "All kong tests passed!"
