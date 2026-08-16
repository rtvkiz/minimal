#!/bin/bash
set -euo pipefail

echo "Testing HTTPD starts..."
docker run -d --name httpd-test "$IMAGE"
sleep 2

if docker ps | grep -q httpd-test; then
  echo "HTTPD is running"
  docker logs httpd-test
  docker stop httpd-test && docker rm httpd-test
else
  echo "HTTPD failed to start, checking logs..."
  docker logs httpd-test 2>&1 || true
  docker rm httpd-test 2>/dev/null || true
  exit 1
fi

# Some httpd/Wolfi dependency chains can bring a minimal /bin/sh.
# We treat shell presence as informational for httpd (we still gate on CVEs + startup).
echo "Checking for shell presence (informational)..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c "true" 2>/dev/null; then
  echo "::notice::/bin/sh is present in minimal-httpd (not treated as failure)"
else
  echo "No /bin/sh found (shell-less)"
fi
