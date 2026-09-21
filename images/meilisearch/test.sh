#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"

# Expected version comes from melange.yaml, never a literal. A hardcoded
# version turns every auto-bump PR red on its own smoke test while the build
# itself is fine — which is exactly what happened to the meilisearch 1.54.0
# bump (#744): both melange arches built, then prod and dev failed the version
# grep. Reading the recipe asserts the real invariant (the image ships what the
# recipe pins) and survives bumps untouched.
EXPECTED=$(grep -m1 '^  version:' "$(dirname "$0")/melange.yaml" | awk '{print $2}')
if [ -z "$EXPECTED" ]; then
  echo "FAIL: could not read version from melange.yaml"
  exit 1
fi

container="minimal-meilisearch-test-$$"
cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Testing Meilisearch version..."
version=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$version" | grep -q "$EXPECTED" || { echo "Unexpected version: $version"; exit 1; }

echo "Testing Meilisearch help..."
help=$(docker run --rm "$IMAGE" --help 2>&1)
echo "$help" | grep -q -- "--db-path" || { echo "Meilisearch help did not load"; exit 1; }

echo "Testing document indexing and search round trip..."
docker run -d --name "$container" "$IMAGE" >/dev/null
ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container")

ready=false
for _ in $(seq 1 30); do
  if curl -fsS "http://${ip}:7700/health" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done
[ "$ready" = true ] || { docker logs "$container"; echo "Meilisearch did not become healthy"; exit 1; }

task=$(curl -fsS -X POST "http://${ip}:7700/indexes/books/documents?primaryKey=id" \
  -H 'Content-Type: application/json' \
  --data '[{"id":1,"title":"Dune"},{"id":2,"title":"The Left Hand of Darkness"}]')
uid=$(printf '%s' "$task" | jq -r '.taskUid')
[ "$uid" != null ] || { echo "Document task was not accepted: $task"; exit 1; }

succeeded=false
for _ in $(seq 1 30); do
  status=$(curl -fsS "http://${ip}:7700/tasks/${uid}")
  if printf '%s' "$status" | grep -q '"status":"succeeded"'; then
    succeeded=true
    break
  fi
  if printf '%s' "$status" | grep -q '"status":"failed"'; then
    echo "Indexing failed: $status"
    exit 1
  fi
  sleep 1
done
[ "$succeeded" = true ] || { echo "Indexing did not finish"; exit 1; }

result=$(curl -fsS "http://${ip}:7700/indexes/books/search?q=dun")
printf '%s' "$result" | grep -q '"title":"Dune"' || { echo "Unexpected search result: $result"; exit 1; }

echo "Verifying production image has no shell..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo shell-found' >/dev/null 2>&1; then
  echo "FAIL: production image contains /bin/sh"
  exit 1
fi

echo "All Meilisearch tests passed!"
