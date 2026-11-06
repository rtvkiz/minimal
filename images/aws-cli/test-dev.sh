#!/bin/bash
# Smoke test for minimal-aws-cli-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing aws --version (parity with prod)..."
VERSION_OUT=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$VERSION_OUT" | grep -qE '^aws-cli/2\.[0-9]+\.[0-9]+ Python/3\.' \
  || { echo "FAIL: unexpected version: $VERSION_OUT"; exit 1; }

echo "Testing aws help renders (full groff + less are dev-only)..."
HELP=$(docker run --rm "$IMAGE" s3 help 2>&1)
echo "$HELP" | grep -q 'DESCRIPTION' || { echo "FAIL: aws s3 help rendered no man page"; echo "$HELP" | head -5; exit 1; }

echo "Testing /bin/sh (busybox)..."
OUT=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok")
[ "$OUT" = "sh-ok" ] || { echo "FAIL: /bin/sh"; exit 1; }

echo "Testing /bin/bash..."
OUT=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok")
[ "$OUT" = "bash-ok" ] || { echo "FAIL: /bin/bash"; exit 1; }

echo "Testing apk-tools present..."
OUT=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version")
echo "$OUT" | grep -q apk-tools || { echo "FAIL: apk-tools missing"; exit 1; }

echo "Testing curl/jq/git present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && jq --version >/dev/null && git --version >/dev/null"

echo "Testing aws output piped through jq (the common scripting path)..."
OUT=$(docker run --rm --network none --entrypoint /bin/sh \
  -e AWS_ACCESS_KEY_ID=testing -e AWS_SECRET_ACCESS_KEY=testing \
  "$IMAGE" -c 'aws ec2 run-instances --generate-cli-skeleton | jq -r "has(\"ImageId\")"')
[ "$OUT" = "true" ] || { echo "FAIL: aws | jq returned '$OUT'"; exit 1; }

echo "All minimal-aws-cli-dev smoke tests passed"
