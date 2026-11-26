#!/bin/bash
# Smoke test for minimal-docker (prod): the Docker CLI, no daemon.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing docker CLI version..."
v=$(docker run --rm --network none "$IMAGE" --version 2>&1)
echo "$v" | grep -qE '^Docker version [0-9]+\.[0-9]+' || { echo "FAIL: unexpected docker --version: $v"; exit 1; }

echo "Testing buildx and compose CLI plugins..."
b=$(docker run --rm --network none "$IMAGE" buildx version 2>&1)
echo "$b" | grep -q 'github.com/docker/buildx' || { echo "FAIL: buildx plugin: $b"; exit 1; }
c=$(docker run --rm --network none "$IMAGE" compose version 2>&1)
echo "$c" | grep -q 'Docker Compose version' || { echo "FAIL: compose plugin: $c"; exit 1; }

echo "Testing it drives a daemon over a mounted socket, as nonroot..."
# The documented usage: mount the socket and add its group. This is the path
# that breaks if the image ever loses the CLI's TLS/socket plumbing.
sock=/var/run/docker.sock
if [ -S "$sock" ]; then
  gid=$(stat -c %g "$sock")
  sv=$(docker run --rm -v "$sock:$sock" --group-add "$gid" "$IMAGE" version --format '{{.Server.Version}}' 2>&1)
  echo "$sv" | grep -qE '^[0-9]+\.[0-9]+' || { echo "FAIL: could not reach the daemon through the socket: $sv"; exit 1; }
  echo "Server version via socket: $sv"
else
  echo "No $sock on this host; skipping the socket check"
fi

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell, no daemon, no package manager..."
for f in /bin/sh /usr/bin/dockerd /usr/bin/containerd /sbin/apk; do
  docker run --rm --entrypoint "$f" "$IMAGE" --version >/dev/null 2>&1 \
    && { echo "FAIL: $f present in prod"; exit 1; }
done
echo "None present (as expected)"

echo "All docker tests passed!"
