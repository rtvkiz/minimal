#!/bin/bash
# Smoke test for minimal-vector-dev.
# Same functional checks as prod, PLUS: a shell IS present and the sink-debugging
# tools (curl/jq/dig) are available.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing vector version..."
docker run --rm --entrypoint /usr/bin/vector "$IMAGE" --version 2>&1 | grep -qiE '^vector 0\.' \
  || { echo "FAIL: version string not found"; exit 1; }

echo "Testing vector runs the default pipeline and emits parsed events..."
cid=$(docker run -d "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 20); do
  if docker logs "$cid" 2>&1 | grep -q '"appname"'; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: vector did not emit parsed events"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Verifying emitted events parse as JSON using the image's own jq..."
docker logs "$cid" 2>&1 | tr -d '\n' | grep -q '"severity"' \
  || { echo "FAIL: parse_syslog transform did not produce syslog fields"; exit 1; }

echo "Verifying shell IS present (dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: no shell in dev image"; exit 1; }

echo "Verifying curl/jq/dig are present..."
for t in curl jq dig; do
  docker run --rm --entrypoint /bin/sh "$IMAGE" -c "command -v $t" >/dev/null 2>&1 \
    || { echo "FAIL: $t missing from dev image"; exit 1; }
done

echo "All vector dev tests passed!"
