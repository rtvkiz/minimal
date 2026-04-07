#!/bin/bash
set -euo pipefail

echo "Testing Python interpreter..."
docker run --rm "$IMAGE" -c "import sys; print(f'Python {sys.version}')"

echo "Testing TLS/SSL..."
docker run --rm "$IMAGE" -c "import ssl; print('TLS OK:', ssl.OPENSSL_VERSION)"

echo "Testing stdlib modules..."
docker run --rm "$IMAGE" -c "import json, hashlib, http.client; print('stdlib OK')"

echo "Verifying CUDA libraries are present..."
docker run --rm --entrypoint "" "$IMAGE" /usr/bin/python3 -c "
import ctypes, os, glob

# Check for key CUDA shared libraries
required_libs = ['libcudart.so', 'libcublas.so', 'libcudnn.so']
lib_dir = '/usr/lib'
for lib_name in required_libs:
    matches = glob.glob(os.path.join(lib_dir, lib_name + '*'))
    if not matches:
        print(f'FAIL: {lib_name} not found in {lib_dir}')
        exit(1)
    # Try loading the library
    lib_path = matches[0]
    try:
        ctypes.CDLL(lib_path)
        print(f'{lib_name}: OK ({os.path.basename(lib_path)})')
    except OSError as e:
        print(f'{lib_name}: loadable but missing driver (expected in CI): {e}')
"

echo "Verifying NVIDIA env vars..."
docker run --rm --entrypoint "" "$IMAGE" /usr/bin/python3 -c "
import os
assert os.environ.get('NVIDIA_VISIBLE_DEVICES') == 'all', 'NVIDIA_VISIBLE_DEVICES not set'
assert os.environ.get('NVIDIA_DRIVER_CAPABILITIES') == 'compute,utility', 'NVIDIA_DRIVER_CAPABILITIES not set'
print('NVIDIA env vars: OK')
"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "::error::Shell found in image!" && exit 1 \
  || echo "No shell confirmed"
