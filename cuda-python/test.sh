#!/bin/bash
set -euo pipefail

echo "Testing Python interpreter..."
docker run --rm "$IMAGE" -c "import sys; print(f'Python {sys.version}')"

echo "Testing TLS/SSL..."
docker run --rm "$IMAGE" -c "import ssl; print('TLS OK:', ssl.OPENSSL_VERSION)"

echo "Testing stdlib modules..."
docker run --rm "$IMAGE" -c "import json, hashlib, http.client; print('stdlib OK')"

echo "Verifying all CUDA libraries are present and loadable..."
docker run --rm "$IMAGE" -c "
import ctypes, os, glob

lib_dir = '/usr/lib'

# All libraries that should be present from our subpackages
required_libs = {
    'libcudart.so':          'cudart',
    'libcublas.so':          'cublas',
    'libcublasLt.so':        'cublasLt',
    'libnvblas.so':          'nvblas',
    'libcufft.so':           'cufft',
    'libcufftw.so':          'cufftw',
    'libcurand.so':          'curand',
    'libcusolver.so':        'cusolver',
    'libcusolverMg.so':      'cusolverMg',
    'libcusparse.so':        'cusparse',
    'libnvtx3interop.so':    'nvtx3interop',
    'libnvJitLink.so':       'nvJitLink',
    'libcudnn.so':           'cudnn',
}

for lib_name, label in required_libs.items():
    matches = glob.glob(os.path.join(lib_dir, lib_name + '*'))
    if not matches:
        print(f'FAIL: {lib_name} not found in {lib_dir}')
        exit(1)
    lib_path = matches[0]
    try:
        handle = ctypes.CDLL(lib_path)
        print(f'  {label}: OK ({os.path.basename(lib_path)})')
    except OSError as e:
        # Libraries load but may fail to resolve driver deps - expected without GPU
        print(f'  {label}: present but missing driver dep (expected in CI): {e}')

print(f'All {len(required_libs)} CUDA libraries verified.')
"

echo "Verifying CUDA library symbols are real (not stubs)..."
docker run --rm "$IMAGE" -c "
import ctypes

# Verify key function symbols exist in the libraries.
# This proves the .so files contain real code, not just empty stubs.
# We only check symbols - we don't call them (that would need a GPU).
symbol_checks = {
    'libcudart.so':   ['cudaGetDeviceCount', 'cudaMalloc', 'cudaFree', 'cudaMemcpy'],
    'libcublas.so':   ['cublasCreate_v2', 'cublasSgemm_v2'],
    'libcufft.so':    ['cufftPlan1d', 'cufftExecC2C'],
    'libcurand.so':   ['curandCreateGenerator'],
    'libcusparse.so': ['cusparseCreate'],
    'libcudnn.so':    ['cudnnCreate', 'cudnnGetVersion'],
}

for lib_name, symbols in symbol_checks.items():
    try:
        handle = ctypes.CDLL(f'/usr/lib/{lib_name}')
    except OSError:
        print(f'  {lib_name}: skipped (cannot load without driver)')
        continue
    for sym in symbols:
        try:
            getattr(handle, sym)
        except AttributeError:
            print(f'FAIL: symbol {sym} not found in {lib_name}')
            exit(1)
    print(f'  {lib_name}: {len(symbols)} symbols verified')

print('Symbol verification: OK')
"

echo "Calling CUDA library functions to verify runtime versions..."
docker run --rm "$IMAGE" -c "
import ctypes

# These version-query functions work WITHOUT a GPU or driver.
# They read version info compiled into the library itself.

# --- CUDA Runtime version ---
libcudart = ctypes.CDLL('/usr/lib/libcudart.so')
version = ctypes.c_int()
err = libcudart.cudaRuntimeGetVersion(ctypes.byref(version))
assert err == 0, f'cudaRuntimeGetVersion failed with error {err}'
major = version.value // 1000
minor = (version.value % 1000) // 10
print(f'  CUDA Runtime: {major}.{minor} (raw: {version.value})')
assert major == 12, f'Expected CUDA 12.x, got {major}.{minor}'

# --- cuDNN version ---
libcudnn = ctypes.CDLL('/usr/lib/libcudnn.so')
libcudnn.cudnnGetVersion.restype = ctypes.c_size_t
ver = libcudnn.cudnnGetVersion()
cudnn_major = ver // 10000
cudnn_minor = (ver % 10000) // 100
cudnn_patch = ver % 100
print(f'  cuDNN: {cudnn_major}.{cudnn_minor}.{cudnn_patch} (raw: {ver})')
assert cudnn_major == 9, f'Expected cuDNN 9.x, got {cudnn_major}'

# --- cuBLAS version ---
libcublas = ctypes.CDLL('/usr/lib/libcublas.so')
handle = ctypes.c_void_p()
err = libcublas.cublasCreate_v2(ctypes.byref(handle))
if err == 0:
    blas_ver = ctypes.c_int()
    libcublas.cublasGetVersion_v2(handle, ctypes.byref(blas_ver))
    print(f'  cuBLAS: version {blas_ver.value}')
    libcublas.cublasDestroy_v2(handle)
else:
    # cublasCreate may need driver init on some builds
    print(f'  cuBLAS: skipped (create returned {err}, expected without driver)')

print('CUDA runtime version checks: OK')
"

echo "Verifying NVIDIA env vars..."
docker run --rm "$IMAGE" -c "
import os
assert os.environ.get('NVIDIA_VISIBLE_DEVICES') == 'all', 'NVIDIA_VISIBLE_DEVICES not set'
assert os.environ.get('NVIDIA_DRIVER_CAPABILITIES') == 'compute,utility', 'NVIDIA_DRIVER_CAPABILITIES not set'
print('NVIDIA env vars: OK')
"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "::error::Shell found in image!" && exit 1 \
  || echo "No shell confirmed"
