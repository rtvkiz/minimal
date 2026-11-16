#!/bin/bash
# Smoke test for minimal-fluentd (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')

echo "Testing fluentd version (expect $EXPECTED)..."
v=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$v" | grep -qF "fluentd $EXPECTED" || { echo "FAIL: unexpected fluentd --version: $v"; exit 1; }

echo "Testing fluentd help..."
h=$(docker run --rm "$IMAGE" --help 2>&1)
echo "$h" | grep -q -- '--dry-run' || { echo "FAIL: unexpected fluentd --help: $h"; exit 1; }

echo "Testing the shipped default config parses (--dry-run)..."
d=$(docker run --rm --network none "$IMAGE" --dry-run 2>&1) || { echo "FAIL: --dry-run failed: $d"; exit 1; }
echo "$d" | grep -q 'finished dry run mode' || { echo "FAIL: dry run did not finish: $d"; exit 1; }

echo "Testing an event round-trip: fluent-cat -> forward input -> stdout (offline)..."
# Exercises the supervisor -> worker spawn (shell-less), the msgpack forward
# protocol over TCP and the cool.io event loop: the native extensions this
# image compiles.
cid=$(docker run -d --network none "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ready=0
for _ in $(seq 1 30); do
  if docker logs "$cid" 2>&1 | grep -q 'fluentd worker is now running'; then ready=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ready" = 1 ] || { echo "FAIL: fluentd worker did not start"; docker logs "$cid" 2>&1 | tail -30; exit 1; }
echo '{"smoke":"minimal-fluentd-roundtrip"}' | docker exec -i "$cid" /usr/bin/fluent-cat smoke.test \
  || { echo "FAIL: fluent-cat could not send"; docker logs "$cid" 2>&1 | tail -30; exit 1; }
seen=0
for _ in $(seq 1 15); do
  logs=$(docker logs "$cid" 2>&1)
  if echo "$logs" | grep -q 'smoke.test: {"smoke":"minimal-fluentd-roundtrip"}'; then seen=1; break; fi
  sleep 1
done
[ "$seen" = 1 ] || { echo "FAIL: event did not reach stdout"; docker logs "$cid" 2>&1 | tail -30; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1 \
  && { echo "FAIL: shell found"; exit 1; } || echo "No shell (as expected)"

echo "All fluentd tests passed!"
