#!/bin/bash
set -euo pipefail

echo "Testing Telegraf version..."
docker run --rm --entrypoint /usr/bin/telegraf "$IMAGE" --version

echo "Testing Telegraf config validation..."
docker run --rm --entrypoint /usr/bin/telegraf "$IMAGE" \
  --config /etc/telegraf/telegraf.conf --test --quiet >/dev/null

echo "Testing Telegraf starts, emits metrics, and exits cleanly..."
# --once: run a single collection cycle and exit. Confirms agent loop,
# cpu input plugin, and file output plugin all work end-to-end.
OUT=$(docker run --rm --entrypoint /usr/bin/telegraf "$IMAGE" \
  --config /etc/telegraf/telegraf.conf --once 2>&1)

if ! echo "$OUT" | grep -q '^cpu,'; then
  echo "Expected at least one cpu,... line in output, got:"
  echo "$OUT"
  exit 1
fi
echo "Saw cpu metrics in InfluxDB line protocol output"

echo "✓ Telegraf tests passed"
