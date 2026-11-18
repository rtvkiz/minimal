#!/bin/bash
# Smoke test for minimal-tomee (prod).
# Deploys an exploded webapp with a JSP from a mounted directory: TomEE has to
# start, compile the JSP (Jasper, writable work/) and serve it over HTTP.
set -eu
: "${IMAGE:?IMAGE env var required}"

EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')
port=18095
name="tomee-smoke-$$"
work=$(mktemp -d)
trap 'docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$work"' EXIT

echo "Testing the Java runtime..."
jv=$(docker run --rm --entrypoint /usr/lib/jvm/java-25-openjdk/bin/java "$IMAGE" -version 2>&1)
echo "$jv" | grep -qE 'version "25\.' || { echo "FAIL: expected OpenJDK 25: $jv"; exit 1; }

echo "Testing TomEE deploys a webapp and serves a compiled JSP..."
mkdir -p "$work/ROOT"
printf '%s\n' '<%= "tomee-jsp-ok " + application.getServerInfo() %>' > "$work/ROOT/index.jsp"
chmod -R a+rX "$work"
docker run -d --name "$name" -p "127.0.0.1:${port}:8080" \
  -v "$work/ROOT:/opt/tomee/webapps/ROOT:ro" "$IMAGE" >/dev/null
out=""
for _ in $(seq 1 60); do
  out=$(curl -sf "http://127.0.0.1:${port}/" 2>/dev/null) && break
  [ -n "$(docker ps -q --filter name="$name")" ] || break
  sleep 1
done
echo "  $out"
echo "$out" | grep -q '^tomee-jsp-ok ' || { echo "FAIL: GET / returned '${out:-<none>}'"; docker logs "$name" 2>&1 | tail -20; exit 1; }

echo "Testing the server is TomEE $EXPECTED..."
echo "$out" | grep -q "(TomEE)/.* (${EXPECTED})" || { echo "FAIL: server info is not TomEE ${EXPECTED}: $out"; exit 1; }
logs=$(docker logs "$name" 2>&1)
echo "$logs" | grep -q 'Server startup in' || { echo "FAIL: no startup line in the log"; exit 1; }
echo "$logs" | grep -qE 'SEVERE|WARNING' && { echo "FAIL: warnings at startup:"; echo "$logs" | grep -E 'SEVERE|WARNING'; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" >/dev/null 2>&1 \
  && { echo "FAIL: shell found"; exit 1; } || echo "No shell (as expected)"
docker run --rm --entrypoint /sbin/apk "$IMAGE" --version >/dev/null 2>&1 \
  && { echo "FAIL: apk found"; exit 1; } || echo "No apk (as expected)"

echo "All tomee tests passed!"
