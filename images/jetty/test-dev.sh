#!/bin/bash
# Smoke test for minimal-jetty-dev.
# Same entrypoint as prod (deploys and serves a webapp), PLUS: shell, apk, curl.
set -eu
: "${IMAGE:?IMAGE env var required}"

port=18091
name="jetty-dev-smoke-$$"
work=$(mktemp -d)
trap 'docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$work"' EXIT

echo "Testing Jetty serves a mounted webapp..."
mkdir -p "$work/ROOT"; echo "jetty-dev-ok" > "$work/ROOT/index.html"; chmod -R a+rX "$work"
docker run -d --name "$name" -p "127.0.0.1:${port}:8080" -v "$work/ROOT:/var/lib/jetty/webapps/ROOT:ro" "$IMAGE" >/dev/null
out=""
for _ in $(seq 1 40); do out=$(curl -sf "http://127.0.0.1:${port}/" 2>/dev/null) && break; sleep 1; done
[ "$out" = "jetty-dev-ok" ] || { echo "FAIL: GET / returned '${out:-<none>}'"; docker logs "$name" 2>&1 | tail -20; exit 1; }

echo "Verifying shell, apk and curl present (dev only)..."
tools=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c 'apk --version; curl --version | head -1' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All jetty-dev tests passed!"
