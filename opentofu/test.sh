#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing tofu version..."
docker run --rm "$IMAGE" version 2>&1 | grep -qiE 'OpenTofu v[0-9]'

echo "Testing tofu help (subcommands load)..."
docker run --rm "$IMAGE" -help 2>&1 | grep -qiE 'Usage: tofu'

echo "Testing tofu can init a trivial config (no providers)..."
work=$(mktemp -d)
# The image runs as nonroot (uid 65532); make the bind-mounted workspace
# readable/writable by the container user so `tofu init` can read main.tf and
# write .terraform.lock.hcl. mktemp -d is 0700/owner-only by default.
chmod 0777 "$work"
cat > "$work/main.tf" <<'TF'
terraform {}
output "ok" { value = "hello" }
TF
chmod 0644 "$work/main.tf"
docker run --rm -v "$work:/workspace" "$IMAGE" init -backend=false 2>&1 | grep -qiE 'has been successfully initialized'
rm -rf "$work"

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All opentofu tests passed!"
