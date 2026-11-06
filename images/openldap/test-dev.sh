#!/bin/bash
# Smoke test for minimal-openldap-dev.
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone in CI

: "${IMAGE:?IMAGE env var required}"

echo "Testing slapd present (parity with prod)..."
ver=$(docker run --rm --entrypoint /usr/bin/slapd "$IMAGE" -VV 2>&1 || true)
echo "$ver" | grep -qE 'OpenLDAP: slapd 2\.[0-9]+\.[0-9]+' || { echo "FAIL: slapd: $ver"; exit 1; }

echo "Testing ldap clients present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "command -v ldapsearch >/dev/null && command -v ldapadd >/dev/null"

echo "Testing /bin/sh (busybox)..."
out=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo sh-ok"); [ "$out" = sh-ok ]

echo "Testing /bin/bash..."
out=$(docker run --rm --entrypoint /bin/bash "$IMAGE" -c "echo bash-ok"); [ "$out" = bash-ok ]

echo "Testing apk-tools present..."
out=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c "apk --version"); echo "$out" | grep -q apk-tools

echo "Testing curl/openssl/jq/dig present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "curl --version >/dev/null && openssl version >/dev/null && jq --version >/dev/null && dig -v 2>&1 | grep -qE '^DiG'"

echo "✓ All openldap-dev smoke tests passed"
