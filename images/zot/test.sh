#!/bin/bash
# Smoke test for minimal-zot (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing zot version..."
# zot logs its version as a JSON line on stderr, not a bare string.
ver=$(docker run --rm --entrypoint /usr/bin/zot "$IMAGE" --version 2>&1)
echo "$ver" | grep -qE '"distribution-spec":"1\.' \
  || { echo "FAIL: version line missing distribution-spec: $ver"; exit 1; }

echo "Testing zot subcommands load..."
help=$(docker run --rm --entrypoint /usr/bin/zot "$IMAGE" --help 2>&1)
echo "$help" | grep -q 'serve' || { echo "FAIL: 'serve' subcommand missing"; exit 1; }
echo "$help" | grep -q 'verify' || { echo "FAIL: 'verify' subcommand missing"; exit 1; }

echo "Testing zli client is present..."
zli=$(docker run --rm --entrypoint /usr/bin/zli "$IMAGE" --help 2>&1)
echo "$zli" | grep -qi 'config' || { echo "FAIL: zli did not run"; exit 1; }

# Shared workspace: uid 65532 must be able to write, so 0777 (see onboarding §5).
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
# `verify` parses and validates the config without opening a socket — this is the
# offline functional check that proves the binary actually does its job.
docker run --rm -v "$work/config.json:/etc/zot/config.json:ro" \
  --entrypoint /usr/bin/zot "$IMAGE" verify /etc/zot/config.json 2>&1 \
  | grep -qi 'config file is valid' \
  || { echo "FAIL: zot verify did not accept a valid config"; exit 1; }

echo "Testing zot rejects a bad config (offline)..."
echo '{"storage":{}}' > "$work/bad.json"; chmod 0644 "$work/bad.json"
if docker run --rm -v "$work/bad.json:/etc/zot/bad.json:ro" \
     --entrypoint /usr/bin/zot "$IMAGE" verify /etc/zot/bad.json >/dev/null 2>&1; then
  echo "FAIL: zot verify accepted an invalid config"; exit 1
fi
echo "Invalid config rejected (as expected)"

echo "Testing registry serves the OCI distribution API..."
cid=$(docker run -d -p 15500:5000 \
        -v "$work/config.json:/etc/zot/config.json:ro" \
        -v "$work/data:/var/lib/registry" "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true; rm -rf "$work"' EXIT
ok=0
for _ in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:15500/v2/" 2>/dev/null || true)
  if [ "$code" = "200" ]; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: /v2/ did not return 200"; docker logs "$cid" 2>&1 | tail -20; exit 1; }

echo "Testing the catalog endpoint returns JSON..."
cat=$(curl -sf "http://127.0.0.1:15500/v2/_catalog" 2>/dev/null || true)
echo "$cat" | grep -q 'repositories' \
  || { echo "FAIL: _catalog did not return a repositories list, got: $cat"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All zot tests passed!"
