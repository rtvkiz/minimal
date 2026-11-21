#!/bin/bash
# Smoke test for minimal-ollama (prod).
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

name="ollama-test-$$"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "Testing ollama client version..."
v=$(docker run --rm --network none "$IMAGE" --version 2>&1 || true)
echo "$v" | grep -qE 'client version is [0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: unexpected ollama --version: $v"; exit 1; }
want=$(echo "$v" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

echo "Starting ollama serve (default CMD, no network)..."
docker run -d --name "$name" --network none "$IMAGE" >/dev/null
ready=""
for _ in $(seq 1 30); do
  docker logs "$name" 2>&1 | grep -q "Listening on" && { ready=1; break; }
  sleep 1
done
[ -n "$ready" ] || { echo "FAIL: server never listened"; docker logs "$name" 2>&1 | tail -20; exit 1; }

echo "Testing it listens on all interfaces (OLLAMA_HOST), as upstream's image does..."
docker logs "$name" 2>&1 | grep -qE 'Listening on (\[::\]|0\.0\.0\.0):11434' \
  || { echo "FAIL: not listening on 0.0.0.0:11434"; docker logs "$name" 2>&1 | tail -5; exit 1; }

echo "Testing the llama.cpp CPU backend was discovered..."
# Without ollama-cpu the server still starts, but reports no compute and
# cannot load any model - this is the line that proves inference is possible.
for _ in $(seq 1 15); do docker logs "$name" 2>&1 | grep -q 'inference compute' && break; sleep 1; done
docker logs "$name" 2>&1 | grep 'inference compute' | grep -q 'library=cpu' \
  || { echo "FAIL: no CPU inference backend"; docker logs "$name" 2>&1 | tail -10; exit 1; }

echo "Testing a client -> server round trip (ollama list, server version)..."
out=$(docker exec "$name" ollama list 2>&1)
echo "$out" | grep -q '^NAME' || { echo "FAIL: ollama list: $out"; exit 1; }
sv=$(docker exec "$name" ollama --version 2>&1)
echo "$sv" | grep -q "ollama version is $want" || { echo "FAIL: server version mismatch: $sv"; exit 1; }

echo "Testing the model store is writable by nonroot..."
# On first start the server writes its identity key and creates models/blobs
# under $HOME/.ollama; read them back with docker cp (no shell to stat with).
listing=$(docker cp "$name:/home/nonroot/.ollama" - 2>/dev/null | tar t)
for p in .ollama/id_ed25519.pub .ollama/models/blobs/; do
  echo "$listing" | grep -qxF "$p" || { echo "FAIL: server did not create $p (store not writable?)"; echo "$listing"; exit 1; }
done

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } \
  || echo "No shell (as expected)"

echo "All ollama tests passed!"
