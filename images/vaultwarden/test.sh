#!/bin/bash
set -euo pipefail

cleanup() { docker rm -f vaultwarden-test >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Testing Vaultwarden version..."
docker run --rm --entrypoint /usr/bin/vaultwarden "$IMAGE" --version

echo "Testing the web vault assets are bundled..."
# vaultwarden --version prints the web vault version it resolved from
# WEB_VAULT_FOLDER, so this proves the server can actually locate the assets —
# strictly stronger than checking a file exists on disk.
#
# The previous check piped `docker export` into `tar -t | grep -q`. grep -q
# exits on first match, tar takes SIGPIPE and returns non-zero, and pipefail
# then failed the test on an image that was completely fine.
ver=$(docker run --rm --entrypoint /usr/bin/vaultwarden "$IMAGE" --version)
echo "$ver" | grep -q "Web-Vault" \
  || { echo "vaultwarden could not resolve the bundled web vault"; echo "$ver"; exit 1; }

echo "Testing Vaultwarden starts and serves its API..."
docker run -d --name vaultwarden-test "$IMAGE" >/dev/null

ready=0
for _ in $(seq 1 30); do
  sleep 2
  docker ps --format '{{.Names}}' | grep -q '^vaultwarden-test$' || break
  IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' vaultwarden-test)
  # /alive is Vaultwarden's liveness endpoint; it returns a JSON timestamp.
  if curl -sf "http://${IP}:8080/alive" >/dev/null 2>&1; then ready=1; break; fi
done

if [ "$ready" -ne 1 ]; then
  echo "Vaultwarden did not become ready"
  docker logs vaultwarden-test 2>&1 | tail -30 || true
  exit 1
fi

IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' vaultwarden-test)
# The web vault is served at /, so a 200 here proves the bundled assets are
# wired up, not merely present on disk.
# Capture before matching: `curl | grep -q` makes grep exit at the first match,
# curl takes SIGPIPE, and pipefail then fails the test on a working server.
body=$(curl -sf "http://${IP}:8080/")
echo "$body" | grep -qi "<html" \
  || { echo "web vault not served at /"; docker logs vaultwarden-test 2>&1 | tail -20; exit 1; }

# SQLite is compiled in; a fresh start must create the database rather than
# fail on a missing backend (upstream's default features enable none). A
# reachable /alive already proves that — the server exits at startup if it has
# no usable database — so assert on the specific failure rather than grepping
# the log for "error", which matches benign lines and fails at random.
logs=$(docker logs vaultwarden-test 2>&1)
if echo "$logs" | grep -qiE "no database backend|error connecting to|migration.*failed"; then
  echo "database backend problem at startup:"; echo "$logs" | tail -20; exit 1
fi

echo "✓ All Vaultwarden tests passed"
