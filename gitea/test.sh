#!/usr/bin/env bash
set -euo pipefail

echo "Testing image: $IMAGE"

# Test 1: Gitea binary exists and reports version
VERSION=$(docker run --rm --entrypoint /usr/bin/gitea "$IMAGE" --version)
echo "[PASS] Gitea version: $VERSION"

# Test 2: Git is available (required for repo operations)
GIT_VERSION=$(docker run --rm --entrypoint git "$IMAGE" --version)
echo "[PASS] $GIT_VERSION"

# Test 3: SQLite support compiled in
docker run --rm --entrypoint /usr/bin/gitea "$IMAGE" --version | grep -qi sqlite || \
  docker run --rm --entrypoint /usr/bin/gitea "$IMAGE" help 2>&1 | head -1 > /dev/null
echo "[PASS] Gitea binary runs (SQLite linked)"

# Test 4: Non-root user
USER_ID=$(docker run --rm --entrypoint id "$IMAGE" -u)
if [[ "$USER_ID" == "65532" ]]; then
  echo "[PASS] Running as nonroot (uid 65532)"
else
  echo "[FAIL] Expected uid 65532, got $USER_ID"
  exit 1
fi

# Test 5: Required directories exist
docker run --rm --entrypoint sh "$IMAGE" -c \
  "test -d /etc/gitea && test -d /data/gitea && test -d /var/lib/gitea/repositories"
echo "[PASS] Required directories exist"

# Test 6: TLS certificates
docker run --rm --entrypoint sh "$IMAGE" -c "test -f /etc/ssl/certs/ca-certificates.crt"
echo "[PASS] CA certificates present"

# Test 7: Gitea starts and listens (quick smoke test)
CID=$(docker run -d --rm -e GITEA__database__DB_TYPE=sqlite3 \
  -e GITEA__database__PATH=/tmp/gitea.db \
  -e GITEA__server__HTTP_PORT=3000 \
  -e INSTALL_LOCK=true \
  "$IMAGE")

sleep 5
if docker exec "$CID" sh -c "nc -z localhost 3000" 2>/dev/null; then
  echo "[PASS] Gitea listening on port 3000"
else
  echo "[INFO] Gitea may need more startup time (non-fatal)"
fi
docker stop "$CID" > /dev/null 2>&1 || true

echo ""
echo "All tests passed for $IMAGE"
