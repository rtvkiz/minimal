#!/bin/bash
set -euo pipefail

echo "Testing OpenSearch starts and becomes ready..."
docker run -d --name opensearch-test \
  -e OPENSEARCH_JAVA_OPTS="-Xms512m -Xmx512m" \
  -e DISABLE_SECURITY_PLUGIN="true" \
  -e DISABLE_INSTALL_DEMO_CONFIG="true" \
  -p 9200:9200 \
  "$IMAGE"

echo "Waiting for OpenSearch to be ready (up to 60s)..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:9200/ >/dev/null 2>&1; then
    echo "OpenSearch is ready (attempt $i)"
    break
  fi
  if [ "$i" = "30" ]; then
    echo "FAIL: OpenSearch did not become ready in time"
    docker logs opensearch-test
    docker stop opensearch-test && docker rm opensearch-test
    exit 1
  fi
  sleep 2
done

echo "Checking cluster health..."
HEALTH=$(curl -sf http://localhost:9200/_cluster/health | python3 -c "import sys,json; h=json.load(sys.stdin); print(h['status'])")
echo "Cluster health: $HEALTH"
if [ "$HEALTH" != "green" ] && [ "$HEALTH" != "yellow" ]; then
  echo "FAIL: Unexpected cluster health: $HEALTH"
  docker logs opensearch-test
  docker stop opensearch-test && docker rm opensearch-test
  exit 1
fi

echo "Checking OpenSearch version..."
VERSION=$(curl -sf http://localhost:9200/ | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['version']['number'])")
echo "OpenSearch version: $VERSION"

docker stop opensearch-test && docker rm opensearch-test
echo "All OpenSearch tests passed!"
