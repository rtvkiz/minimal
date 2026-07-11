#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

# kubeconform uses Go's stdlib flag package: -v (version), -h (help)
echo "Testing kubeconform version..."
docker run --rm "$IMAGE" -v 2>&1 | grep -qiE '0\.[0-9]'

echo "Testing kubeconform help (flags load)..."
docker run --rm "$IMAGE" -h 2>&1 | grep -qiE 'schema|kubernetes-version|summary'

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All kubeconform tests passed!"
