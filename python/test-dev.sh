#!/bin/bash
# Smoke test for minimal-python-dev.
# Validates the dev variant has shell + toolchain + pip/uv while
# preserving prod runtime parity (same entrypoint, same Python).
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing Python version (parity with prod)..."
docker run --rm "$IMAGE" --version | grep -q "Python 3.14"

echo "Testing /bin/sh (busybox)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok" | grep -q sh-ok

echo "Testing /bin/bash..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok" | grep -q bash-ok

echo "Testing apk-tools present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version" | grep -q apk-tools

echo "Testing C toolchain (gcc, make, pkgconf)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "gcc --version && make --version && pkgconf --version" >/dev/null

echo "Testing Python C headers (python-3.14-dev)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "ls /usr/include/python3.14/Python.h" >/dev/null

echo "Testing git..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "git --version" | grep -q "git version"

echo "Testing pip is baked in (no runtime install needed)..."
pip_ver=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "pip --version")
echo "$pip_ver" | grep -qE "pip [0-9]+\.[0-9]+" || { echo "::error::pip version unexpected: $pip_ver"; exit 1; }

echo "Testing uv is baked in..."
uv_ver=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "uv --version")
echo "$uv_ver" | grep -qE "uv [0-9]+\.[0-9]+" || { echo "::error::uv version unexpected: $uv_ver"; exit 1; }

echo "Testing setuptools available..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "python3 -c 'import setuptools; print(setuptools.__version__)'" >/dev/null

echo "Testing pip install --user works for nonroot..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  "pip install --quiet --no-cache-dir --user --disable-pip-version-check requests && python3 -c 'import requests; print(requests.__version__)'" >/dev/null

echo "Testing core stdlib (ssl, json, sqlite3, hashlib)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  "python3 -c 'import ssl, json, sqlite3, hashlib; print(\"Core stdlib OK\")'" | grep -q "Core stdlib OK"

echo "✓ All python-dev smoke tests passed"
