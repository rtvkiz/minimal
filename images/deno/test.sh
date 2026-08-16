#!/bin/bash
set -euo pipefail

echo "Testing Deno version..."
docker run --rm "$IMAGE" --version

echo "Testing Deno runs TypeScript..."
docker run --rm "$IMAGE" eval "console.log('Deno ' + Deno.version.deno + ' OK')"

echo "Testing Deno permissions sandbox..."
# deno eval doesn't support permission flags; use 'deno run --deny-net -' (stdin) instead
docker run --rm -i "$IMAGE" run --deny-net - << 'DENO'
try {
  await fetch('http://example.com');
  console.error('FAIL: should have been blocked by permissions sandbox');
  Deno.exit(1);
} catch(e) {
  if (e.name === 'NotCapable' || e.message.includes('net') || e.message.includes('NotCapable')) {
    console.log('Permissions sandbox works correctly');
  } else {
    throw e;
  }
}
DENO

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" \
  -c "echo fail" 2>/dev/null && echo "FAIL: shell found!" && exit 1 || echo "✓ No shell (as expected)"

echo "✓ Deno tests passed"
