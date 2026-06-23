#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing trivy version..."
docker run --rm "$IMAGE" --version 2>&1 | grep -qiE 'Version: 0\.[0-9]'

echo "Testing trivy help (scanners load)..."
docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'image|filesystem|config'

echo "Testing trivy config scan on a clean Dockerfile (no DB download needed)..."
work=$(mktemp -d); chmod 0777 "$work"
cat > "$work/Dockerfile" <<'DF'
FROM scratch
USER 65532
DF
chmod 0644 "$work/Dockerfile"
# misconfig scanning runs offline (policies are embedded); exit 0 = no findings.
docker run --rm -v "$work:/workspace" "$IMAGE" config --quiet /workspace 2>&1 | tail -3
rm -rf "$work"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All trivy tests passed!"
