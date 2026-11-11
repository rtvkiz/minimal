#!/bin/bash
# Smoke test for minimal-couchdb-dev.
# Same functional checks as prod, PLUS: bash/curl/jq are available.
set -eu
: "${IMAGE:?IMAGE env var required}"

# Version is asserted from the welcome response below, not releases/start_erl.data
# (Wolfi's couchdb-3.5 build leaves the release vsn empty there).
echo "Testing couchdb boots and jq can parse its welcome response (offline)..."
conf=$(mktemp -d); chmod 0777 "$conf"
cat > "$conf/local.ini" <<'INI'
[couchdb]
database_dir = /data
view_index_dir = /data

[admins]
admin = testpass123

[chttpd]
bind_address = 0.0.0.0
INI
chmod 0644 "$conf/local.ini"

cid=$(docker run -d -v "$conf/local.ini:/usr/share/couchdb/etc/local.ini" "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true; rm -rf "$conf"' EXIT

ok=0
for _ in $(seq 1 20); do
  if docker exec "$cid" curl -sf -u admin:testpass123 http://127.0.0.1:5984/ >/dev/null 2>&1; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: couchdb did not answer on :5984"; docker logs "$cid" 2>&1 | tail -30; exit 1; }

root=$(docker exec "$cid" curl -sf -u admin:testpass123 http://127.0.0.1:5984/)
vendor=$(docker exec "$cid" sh -c "echo '$root' | jq -r '.vendor.name'")
echo "$vendor" | grep -qi 'apache' || { echo "FAIL: unexpected vendor via jq: $vendor"; exit 1; }
version=$(docker exec "$cid" sh -c "echo '$root' | jq -r '.version'")
echo "$version" | grep -qE '^3\.[0-9]+\.[0-9]+$' || { echo "FAIL: unexpected version via jq: $version"; exit 1; }
echo "couchdb $version"

echo "Verifying bash present (dev only)..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo x" 2>&1 | grep -q x \
  || { echo "FAIL: expected bash in dev variant"; exit 1; }

echo "All couchdb-dev tests passed!"
