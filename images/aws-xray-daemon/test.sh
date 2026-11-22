#!/bin/bash
# Smoke test for minimal-aws-xray-daemon (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

net="xray-test-$$"
cleanup() { docker rm -f "$net-d" >/dev/null 2>&1 || true; docker network rm "$net" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Testing xray version..."
v=$(docker run --rm --network none --entrypoint /xray "$IMAGE" --version 2>&1 || true)
echo "$v" | grep -qE '^AWS X-Ray daemon version: [0-9]+\.[0-9]+\.[0-9]+$' || { echo "FAIL: unexpected --version: $v"; exit 1; }
echo "$v" | grep -q 'unknown' && { echo "FAIL: version not injected"; exit 1; } || true

echo "Testing the upstream entrypoint and default listen flags..."
ep=$(docker inspect --format '{{json .Config.Entrypoint}}' "$IMAGE")
[ "$ep" = '["/xray","-t","0.0.0.0:2000","-b","0.0.0.0:2000"]' ] || { echo "FAIL: entrypoint is $ep"; exit 1; }

echo "Starting the daemon in local mode (no EC2 metadata) on a private network..."
docker network create --internal "$net" >/dev/null
docker run -d --name "$net-d" --network "$net" "$IMAGE" -o -n us-east-1 -l dev >/dev/null
for _ in $(seq 1 20); do docker logs "$net-d" 2>&1 | grep -q 'Starting proxy http server on 0.0.0.0:2000' && break; sleep 0.5; done
docker logs "$net-d" 2>&1 | grep -q 'Initializing AWS X-Ray daemon' || { echo "FAIL: daemon did not start"; docker logs "$net-d" 2>&1 | tail -10; exit 1; }
docker logs "$net-d" 2>&1 | grep -q 'Starting proxy http server on 0.0.0.0:2000' || { echo "FAIL: TCP proxy not listening"; docker logs "$net-d" 2>&1 | tail -10; exit 1; }

echo "Testing a trace segment sent over UDP is received and batched..."
# The X-Ray SDK wire format: a JSON header line, then the segment document.
docker run --rm --network "$net" busybox:stable sh -c "printf '{\"format\":\"json\",\"version\":1}\n{\"trace_id\":\"1-581cf771-a006649127e371903a2de979\",\"id\":\"70de5b6f19ff9a0a\",\"start_time\":1478293361.271,\"end_time\":1478293361.449,\"name\":\"smoke\"}' | nc -u -w1 $net-d 2000"
ok=""
for _ in $(seq 1 20); do
  docker logs "$net-d" 2>&1 | grep -q 'segment batch size: 1' && { ok=1; break; }
  sleep 0.5
done
[ -n "$ok" ] || { echo "FAIL: segment never reached the batch processor"; docker logs "$net-d" 2>&1 | tail -10; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All aws-xray-daemon tests passed!"
