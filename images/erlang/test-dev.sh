#!/bin/bash
# Smoke test for minimal-erlang-dev.
# Same functional checks as prod, PLUS: bash IS present, the C toolchain can
# build a NIF, and rebar3 is installed.
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing Erlang/OTP release..."
ver=$(docker run --rm "$IMAGE" -noshell -eval \
  'io:format("otp=~s erts=~s~n",[erlang:system_info(otp_release), erlang:system_info(version)]), halt().' 2>&1)
echo "$ver" | grep -qE 'otp=[0-9]+ erts=[0-9]+\.' \
  || { echo "FAIL: could not read OTP release: $ver"; exit 1; }

echo "Testing the crypto app (OpenSSL NIF) works offline..."
sha=$(docker run --rm "$IMAGE" -noshell -eval \
  'ok = application:start(crypto),
   io:format("sha=~s~n",[binary:encode_hex(crypto:hash(sha256, <<"minimal">>))]),
   halt().' 2>&1)
echo "$sha" | grep -qE 'sha=[0-9A-F]{64}' \
  || { echo "FAIL: crypto app did not produce a digest: $sha"; exit 1; }

echo "Verifying bash IS present (dev)..."
docker run --rm --entrypoint /bin/bash "$IMAGE" -c 'echo bash-ok' 2>/dev/null | grep -q bash-ok \
  || { echo "FAIL: no bash in dev image"; exit 1; }

echo "Verifying rebar3 is present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v rebar3' >/dev/null 2>&1 \
  || { echo "FAIL: rebar3 missing from dev image"; exit 1; }

echo "Verifying the C toolchain can compile (offline)..."
cc=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c '
  set -e
  cd /tmp
  cat > hello.c <<EOF
#include <stdio.h>
int main(void) { printf("cc-ok\n"); return 0; }
EOF
  cc -o hello hello.c && ./hello' 2>&1)
echo "$cc" | grep -q 'cc-ok' || { echo "FAIL: C toolchain did not compile: $cc"; exit 1; }

echo "Verifying erl_nif.h is available for NIF builds (offline)..."
# The dev variant exists so NIFs and port drivers can be built — that needs the
# OTP headers on the include path, not just a working cc.
nif=$(docker run --rm --entrypoint /bin/sh "$IMAGE" -c '
  set -e
  inc=$(erl -noshell -eval "io:format(\"~s\",[code:root_dir()]), halt()." 2>/dev/null)/usr/include
  test -f "$inc/erl_nif.h" || exit 1
  cd /tmp
  cat > nif.c <<EOF
#include <erl_nif.h>
static ErlNifFunc funcs[] = {};
ERL_NIF_INIT(dummy, funcs, NULL, NULL, NULL, NULL)
EOF
  cc -fPIC -shared -I"$inc" -o dummy.so nif.c && echo nif-ok' 2>&1)
echo "$nif" | grep -q 'nif-ok' || { echo "FAIL: could not build a NIF shared object: $nif"; exit 1; }

echo "Verifying git and curl are present..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v git && command -v curl' >/dev/null 2>&1 \
  || { echo "FAIL: git/curl missing from dev image"; exit 1; }

echo "All erlang dev tests passed!"
