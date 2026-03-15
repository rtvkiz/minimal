#!/bin/bash
set -euo pipefail

echo "Testing etcd version..."
docker run --rm --entrypoint /usr/bin/etcd "$IMAGE" --version
docker run --rm --entrypoint /usr/bin/etcdctl "$IMAGE" version

echo "Testing etcd starts and responds to client requests..."
docker run -d --name etcd-test \
  "$IMAGE" \
  --data-dir=/var/lib/etcd \
  --listen-client-urls=http://0.0.0.0:2379 \
  --advertise-client-urls=http://127.0.0.1:2379 \
  --listen-peer-urls=http://0.0.0.0:2380 \
  --initial-advertise-peer-urls=http://127.0.0.1:2380 \
  --initial-cluster=default=http://127.0.0.1:2380
sleep 3

if docker ps | grep -q etcd-test; then
  ETCD_IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' etcd-test)
  docker run --rm --entrypoint /usr/bin/etcdctl "$IMAGE" \
    --endpoints="http://${ETCD_IP}:2379" endpoint health
  docker run --rm --entrypoint /usr/bin/etcdctl "$IMAGE" \
    --endpoints="http://${ETCD_IP}:2379" put testkey testvalue
  docker run --rm --entrypoint /usr/bin/etcdctl "$IMAGE" \
    --endpoints="http://${ETCD_IP}:2379" get testkey | grep -q testvalue
  echo "etcd put/get works"
  docker stop etcd-test && docker rm etcd-test
else
  echo "etcd failed to start"
  docker logs etcd-test 2>&1 || true
  docker rm etcd-test 2>/dev/null || true
  exit 1
fi

echo "✓ etcd tests passed"
