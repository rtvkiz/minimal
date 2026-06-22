#!/bin/bash
set -euo pipefail

echo "Testing mailpit version..."
# `mailpit version` prints the version, then phones GitHub to check for a
# newer release; that check exits non-zero on any network hiccup (e.g. a 403
# when the runner IP is rate-limited), which under `set -e` failed the whole
# job even though the binary works. Capture output and assert the version
# string instead of trusting the exit code.
ver_out=$(docker run --rm --entrypoint /usr/bin/mailpit "$IMAGE" version 2>&1 || true)
echo "$ver_out"
echo "$ver_out" | grep -qiE 'mailpit v[0-9]' || { echo "FAIL: mailpit version not reported"; exit 1; }

echo "Testing mailpit server starts..."
docker run -d --name mailpit-test \
  -p 11025:1025 \
  -p 18025:8025 \
  "$IMAGE"
sleep 5

if docker ps | grep -q mailpit-test; then
  echo "mailpit container is running"
  docker logs mailpit-test

  echo "Checking HTTP UI /livez at :18025..."
  if curl -sf --retry 5 --retry-delay 2 http://localhost:18025/livez; then
    echo "mailpit HTTP /livez OK"
  else
    echo "FAIL: mailpit HTTP /livez check failed"
    docker logs mailpit-test
    docker stop mailpit-test && docker rm mailpit-test
    exit 1
  fi

  echo "Checking SMTP banner at :11025..."
  if printf 'QUIT\r\n' | timeout 5 nc -w 3 localhost 11025 | grep -qi "Mailpit"; then
    echo "mailpit SMTP banner OK"
  else
    echo "FAIL: mailpit SMTP banner check failed"
    docker logs mailpit-test
    docker stop mailpit-test && docker rm mailpit-test
    exit 1
  fi

  docker stop mailpit-test && docker rm mailpit-test
else
  echo "mailpit failed to start, checking logs..."
  docker logs mailpit-test 2>&1 || true
  docker rm mailpit-test 2>/dev/null || true
  exit 1
fi

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All mailpit tests passed!"
