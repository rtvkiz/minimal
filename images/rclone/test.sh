#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing rclone version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qE 'rclone v1\.[0-9]+'

echo "Testing rclone backend registry is populated..."
# The backends ARE rclone; if the build dropped them the binary still runs but
# is useless. Assert several well-known ones are compiled in.
docker run --rm "$IMAGE" help backends 2>&1 | grep -qi 's3'
docker run --rm "$IMAGE" help backends 2>&1 | grep -qi 'sftp'
docker run --rm "$IMAGE" help backends 2>&1 | grep -qi 'webdav'

echo "Testing rclone copies and verifies real data..."
# copy → check against a mounted directory. Exercises the local backend,
# hashing and the verify path end to end. The prod image has no shell, so each
# step is its own `docker run` sharing the mount.
WORK=$(mktemp -d); chmod 0777 "$WORK"
mkdir -p "$WORK/src" "$WORK/dst"; chmod 0777 "$WORK/src" "$WORK/dst"
echo "hello-rclone" > "$WORK/src/probe.txt"
# The container runs as uid 65532 and leaves files the host user cannot
# remove. Cleanup must never fail: a non-zero EXIT trap overrides the script's
# real exit status, so a fully passing test would report failure.
trap 'rm -rf "$WORK" 2>/dev/null || true' EXIT

docker run --rm -v "$WORK:/data" "$IMAGE" copy /data/src /data/dst >/dev/null 2>&1
docker run --rm -v "$WORK:/data" "$IMAGE" check /data/src /data/dst 2>&1 | grep -qi '0 differences found'

grep -q 'hello-rclone' "$WORK/dst/probe.txt" \
  || { echo "FAIL: copied content mismatch"; exit 1; }
echo "rclone copy/check OK"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All rclone tests passed!"
