#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing cosign version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE 'GitVersion:[[:space:]]*v?3\.[0-9]'

echo "Testing cosign help (subcommands load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'sign|verify|attest'

echo "Testing cosign generate-key-pair (fully offline)..."
work=$(mktemp -d); chmod 0777 "$work"
# nonroot (65532) writes the key pair into the bind-mounted workdir; the dir
# must be world-writable for that to succeed. COSIGN_PASSWORD makes it non-interactive.
docker run --rm -e COSIGN_PASSWORD=testpassword -v "$work:/workspace" "$IMAGE" generate-key-pair
if [ -f "$work/cosign.pub" ] && grep -q 'PUBLIC KEY' "$work/cosign.pub"; then
  echo "cosign generate-key-pair OK"
else
  echo "FAIL: cosign did not produce a valid public key"
  ls -la "$work"; rm -rf "$work"; exit 1
fi
rm -rf "$work"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All cosign tests passed!"
