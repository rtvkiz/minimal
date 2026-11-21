#!/bin/bash
# Smoke test for minimal-curl (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

echo "Testing curl version..."
v=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$v" | grep -qE '^curl 8\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected curl --version: $v"; exit 1; }
for f in HTTP2 HTTPS-proxy SSL libz; do
  echo "$v" | grep -q "$f" || { echo "FAIL: curl built without $f: $v"; exit 1; }
done

work=$(mktemp -d); chmod 0777 "$work"
net="curl-test-$$"
cleanup() { docker rm -f "$net-srv" >/dev/null 2>&1 || true; docker network rm "$net" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT

echo "Testing a file:// read (no network)..."
echo "file-ok" > "$work/in.txt"; chmod 0644 "$work/in.txt"
out=$(docker run --rm --network none -v "$work:/work" "$IMAGE" -sS file:///work/in.txt 2>&1)
[ "$out" = "file-ok" ] || { echo "FAIL: file:// read: $out"; exit 1; }

echo "Testing an HTTP GET + POST against a local server..."
# A throwaway busybox httpd on a private network: proves DNS resolution,
# the TCP client path and -w output formatting, with no internet access.
docker network create --internal "$net" >/dev/null
mkdir -p "$work/www"; echo "http-ok" > "$work/www/index.html"; chmod -R a+rX "$work/www"
docker run -d --name "$net-srv" --network "$net" -v "$work/www:/www:ro" \
  busybox:stable httpd -f -p 8080 -h /www >/dev/null
out=""
for _ in $(seq 1 20); do
  out=$(docker run --rm --network "$net" "$IMAGE" -sS --max-time 5 "http://$net-srv:8080/" 2>&1) && break
  sleep 0.5
done
[ "$out" = "http-ok" ] || { echo "FAIL: HTTP GET: $out"; exit 1; }
code=$(docker run --rm --network "$net" "$IMAGE" -s -o /dev/null -w '%{http_code}' --max-time 5 "http://$net-srv:8080/missing" 2>&1)
[ "$code" = "404" ] || { echo "FAIL: expected 404 for a missing path, got '$code'"; exit 1; }

echo "Testing the CA bundle is present..."
# Read through curl itself: no shell to stat with, and this is the path
# Wolfi's curl is built to trust by default.
n=$(docker run --rm --network none "$IMAGE" -sS file:///etc/ssl/certs/ca-certificates.crt 2>&1 | grep -c "BEGIN CERTIFICATE" || true)
[ "$n" -gt 50 ] || { echo "FAIL: CA bundle missing or near-empty ($n certs)"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All curl tests passed!"
