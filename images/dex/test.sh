#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing dex version..."
docker run --rm --entrypoint /usr/bin/dex "$IMAGE" version 2>&1 | grep -qiE 'Dex Version: 2\.[0-9]+'

echo "Testing dex rejects a missing config (serve path wired)..."
# The default entrypoint points at /etc/dex/config.yaml, which the image
# deliberately does not ship. dex must fail loudly rather than start with an
# empty configuration.
docker run --rm "$IMAGE" 2>&1 | grep -qiE 'no such file|failed to (open|read|load)|config' \
  && echo "dex missing-config handling OK"

echo "Testing dex serves OIDC discovery with a real config..."
# Full round-trip on the in-memory storage backend: dex boots, opens its web
# listener, and serves the OIDC discovery document. Exercises config parsing,
# storage init and the HTTP server without any upstream connector or database.
CFG=$(mktemp -d)
cat > "$CFG/config.yaml" <<'YAML'
issuer: http://127.0.0.1:5556/dex
storage:
  type: memory
web:
  http: 0.0.0.0:5556
staticClients:
  - id: smoke
    name: smoke
    secret: smoke-secret
    redirectURIs:
      - http://127.0.0.1/callback
enablePasswordDB: true
YAML
chmod 0644 "$CFG/config.yaml"

CID=$(docker run -d --rm -p 15556:5556 -v "$CFG/config.yaml:/etc/dex/config.yaml:ro" "$IMAGE")
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true; rm -rf "$CFG"' EXIT

ok=""
for _ in $(seq 1 30); do
  if curl -fsS --max-time 3 http://127.0.0.1:15556/dex/.well-known/openid-configuration 2>/dev/null \
       | grep -q '"issuer"'; then ok=1; break; fi
  sleep 1
done
[ -n "$ok" ] || { echo "FAIL: dex did not serve OIDC discovery"; docker logs "$CID" 2>&1 | tail -20; exit 1; }
echo "dex OIDC discovery OK"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All dex tests passed!"
