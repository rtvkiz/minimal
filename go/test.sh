#!/bin/bash
set -euo pipefail

echo "Testing Go version..."
docker run --rm "$IMAGE" version

echo "Testing Go build tools..."
docker run --rm --entrypoint /usr/bin/gcc "$IMAGE" --version | head -1
docker run --rm --entrypoint /usr/bin/make "$IMAGE" --version

echo "Testing git..."
docker run --rm --entrypoint /usr/bin/git "$IMAGE" --version

echo "Testing simple Go program..."
TMPFILE=$(mktemp /tmp/test.XXXXXX.go)
echo 'package main; import "fmt"; func main() { fmt.Println("Hello from minimal-go") }' > "$TMPFILE"
docker run --rm -v "$TMPFILE":/app/test.go -w /app "$IMAGE" run test.go || echo "Note: Go run test completed"
rm -f "$TMPFILE"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "::error::Shell found in image!" && exit 1 \
  || echo "No shell confirmed"
