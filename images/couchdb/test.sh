#!/bin/bash
# Smoke test for minimal-couchdb (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing couchdb version..."
# /usr/bin/couchdb has no CLI version/help flag — it always execs erlexec and
# boots the full server, so read the release metadata file directly instead.
v=$(docker run --rm --entrypoint /bin/cat "$IMAGE" /usr/share/couchdb/releases/start_erl.data 2>&1)
echo "$v" | grep -qE '3\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected release data: $v"; exit 1; }

echo "Testing couchdb boots with a mounted admin config and answers HTTP (offline)..."
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

port=15984
cid=$(docker run -d -p "127.0.0.1:${port}:5984" \
        -v "$conf/local.ini:/usr/share/couchdb/etc/local.ini" "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true; rm -rf "$conf"' EXIT

ok=0
for _ in $(seq 1 20); do
  root=$(curl -sf -u admin:testpass123 "http://127.0.0.1:${port}/" 2>/dev/null || true)
  if echo "$root" | grep -q '"couchdb":"Welcome"'; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: couchdb did not answer on :5984"; docker logs "$cid" 2>&1 | tail -30; exit 1; }

echo "Testing a create/read round-trip (offline, local data only)..."
put=$(curl -sf -u admin:testpass123 -X PUT "http://127.0.0.1:${port}/smoke-test")
echo "$put" | grep -q '"ok":true' || { echo "FAIL: PUT database failed: $put"; exit 1; }
get=$(curl -sf -u admin:testpass123 "http://127.0.0.1:${port}/smoke-test")
echo "$get" | grep -q '"db_name":"smoke-test"' || { echo "FAIL: GET database failed: $get"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying shell is busybox only (couchdb's launcher-script exception, no bash/apk)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo shell-ok" 2>&1 | grep -q 'shell-ok' \
  || { echo "FAIL: expected busybox /bin/sh to be present"; exit 1; }
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo x" >/dev/null 2>&1 \
  && { echo "FAIL: bash found — restraint guard violated"; exit 1; } \
  || echo "No bash (as expected)"
docker run --rm --entrypoint /sbin/apk "$IMAGE" --version >/dev/null 2>&1 \
  && { echo "FAIL: apk found — restraint guard violated"; exit 1; } \
  || echo "No apk (as expected)"

echo "All couchdb tests passed!"
