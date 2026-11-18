#!/bin/bash
# Smoke test for minimal-tomee-dev.
# Same entrypoint as prod (serves a compiled JSP), PLUS: shell, apk, curl.
set -eu
: "${IMAGE:?IMAGE env var required}"

port=18096
name="tomee-dev-smoke-$$"
work=$(mktemp -d)
trap 'docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$work"' EXIT

echo "Testing TomEE serves a compiled JSP..."
mkdir -p "$work/ROOT"
printf '%s\n' '<%= "tomee-dev-ok" %>' > "$work/ROOT/index.jsp"; chmod -R a+rX "$work"
docker run -d --name "$name" -p "127.0.0.1:${port}:8080" -v "$work/ROOT:/opt/tomee/webapps/ROOT:ro" "$IMAGE" >/dev/null
out=""
for _ in $(seq 1 60); do out=$(curl -sf "http://127.0.0.1:${port}/" 2>/dev/null) && break; sleep 1; done
echo "$out" | grep -q 'tomee-dev-ok' || { echo "FAIL: GET / returned '${out:-<none>}'"; docker logs "$name" 2>&1 | tail -20; exit 1; }

echo "Verifying shell, apk and curl present (dev only)..."
tools=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c 'apk --version; curl --version | head -1' 2>&1) \
  || { echo "FAIL: dev tooling missing: $tools"; exit 1; }
echo "$tools"

echo "All tomee-dev tests passed!"
