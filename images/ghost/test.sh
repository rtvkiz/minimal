#!/bin/bash
# Smoke test for minimal-ghost (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')

echo "Testing ghost version (expect $EXPECTED)..."
v=$(docker run --rm --network none --entrypoint /usr/bin/node "$IMAGE" -p "require('/usr/lib/ghost/package.json').version" 2>&1)
[ "$v" = "$EXPECTED" ] || { echo "FAIL: unexpected ghost version: $v"; exit 1; }

echo "Testing the runtime Node satisfies Ghost's engines.node..."
# This is the guard for bump-toolchain-pins.sh: if the nodejs-N pin moves to a
# line Ghost does not support, this fails, the probe fails, and the repair
# step holds the image on the last supported Node.
e=$(docker run --rm --network none --entrypoint /usr/bin/node "$IMAGE" -e "
  const semver = require('/usr/lib/ghost/node_modules/semver');
  const range = require('/usr/lib/ghost/package.json').engines.node;
  const ok = semver.satisfies(process.versions.node, range);
  console.log((ok ? 'ok' : 'UNSUPPORTED') + ' node ' + process.versions.node + ' vs ' + range);
  process.exit(ok ? 0 : 1);" 2>&1) || { echo "FAIL: $e"; exit 1; }
echo "  $e"

echo "Testing ghost boots on SQLite in a fresh content volume and serves HTTP..."
# A fresh named volume at the content path exercises the first-boot seeding
# (themes copied from content.orig) and the knex migrations into SQLite.
vol="minimal-ghost-smoke-$$"
docker volume create "$vol" >/dev/null
port=12368
cid=$(docker run -d -p "127.0.0.1:${port}:2368" \
        -e url="http://127.0.0.1:${port}" \
        -e privacy__useUpdateCheck=false -e privacy__useGravatar=false \
        -v "$vol:/var/lib/ghost/content" "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true; docker volume rm -f "$vol" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 90); do
  if curl -sf "http://127.0.0.1:${port}/ghost/api/admin/site/" >/dev/null 2>&1; then ok=1; break; fi
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "FAIL: ghost did not answer on :2368"; docker logs "$cid" 2>&1 | tail -40; exit 1; }

site=$(curl -sf "http://127.0.0.1:${port}/ghost/api/admin/site/")
echo "$site" | grep -q '"version"' || { echo "FAIL: admin site API: $site"; exit 1; }
home=$(curl -sf "http://127.0.0.1:${port}/")
echo "$home" | grep -qi '<html' || { echo "FAIL: front page did not render"; exit 1; }
echo "$home" | grep -q 'name="generator" content="Ghost' || { echo "FAIL: front page not rendered by Ghost"; exit 1; }
admin=$(curl -sf "http://127.0.0.1:${port}/ghost/")
echo "$admin" | grep -qi '<html' || { echo "FAIL: built admin not served"; exit 1; }

echo "Testing first-boot seeding populated the content volume..."
seed=$(docker run --rm --network none -v "$vol:/var/lib/ghost/content" --entrypoint /usr/bin/node "$IMAGE" -e "
  const fs = require('fs');
  const t = fs.readdirSync('/var/lib/ghost/content/themes');
  const db = fs.existsSync('/var/lib/ghost/content/data/ghost.db');
  console.log('themes=' + t.sort().join(',') + ' db=' + db);
  process.exit(t.includes('source') && t.includes('casper') && db ? 0 : 1);" 2>&1) \
  || { echo "FAIL: content volume not seeded: $seed"; exit 1; }
echo "  $seed"

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" >/dev/null 2>&1 \
  && { echo "FAIL: shell found"; exit 1; } || echo "No shell (as expected)"

echo "All ghost tests passed!"
