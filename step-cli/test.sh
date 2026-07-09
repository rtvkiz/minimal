#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing step version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE 'Smallstep CLI/0\.[0-9]|0\.30'

echo "Testing step help (subcommands load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'certificate|crypto|\bca\b'

echo "Testing step crypto keypair generation (fully offline)..."
work=$(mktemp -d); chmod 0777 "$work"
# nonroot (65532) writes the key pair into the bind-mounted workdir; the dir
# must be world-writable. --no-password --insecure keeps it non-interactive.
docker run --rm -v "$work:/workspace" "$IMAGE" \
  crypto keypair /workspace/pub.pem /workspace/priv.pem --kty EC --no-password --insecure
# step writes the PEMs as 0600 owned by uid 65532, so the host user cannot read
# them; verify they exist and are non-empty (stat only needs the 0777 dir).
if [ -s "$work/pub.pem" ] && [ -s "$work/priv.pem" ]; then
  echo "step crypto keypair OK"
else
  echo "FAIL: step did not produce a key pair"
  ls -la "$work"; rm -rf "$work"; exit 1
fi
rm -rf "$work"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All step-cli tests passed!"
