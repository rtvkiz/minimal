#!/bin/bash
# Smoke test for minimal-docker-dev: Docker-in-Docker.
# Starts dockerd in a --privileged container and checks it serves requests.
set -eu
: "${IMAGE:?IMAGE env var required}"

name="minimal-docker-dind-$$"
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT

echo "Starting dockerd (--privileged, TLS disabled for the test)..."
docker run -d --name "$name" --privileged -e DOCKER_TLS_CERTDIR= "$IMAGE" >/dev/null

echo "Waiting for the inner daemon..."
for i in $(seq 1 60); do
  if sv=$(docker exec "$name" docker version --format '{{.Server.Version}}' 2>/dev/null) && [ -n "$sv" ]; then
    break
  fi
  sleep 1
done
echo "$sv" | grep -qE '^[0-9]+\.[0-9]+' || { echo "FAIL: inner dockerd never came up"; docker logs "$name" 2>&1 | tail -20; exit 1; }
echo "Inner dockerd version: $sv"

info=$(docker exec "$name" docker info --format '{{.Driver}} {{.CgroupVersion}}' 2>&1)
echo "Inner daemon storage/cgroup: $info"
[ -n "$info" ] || { echo "FAIL: docker info returned nothing"; exit 1; }

echo "Verifying the dev tooling (bash, apk, wget, buildx, compose)..."
docker exec "$name" sh -c 'bash --version | head -1; apk --version; wget --version | head -1; docker buildx version; docker compose version' \
  || { echo "FAIL: dev tooling missing"; exit 1; }

echo "All docker-dev tests passed!"
