#!/bin/bash
# Smoke test for minimal-configmap-reload (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"
# Webhook receiver for the end-to-end check: any image with Python works; ours
# avoids a Docker Hub pull (same approach as keycloak's postgres sidecar).
RCV_IMAGE="${CONFIGMAP_RELOAD_TEST_RCV_IMAGE:-ghcr.io/rtvkiz/minimal-python:latest}"

echo "Testing configmap-reload runs..."
help=$(docker run --rm "$IMAGE" --help 2>&1 || true)
echo "$help" | grep -q -- '-volume-dir' || { echo "FAIL: unexpected --help output: $help"; exit 1; }

echo "Testing the upstream /configmap-reload path..."
help2=$(docker run --rm --entrypoint /configmap-reload "$IMAGE" --help 2>&1 || true)
echo "$help2" | grep -q -- '-volume-dir' || { echo "FAIL: /configmap-reload does not run"; exit 1; }

# End to end: mimic the kubelet's atomic ConfigMap update (write a new ..<ts>
# dir, then rename a fresh ..data symlink over the old one). configmap-reload
# only fires on a Create of "..data", so this is the exact event it acts on.
work=$(mktemp -d); net="cmr-test-$$"
cleanup() {
  docker rm -f cmr-test cmr-rcv >/dev/null 2>&1 || true
  docker network rm "$net" >/dev/null 2>&1 || true
  rm -rf "$work"
}
cleanup; trap cleanup EXIT
mkdir -p "$work/..v1"; echo one > "$work/..v1/app.conf"; ln -s ..v1 "$work/..data"
chmod -R a+rX "$work"
docker network create "$net" >/dev/null

docker run -d --name cmr-rcv --network "$net" "$RCV_IMAGE" -u -c '
from http.server import BaseHTTPRequestHandler as B, HTTPServer as H
class R(B):
    def do_POST(s):
        print("HOOK", s.command, s.path, flush=True); s.send_response(200); s.end_headers()
    def log_message(s, *a): pass
H(("0.0.0.0", 9000), R).serve_forever()' >/dev/null

docker run -d --name cmr-test --network "$net" -v "$work:/config:ro" "$IMAGE" \
  --volume-dir=/config --webhook-url=http://cmr-rcv:9000/-/reload >/dev/null

ok=0
for _ in $(seq 1 30); do
  docker logs cmr-test 2>&1 | grep -q 'Watching directory' && { ok=1; break; }
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: configmap-reload did not start watching"; docker logs cmr-test 2>&1 | tail -10; exit 1; }

echo "Testing a ConfigMap swap fires the reload webhook..."
mkdir "$work/..v2"; echo two > "$work/..v2/app.conf"; chmod -R a+rX "$work/..v2"
ln -s ..v2 "$work/..data_tmp"; mv -fT "$work/..data_tmp" "$work/..data"
hit=0
for _ in $(seq 1 20); do
  docker logs cmr-rcv 2>&1 | grep -q 'HOOK POST /-/reload' && { hit=1; break; }
  sleep 1
done
[ "$hit" = 1 ] || { echo "FAIL: webhook never received"; docker logs cmr-test 2>&1 | tail -10; exit 1; }
docker logs cmr-test 2>&1 | grep -q 'successfully triggered reload' \
  || { echo "FAIL: configmap-reload did not record success"; docker logs cmr-test 2>&1 | tail -10; exit 1; }
echo "✓ swap detected, POST /-/reload delivered"

echo "Testing reload metrics on :9533..."
m=$(docker run --rm --network "$net" --entrypoint /usr/bin/python3 "$RCV_IMAGE" -c \
  'import urllib.request; print(urllib.request.urlopen("http://cmr-test:9533/metrics").read().decode())')
echo "$m" | grep -qE '^configmap_reload_success_reloads_total\{[^}]*\} 1' \
  || { echo "FAIL: success_reloads_total is not 1"; echo "$m" | grep configmap_reload; exit 1; }
echo "✓ configmap_reload_success_reloads_total 1"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All configmap-reload tests passed!"
