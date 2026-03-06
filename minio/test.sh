#!/bin/bash
set -euo pipefail

echo "Testing MinIO version..."
docker run --rm --entrypoint /usr/bin/minio "$IMAGE" --version

echo "Testing MinIO server starts..."
docker run -d --name minio-test \
  -e MINIO_ROOT_USER=minioadmin \
  -e MINIO_ROOT_PASSWORD=minioadmin123 \
  -p 9000:9000 \
  -p 9001:9001 \
  "$IMAGE"
sleep 5

if docker ps | grep -q minio-test; then
  echo "MinIO container is running"
  docker logs minio-test

  # Health check via S3 API liveness endpoint
  echo "Checking S3 API health at :9000..."
  if curl -sf --retry 5 --retry-delay 2 http://localhost:9000/minio/health/live; then
    echo "MinIO S3 API health check passed"
  else
    echo "FAIL: MinIO S3 API health check failed"
    docker logs minio-test
    docker stop minio-test && docker rm minio-test
    exit 1
  fi

  docker stop minio-test && docker rm minio-test
else
  echo "MinIO failed to start, checking logs..."
  docker logs minio-test 2>&1 || true
  docker rm minio-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All MinIO tests passed!"
