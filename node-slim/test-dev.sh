#!/bin/bash
# Smoke test for minimal-node-slim-dev.
# Validates shell + toolchain + node package managers while preserving
# prod runtime parity.
set -euo pipefail

: "${IMAGE:?IMAGE env var required}"

echo "Testing Node.js version (parity with prod)..."
docker run --rm "$IMAGE" --version | grep -qE "^v(26|2[6-9])\."

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing C toolchain (gcc, make, pkgconf)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "gcc --version && make --version && pkgconf --version" >/dev/null

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "Testing npm baked in..."
npm_ver=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "npm --version")
echo "$npm_ver" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+" || { echo "::error::npm version unexpected: $npm_ver"; exit 1; }

echo "Testing yarn baked in..."
yarn_ver=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "yarn --version")
echo "$yarn_ver" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+" || { echo "::error::yarn version unexpected: $yarn_ver"; exit 1; }

echo "Testing pnpm baked in..."
pnpm_ver=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "pnpm --version")
echo "$pnpm_ver" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+" || { echo "::error::pnpm version unexpected: $pnpm_ver"; exit 1; }

echo "Testing corepack baked in..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "corepack --version" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+"

echo "Testing node-gyp baked in..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "node-gyp --version" | grep -qE "^v?[0-9]+\."

echo "Testing npm install works (writes to ~/.npm)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  "cd /tmp && npm init -y >/dev/null && npm install --silent --no-fund --no-audit lodash && node -e 'console.log(require(\"lodash\").VERSION || \"lodash loaded\")'" \
  | grep -qE "(lodash loaded|^[0-9]+\.[0-9]+\.[0-9]+)"

echo "Testing core node modules (crypto, fs, http)..."
docker run --rm "$IMAGE" -e "require('crypto'); require('fs'); require('http'); console.log('Core modules OK')" \
  | grep -q "Core modules OK"

echo "✓ All node-slim-dev smoke tests passed"
