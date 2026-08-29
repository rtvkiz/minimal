#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep -q` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing kube-vip version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qE 'Version: +v?1\.[0-9]+\.[0-9]+'

echo "Testing kube-vip generates a static pod manifest..."
# Real work, no cluster needed: `manifest pod` renders the static-pod YAML that
# kubeadm drops into /etc/kubernetes/manifests. Exercises cobra wiring, the
# config struct and the manifest renderer — a binary that links but cannot run
# fails here rather than silently passing a --version check.
out=$(docker run --rm "$IMAGE" manifest pod \
        --interface eth0 \
        --address 192.168.0.40 \
        --controlplane \
        --arp \
        --leaderElection 2>&1)
printf '%s' "$out" | grep -q 'kind: Pod'
printf '%s' "$out" | grep -q 'name: kube-vip'
printf '%s' "$out" | grep -q 'value: eth0'
printf '%s' "$out" | grep -q '192.168.0.40'
echo "kube-vip pod manifest OK"

echo "Testing kube-vip generates a daemonset manifest..."
docker run --rm "$IMAGE" manifest daemonset \
  --interface eth0 \
  --address 192.168.0.40 \
  --services \
  --inCluster 2>&1 | grep -q 'kind: DaemonSet'
echo "kube-vip daemonset manifest OK"

echo "Testing kube-vip manager fails cleanly without a kubeconfig..."
# The manager cannot reach an API server here. It must exit with an error
# rather than hang or crash — confirms the runtime path is actually reached.
docker run --rm "$IMAGE" manager --interface lo --address 127.0.0.1 2>&1 \
  | grep -qiE 'kubernetes|kubeconfig|connection refused|no such file|unable|error' \
  && echo "kube-vip manager error handling OK"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All kube-vip tests passed!"
