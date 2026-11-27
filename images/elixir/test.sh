#!/bin/bash
# Smoke test for minimal-elixir (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing elixir version..."
v=$(docker run --rm --network none "$IMAGE" elixir --version 2>&1)
echo "$v" | grep -qE '^Elixir 1\.[0-9]+' || { echo "FAIL: unexpected elixir --version: $v"; exit 1; }
echo "$v" | grep -qE 'Erlang/OTP 29' || { echo "FAIL: not on OTP 29: $v"; exit 1; }

echo "Testing evaluation and OTP crypto (no network)..."
out=$(docker run --rm --network none "$IMAGE" elixir -e 'IO.puts(Enum.sum(1..10)); IO.puts(:crypto.hash(:sha256, "x") |> Base.encode16(case: :lower) |> binary_part(0, 8))')
[ "$out" = "$(printf '55\n2d711642')" ] || { echo "FAIL: elixir -e output: $out"; exit 1; }

echo "Testing mix new + mix test offline (needs a writable project dir)..."
vol="minimal-elixir-smoke-$$"
docker volume create "$vol" >/dev/null
trap 'docker volume rm -f "$vol" >/dev/null 2>&1 || true' EXIT
out=$(docker run --rm --network none -v "$vol:/app" "$IMAGE" sh -c 'cd /app && mix new hello >/dev/null && cd hello && mix test 2>&1' ) \
  || { echo "FAIL: mix new/test: $out"; exit 1; }
# Elixir 1.20 prints "Result: N passed (...)"; older releases "N tests, 0 failures".
echo "$out" | grep -qE 'Result: [0-9]+ passed|[0-9]+ tests?, 0 failures' || { echo "FAIL: mix test output: $out"; exit 1; }
echo "$out" | grep -qiE '[1-9][0-9]* fail' && { echo "FAIL: mix test reported failures: $out"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying busybox sh only (declared: elixir/iex/mix are sh launchers), no bash, no apk..."
for f in /bin/bash /usr/bin/bash /sbin/apk; do
  docker run --rm --entrypoint "$f" "$IMAGE" --version >/dev/null 2>&1 \
    && { echo "FAIL: $f present in prod"; exit 1; }
done
echo "busybox sh only (as expected)"

echo "All elixir tests passed!"
