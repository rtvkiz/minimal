#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing buildctl version..."
cv=$(docker run --rm --entrypoint /usr/bin/buildctl "$IMAGE" --version 2>&1)
echo "$cv" | grep -qE 'buildctl .* v0\.[0-9]+' || { echo "unexpected version: $cv"; exit 1; }

echo "Testing buildkitd version..."
dv=$(docker run --rm --entrypoint /usr/bin/buildkitd "$IMAGE" --version 2>&1)
echo "$dv" | grep -qE 'buildkitd .* v0\.[0-9]+' || { echo "unexpected version: $dv"; exit 1; }

echo "Testing buildctl subcommands are wired..."
docker run --rm --entrypoint /usr/bin/buildctl "$IMAGE" --help 2>&1 | grep -qE 'build|du|prune'

echo "Verifying buildkitd was built with seccomp support..."
# buildkitd is the one CGO_ENABLED=1 build in this catalogue, purely so the
# `seccomp` tag can link libseccomp. Dropping the tag still compiles and still
# runs — it just silently stops applying a seccomp profile to build steps. That
# is invisible at runtime, so assert it here.
docker run --rm --entrypoint /usr/bin/buildkitd "$IMAGE" --help 2>&1 | grep -q 'oci-worker-no-process-sandbox' \
  || { echo "FAIL: OCI worker flags missing"; exit 1; }

echo "Verifying runc is present for the OCI worker..."
# Without runc, buildkitd starts and then fails every solve with
# "exec: runc: not found" — a runtime failure that looks like a build error.
docker run --rm --entrypoint /usr/bin/runc "$IMAGE" --version 2>&1 | grep -q 'runc version' \
  || { echo "FAIL: runc missing"; exit 1; }

echo "Testing buildkitd boots and serves its gRPC API..."
# The real round-trip. buildkitd creates mount/user namespaces for every build
# step, so it needs --privileged here; that is the documented posture for this
# image (see apko/buildkit.yaml), not a workaround for the test.
CID=$(docker run -d --rm --privileged \
  --entrypoint /usr/bin/buildkitd "$IMAGE" \
  --root /var/lib/buildkit \
  --addr unix:///run/buildkit/buildkitd.sock)
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT

ok=""
for _ in $(seq 1 30); do
  if docker exec "$CID" /usr/bin/buildctl --addr unix:///run/buildkit/buildkitd.sock debug workers >/dev/null 2>&1; then
    ok=1; break
  fi
  sleep 1
done
[ -n "$ok" ] || { echo "FAIL: buildkitd did not serve its API"; docker logs "$CID" 2>&1 | tail -30; exit 1; }

workers=$(docker exec "$CID" /usr/bin/buildctl --addr unix:///run/buildkit/buildkitd.sock debug workers 2>&1)
echo "$workers" | grep -qE 'ID|PLATFORM' || { echo "FAIL: no workers registered: $workers"; exit 1; }
echo "buildkitd gRPC + worker registration OK"

echo "Verifying the OCI worker actually came up (not just the socket)..."
# A daemon with no worker accepts connections and fails every build. Assert the
# worker line, which is what proves runc was found and the snapshotter works.
docker logs "$CID" 2>&1 | grep -q 'found 1 workers' \
  || { echo "FAIL: no OCI worker registered"; docker logs "$CID" 2>&1 | tail -20; exit 1; }
echo "OCI worker OK"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All buildkit tests passed!"
