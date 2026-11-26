#!/bin/bash
# Smoke test for minimal-rethinkdb (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing rethinkdb version..."
v=$(docker run --rm --network none "$IMAGE" --version 2>&1)
echo "$v" | grep -qE '^rethinkdb [0-9]+\.[0-9]+' || { echo "FAIL: unexpected --version: $v"; exit 1; }

name="minimal-rethinkdb-smoke-$$"
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT

echo "Starting the server with the default cmd (--bind all, data in /data)..."
docker run -d --name "$name" -p 127.0.0.1::8080 -p 127.0.0.1::28015 "$IMAGE" >/dev/null
for i in $(seq 1 60); do
  docker logs "$name" 2>&1 | grep -q 'Server ready' && break
  sleep 1
done
docker logs "$name" 2>&1 | grep -q 'Server ready' || { echo "FAIL: server never became ready"; docker logs "$name" 2>&1 | tail -20; exit 1; }

echo "Testing the web UI and driver port answer from outside the container..."
web=$(docker port "$name" 8080/tcp | head -1)
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://$web/")
[ "$code" = "200" ] || { echo "FAIL: web UI on $web returned $code"; exit 1; }
drv=$(docker port "$name" 28015/tcp | head -1)
(exec 3<>"/dev/tcp/${drv%:*}/${drv##*:}") 2>/dev/null || { echo "FAIL: driver port $drv not accepting connections"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell and no package manager..."
for f in /bin/sh /sbin/apk; do
  docker run --rm --entrypoint "$f" "$IMAGE" --version >/dev/null 2>&1 \
    && { echo "FAIL: $f present in prod"; exit 1; }
done
echo "None present (as expected)"

echo "All rethinkdb tests passed!"
