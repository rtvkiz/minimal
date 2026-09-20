#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI
: "${IMAGE:?IMAGE env var required}"

echo "Testing Airflow parity with production..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  'airflow version | grep -q "3.3.2"'
echo "Testing /bin/sh and /bin/bash..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'test "$(echo sh-ok)" = sh-ok'
docker run --rm --entrypoint /bin/bash "$IMAGE" -c 'test "$(echo bash-ok)" = bash-ok'
echo "Testing python interpreter and airflow import..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  'python3.12 -c "import airflow; print(airflow.__version__)" | grep -q 3.3.2'
echo "Testing apk-tools and standard debugging tools..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c \
  'apk --version >/dev/null && curl --version >/dev/null && wget --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null && dig -v >/dev/null 2>&1 && git --version >/dev/null'
echo "All Airflow dev tests passed!"
