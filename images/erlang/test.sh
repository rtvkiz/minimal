#!/bin/bash
# Smoke test for minimal-erlang (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing Erlang/OTP release..."
ver=$(docker run --rm "$IMAGE" -noshell -eval \
  'io:format("otp=~s erts=~s~n",[erlang:system_info(otp_release), erlang:system_info(version)]), halt().' 2>&1)
echo "$ver" | grep -qE 'otp=[0-9]+ erts=[0-9]+\.' \
  || { echo "FAIL: could not read OTP release: $ver"; exit 1; }
echo "$ver"

echo "Testing the crypto app (OpenSSL NIF) works offline..."
# crypto is the app most likely to break on a minimal image — it dlopens the
# OpenSSL NIF, so this proves libcrypto3 is present and ABI-compatible.
sha=$(docker run --rm "$IMAGE" -noshell -eval \
  'ok = application:start(crypto),
   io:format("sha=~s~n",[binary:encode_hex(crypto:hash(sha256, <<"minimal">>))]),
   halt().' 2>&1)
echo "$sha" | grep -qE 'sha=[0-9A-F]{64}' \
  || { echo "FAIL: crypto app did not produce a digest: $sha"; exit 1; }

echo "Testing the ssl app starts (offline)..."
ssl=$(docker run --rm "$IMAGE" -noshell -eval \
  'ok = application:start(crypto), ok = application:start(asn1),
   ok = application:start(public_key), ok = application:start(ssl),
   io:format("ssl-ok~n"), halt().' 2>&1)
echo "$ssl" | grep -q 'ssl-ok' \
  || { echo "FAIL: ssl app failed to start: $ssl"; exit 1; }

echo "Testing escript runs a script (offline)..."
work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work"' EXIT
cat > "$work/hello.erl" <<'ERL'
#!/usr/bin/env escript
main(_) ->
    L = lists:sum(lists:seq(1, 100)),
    io:format("escript-ok sum=~p~n", [L]).
ERL
chmod 0644 "$work/hello.erl"
esc=$(docker run --rm -v "$work:/app" --entrypoint /usr/bin/escript "$IMAGE" /app/hello.erl 2>&1)
echo "$esc" | grep -q 'escript-ok sum=5050' \
  || { echo "FAIL: escript did not run correctly: $esc"; exit 1; }

echo "Testing the compiler works (offline)..."
# erlc + the BEAM loading its own output: proves the toolchain half of OTP.
cat > "$work/m.erl" <<'ERL'
-module(m).
-export([go/0]).
go() -> io:format("compile-ok ~p~n", [lists:reverse([1,2,3])]).
ERL
chmod 0644 "$work/m.erl"
comp=$(docker run --rm -v "$work:/app" -w /app "$IMAGE" -noshell -eval \
  '{ok, m} = compile:file("m.erl", [{outdir,"/tmp"}]),
   {module, m} = code:load_abs("/tmp/m"),
   m:go(), halt().' 2>&1)
echo "$comp" | grep -q 'compile-ok' \
  || { echo "FAIL: erlang compiler round-trip failed: $comp"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

# --- Shell policy for this image -------------------------------------------
# OTP's /usr/bin/erl is a `#!/bin/sh` wrapper, so busybox is REQUIRED. Guard
# both directions, same as the postgres family: sh must exist (regression),
# bash/apk must not (restraint).
echo "Verifying /bin/sh exists (required by the erl wrapper)..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'echo sh-ok' 2>/dev/null | grep -q sh-ok \
  || { echo "FAIL: /bin/sh missing — /usr/bin/erl cannot run"; exit 1; }

echo "Verifying bash and apk-tools are ABSENT (prod restraint)..."
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v bash' >/dev/null 2>&1; then
  echo "FAIL: bash found in prod image"; exit 1
fi
if docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'command -v apk' >/dev/null 2>&1; then
  echo "FAIL: apk-tools found in prod image"; exit 1
fi
echo "busybox only (as expected)"

echo "All erlang tests passed!"
