#!/bin/bash
# Smoke test for minimal-bash (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing bash version..."
v=$(docker run --rm "$IMAGE" --version 2>&1)
echo "$v" | grep -qE '^GNU bash, version 5\.[0-9]+' || { echo "FAIL: unexpected bash --version: $v"; exit 1; }

work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work"' EXIT

echo "Testing a script that uses bash-only features (no network)..."
# Associative arrays, [[ ]], arithmetic, process substitution and here-strings:
# none of these exist in a POSIX sh, so this fails if /bin/bash were busybox.
cat > "$work/smoke.sh" <<'SH'
declare -A seen=()
for w in alpha beta alpha gamma; do seen[$w]=$(( ${seen[$w]:-0} + 1 )); done
[[ ${seen[alpha]} -eq 2 && ${#seen[@]} -eq 3 ]] || { echo "assoc-array-broken"; exit 1; }
mapfile -t lines < <(printf 'one\ntwo\n')
read -r first <<< "${lines[0]}"
echo "bash-ok ${first} ${#lines[@]}"
SH
chmod 0644 "$work/smoke.sh"
out=$(docker run --rm --network none -v "$work:/work" "$IMAGE" smoke.sh 2>&1)
[ "$out" = "bash-ok one 2" ] || { echo "FAIL: bash script output: $out"; exit 1; }

echo "Testing the utilities a script reaches for are present..."
out=$(docker run --rm --network none "$IMAGE" -c 'printf "b\na\n" | sort | head -1; echo x | sed s/x/y/; ls / >/dev/null && echo ls-ok' 2>&1)
[ "$out" = "$(printf 'a\ny\nls-ok')" ] || { echo "FAIL: utilities: $out"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }
id=$(docker run --rm "$IMAGE" -c 'id -u')
[ "$id" = "65532" ] || { echo "FAIL: runs as uid $id"; exit 1; }

echo "Verifying no package manager (restraint guard)..."
docker run --rm --entrypoint /sbin/apk "$IMAGE" --version >/dev/null 2>&1 \
  && { echo "FAIL: apk found — restraint guard violated"; exit 1; } \
  || echo "No apk (as expected)"

echo "All bash tests passed!"
