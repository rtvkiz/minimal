#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing restic version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qE 'restic 0\.[0-9]+'

echo "Testing restic backup round-trip (init → backup → check → restore)..."
# Full lifecycle against a real repository. The prod image has no shell, so the
# steps are separate `docker run` invocations sharing a mounted directory —
# /data inside the image is not persisted between runs.
# Exercises repo creation, key derivation, the chunker, the index, the
# integrity checker and restore. A `--version` check would pass on a binary
# that cannot actually write a repository.
WORK=$(mktemp -d); chmod 0777 "$WORK"
mkdir -p "$WORK/src" "$WORK/restored"; chmod 0777 "$WORK/src" "$WORK/restored"
echo "hello-restic" > "$WORK/src/probe.txt"
# The container runs as uid 65532 and leaves files the host user cannot
# remove. Cleanup must never fail: a non-zero EXIT trap overrides the script's
# real exit status, so a fully passing test would report failure.
trap 'rm -rf "$WORK" 2>/dev/null || true' EXIT

R=(docker run --rm -v "$WORK:/data"
   -e RESTIC_REPOSITORY=/data/repo -e RESTIC_PASSWORD=smoke "$IMAGE")

"${R[@]}" init            2>&1 | grep -qi 'created restic repository'
"${R[@]}" backup /data/src 2>&1 | grep -qiE 'snapshot .* saved'
"${R[@]}" check            2>&1 | grep -qi 'no errors were found'
"${R[@]}" restore latest --target /data/restored >/dev/null 2>&1

grep -q 'hello-restic' "$WORK/restored/data/src/probe.txt" \
  || { echo "FAIL: restored content mismatch"; ls -R "$WORK/restored" | head; exit 1; }
echo "restic init/backup/check/restore OK"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All restic tests passed!"
