#!/bin/bash
set -euo pipefail

echo "Testing Java version..."
docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version

echo "Testing Jenkins WAR..."
docker run --rm --entrypoint /usr/bin/java "$IMAGE" \
  -jar /usr/share/jenkins/jenkins.war --version

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "::error::Shell found in image!" && exit 1 \
  || echo "No shell confirmed"

echo "Verifying git is present..."
docker run --rm --entrypoint /usr/bin/git "$IMAGE" --version

echo "Verifying core utils..."
docker run --rm --entrypoint /bin/ls "$IMAGE" /usr/bin/java

# Boot Jenkins and prove it serves.
#
# Everything above is offline — the WAR's version, the JRE, git's presence.
# None of it would notice a bundled-jar CVE swap that breaks at RUNTIME rather
# than at class-load, and that is exactly the risk auto-patching this image has
# to be safe against. This is the test that lets jenkins move off report-only
# in .github/patch-deps.yaml.
echo "Starting Jenkins and waiting for its login page..."
cid=$(docker run -d -p 18080:8080 "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT

ok=""
for _ in $(seq 1 90); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:18080/login 2>/dev/null || true)
  # 403 is a valid "serving" answer too — a locked-down instance still proves
  # the servlet container and the WAR came up.
  case "$code" in
    200|403) ok="$code"; break ;;
  esac
  [ "$(docker inspect -f '{{.State.Running}}' "$cid" 2>/dev/null)" = "true" ] || break
  sleep 1
done
[ -n "$ok" ] || { echo "FAIL: Jenkins never served /login"; docker logs "$cid" 2>&1 | tail -25; exit 1; }
echo "Jenkins /login returned HTTP $ok"
