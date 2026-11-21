#!/bin/bash
# Smoke test for minimal-whoami (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

net="whoami-test-$$"
cleanup() { docker rm -f "$net-srv" >/dev/null 2>&1 || true; docker network rm "$net" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Testing whoami --help (flags load)..."
h=$(docker run --rm --network none "$IMAGE" --help 2>&1 || true)
echo "$h" | grep -q -- '-port' || { echo "FAIL: unexpected --help: $h"; exit 1; }
echo "$h" | grep -q 'default "8080"' || { echo "FAIL: default port is not 8080 (WHOAMI_PORT_NUMBER unset?)"; exit 1; }

echo "Starting whoami on a private network as nonroot..."
docker network create --internal "$net" >/dev/null
docker run -d --name "$net-srv" --network "$net" "$IMAGE" --name smoke >/dev/null
# busybox wget as the client: the image under test has no shell or HTTP client.
get() { docker run --rm --network "$net" busybox:stable wget -qO- --header "X-Smoke: abc123" "http://$net-srv:8080$1" 2>&1; }
out=""
for _ in $(seq 1 20); do out=$(get /) && break; sleep 0.5; done

echo "Testing / echoes the request back..."
echo "$out" | grep -q '^Name: smoke' || { echo "FAIL: --name not echoed: $out"; exit 1; }
echo "$out" | grep -q '^X-Smoke: abc123' || { echo "FAIL: request header not echoed: $out"; exit 1; }
echo "$out" | grep -qE '^GET / HTTP/1\.1' || { echo "FAIL: request line not echoed: $out"; exit 1; }

echo "Testing /api returns JSON..."
api=$(get /api)
echo "$api" | grep -q '"name":"smoke"' || { echo "FAIL: /api: $api"; exit 1; }

echo "Testing /health..."
docker run --rm --network "$net" busybox:stable wget -q --spider "http://$net-srv:8080/health" \
  || { echo "FAIL: /health not 200"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All whoami tests passed!"
