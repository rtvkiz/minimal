#!/bin/bash
# Smoke test for minimal-busybox (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing busybox version..."
v=$(docker run --rm --network none "$IMAGE" busybox --help 2>&1 | head -1)
echo "$v" | grep -qE '^BusyBox v1\.[0-9]+' || { echo "FAIL: unexpected busybox banner: $v"; exit 1; }

echo "Testing drop-in image shape (no entrypoint, CMD /bin/sh)..."
# Docker Hub's busybox has no entrypoint, so `docker run busybox echo hi` runs
# echo. An entrypoint of /bin/sh would instead try to run a script named echo.
ep=$(docker inspect --format '{{json .Config.Entrypoint}}' "$IMAGE")
cmd=$(docker inspect --format '{{json .Config.Cmd}}' "$IMAGE")
[ "$ep" = "null" ] || [ "$ep" = "[]" ] || { echo "FAIL: expected no entrypoint, got $ep"; exit 1; }
[ "$cmd" = '["/bin/sh"]' ] || { echo "FAIL: expected CMD [\"/bin/sh\"], got $cmd"; exit 1; }
out=$(docker run --rm --network none "$IMAGE" echo drop-in-ok 2>&1)
[ "$out" = "drop-in-ok" ] || { echo "FAIL: docker run IMAGE echo: $out"; exit 1; }
out=$(echo 'echo stdin-ok' | docker run --rm -i --network none "$IMAGE" 2>&1)
[ "$out" = "stdin-ok" ] || { echo "FAIL: default CMD shell on stdin: $out"; exit 1; }

work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work"' EXIT

echo "Testing a POSIX script with the core utilities (no network)..."
cat > "$work/smoke.sh" <<'SH'
set -e
printf 'b 2\na 1\nc 3\n' > /tmp/in.txt
first=$(sort /tmp/in.txt | head -1 | cut -d' ' -f1)
sum=$(awk '{s += $2} END {print s}' /tmp/in.txt)
up=$(echo x | sed s/x/y/ | tr y Y)
mkdir -p /tmp/t/d && echo data > /tmp/t/d/f
tar -C /tmp/t -czf /tmp/t.tgz d && mkdir /tmp/u && tar -C /tmp/u -xzf /tmp/t.tgz
grep -q data /tmp/u/d/f
echo "sh-ok $first $sum $up"
SH
chmod 0644 "$work/smoke.sh"
out=$(docker run --rm --network none -v "$work:/work" "$IMAGE" sh smoke.sh 2>&1)
[ "$out" = "sh-ok a 6 Y" ] || { echo "FAIL: sh script output: $out"; exit 1; }

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }
id=$(docker run --rm --network none "$IMAGE" id -u)
[ "$id" = "65532" ] || { echo "FAIL: runs as uid $id"; exit 1; }

echo "Verifying no network applets (wget, nc, telnet are busybox-full only)..."
applets=$(docker run --rm --network none "$IMAGE" busybox --list)
for a in wget nc telnet ftpget tftp httpd; do
  echo "$applets" | grep -qx "$a" && { echo "FAIL: network applet $a compiled in"; exit 1; }
  docker run --rm --network none "$IMAGE" sh -c "command -v $a" >/dev/null 2>&1 \
    && { echo "FAIL: $a on PATH"; exit 1; }
done
echo "No network applets (as expected)"

echo "Verifying no setuid/setgid files..."
# As root: nonroot can't read several baselayout dirs (/root, /var/mail...),
# so a nonroot find both exits non-zero and could miss a file in them.
suid=$(docker run --rm --network none --user 0 "$IMAGE" find / -xdev \( -perm -4000 -o -perm -2000 \) -type f)
[ -z "$suid" ] || { echo "FAIL: setuid/setgid files: $suid"; exit 1; }

echo "Verifying no package manager (restraint guard)..."
docker run --rm --entrypoint /sbin/apk "$IMAGE" --version >/dev/null 2>&1 \
  && { echo "FAIL: apk found — restraint guard violated"; exit 1; } \
  || echo "No apk (as expected)"
docker run --rm --entrypoint /bin/bash "$IMAGE" --version >/dev/null 2>&1 \
  && { echo "FAIL: bash found in prod"; exit 1; } \
  || echo "No bash (as expected)"

echo "All busybox tests passed!"
