#!/bin/bash
# Smoke test for minimal-argo-cd-repo-server (prod).
set -eu
: "${IMAGE:?IMAGE env var required}"

echo "Testing argocd version (client-only, no cluster needed)..."
v=$(docker run --rm --entrypoint /usr/local/bin/argocd "$IMAGE" version --client 2>&1)
echo "$v" | grep -qE 'argocd: v[0-9]+\.[0-9]+\.[0-9]+' || { echo "FAIL: unexpected version output: $v"; exit 1; }

echo "Testing repo-server help (subcommand loads)..."
h=$(docker run --rm "$IMAGE" --help 2>&1)
echo "$h" | grep -qi 'repo-server' || { echo "FAIL: unexpected repo-server --help output: $h"; exit 1; }

echo "Testing bundled git/helm/kustomize are invokable (repo-server's real runtime deps)..."
docker run --rm --entrypoint /usr/bin/git "$IMAGE" --version | grep -qE 'git version [0-9]' \
  || { echo "FAIL: git --version did not look right"; exit 1; }
docker run --rm --entrypoint /usr/bin/helm "$IMAGE" version --short | grep -qE '^v[0-9]+\.[0-9]+' \
  || { echo "FAIL: helm version did not look right"; exit 1; }
docker run --rm --entrypoint /usr/bin/kustomize "$IMAGE" version | grep -qE '[0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "FAIL: kustomize version did not look right"; exit 1; }

echo "Starting repo-server and waiting for it to open its gRPC port (offline)..."
port=18081
cid=$(docker run -d -p "127.0.0.1:${port}:8081" "$IMAGE")
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
ok=0
for _ in $(seq 1 20); do
  if [ -z "$(docker ps -q --filter id="$cid")" ]; then break; fi
  if (exec 3<>"/dev/tcp/127.0.0.1/${port}") 2>/dev/null; then exec 3<&-; exec 3>&-; ok=1; break; fi
  sleep 1
done
if [ "$ok" != 1 ]; then
  echo "FAIL: repo-server never opened :8081"
  docker logs "$cid" 2>&1 | tail -40
  exit 1
fi

echo "Verifying non-root..."
uid=$(docker inspect --format '{{.Config.User}}' "$IMAGE")
[ "$uid" = "65532" ] || { echo "FAIL: expected uid 65532, got '$uid'"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && { echo "FAIL: shell found!"; exit 1; } || echo "No shell (as expected)"

echo "All argo-cd-repo-server tests passed!"
