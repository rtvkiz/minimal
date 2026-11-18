#!/bin/bash
# Smoke test for minimal-jetty (prod).
# Deploys an exploded webapp from a mounted directory and fetches it over HTTP.
set -eu
: "${IMAGE:?IMAGE env var required}"

EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')
port=18090
name="jetty-smoke-$$"
work=$(mktemp -d)
trap 'docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$work"' EXIT

echo "Testing the Java runtime..."
jv=$(docker run --rm --entrypoint /usr/lib/jvm/java-25-openjdk/bin/java "$IMAGE" -version 2>&1)
echo "$jv" | grep -qE 'version "25\.' || { echo "FAIL: expected OpenJDK 25: $jv"; exit 1; }

echo "Testing Jetty deploys a webapp and serves it..."
mkdir -p "$work/ROOT"
echo "jetty-static-ok" > "$work/ROOT/index.html"
chmod -R a+rX "$work"
docker run -d --name "$name" -p "127.0.0.1:${port}:8080" \
  -v "$work/ROOT:/var/lib/jetty/webapps/ROOT:ro" "$IMAGE" >/dev/null
out=""
for _ in $(seq 1 40); do
  out=$(curl -sf "http://127.0.0.1:${port}/" 2>/dev/null) && break
  [ -n "$(docker ps -q --filter name="$name")" ] || break
  sleep 1
done
[ "$out" = "jetty-static-ok" ] || { echo "FAIL: GET / returned '${out:-<none>}'"; docker logs "$name" 2>&1 | tail -20; exit 1; }

echo "Testing the server is Jetty $EXPECTED..."
logs=$(docker logs "$name" 2>&1)
echo "$logs" | grep -q "jetty-${EXPECTED};" || { echo "FAIL: startup log does not report jetty-${EXPECTED}"; echo "$logs" | head -5; exit 1; }
echo "$logs" | grep -q 'WebAppContext.*{ROOT,/' || { echo "FAIL: ROOT webapp was not deployed through ee10"; exit 1; }
echo "$logs" | grep -qE 'WARN|ERROR' && { echo "FAIL: warnings at startup:"; echo "$logs" | grep -E 'WARN|ERROR'; exit 1; }
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}/missing")
[ "$code" = 404 ] || { echo "FAIL: missing path returned $code, expected 404"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" >/dev/null 2>&1 \
  && { echo "FAIL: shell found"; exit 1; } || echo "No shell (as expected)"
docker run --rm --entrypoint /sbin/apk "$IMAGE" --version >/dev/null 2>&1 \
  && { echo "FAIL: apk found"; exit 1; } || echo "No apk (as expected)"

echo "All jetty tests passed!"
