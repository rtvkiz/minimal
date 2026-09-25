#!/bin/bash
# Smoke test for minimal-zot-dev.
# Same functional checks as prod, PLUS: a shell IS present, and the registry
# debugging tools (curl/jq) are available.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing zot version..."
ver=$(docker run --rm --entrypoint /usr/bin/zot "$IMAGE" --version 2>&1)
echo "$ver" | grep -qE '"distribution-spec":"1\.' \
  || { echo "FAIL: version line missing distribution-spec: $ver"; exit 1; }

work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/data"; chmod 0777 "$work/data"
cat > "$work/config.json" <<'JSON'
{
  "distSpecVersion": "1.1.1",
  "storage": { "rootDirectory": "/var/lib/registry" },
  "http": { "address": "0.0.0.0", "port": "5000" },
  "log": { "level": "info" }
}
JSON
chmod 0644 "$work/config.json"

echo "Testing config validation (offline)..."
docker run --rm -v "$work/config.json:/etc/zot/config.json:ro" \
  --entrypoint /usr/bin/zot "$IMAGE" verify /etc/zot/config.json 2>&1 \
  | grep -qi 'config file is valid' \
  || { echo "FAIL: zot verify did not accept a valid config"; exit 1; }

echo "Testing registry serves the OCI distribution API..."
cid=$(docker run -d -p 15501:5000 \
        -v "$work/config.json:/etc/zot/config.json:ro" \
        -v "$work/data:/var/lib/registry" "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true; rm -rf "$work"' EXIT
ok=0
for _ in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:15501/v2/" 2>/dev/null || true)
  if [ "$code" = "200" ]; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: /v2/ did not return 200"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Catalog round-trip using the image's own curl+jq (no host tooling needed)..."
repos=$(docker run --rm --network "container:$cid" --entrypoint /bin/sh "$IMAGE" -c \
          'curl -sf http://127.0.0.1:5000/v2/_catalog | jq -c .repositories' 2>/dev/null || true)
[ -n "$repos" ] \
  && echo "_catalog -> $repos (fetched via in-image curl+jq)" \
  || { echo "FAIL: in-image curl+jq round-trip returned nothing"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Verifying shell IS present (dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-ok' 2>/dev/null | grep -q shell-ok \
  || { echo "FAIL: no shell in dev image"; exit 1; }

echo "Verifying curl and jq are present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v curl && command -v jq' >/dev/null 2>&1 \
  || { echo "FAIL: curl/jq missing from dev image"; exit 1; }

echo "All zot dev tests passed!"
