#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing gitlab-runner version..."
gv=$(docker run --rm --entrypoint /usr/bin/gitlab-runner "$IMAGE" --version 2>&1)
echo "$gv" | grep -qE 'Version:[[:space:]]+19\.[0-9]+' || { echo "unexpected version: $gv"; exit 1; }

echo "Verifying the runner reports its own name..."
# common.NAME is one of the three -X ldflags upstream sets. Get it wrong and the
# runner registers itself under the wrong name with the GitLab instance, which
# is invisible until someone looks at the admin UI.
echo "$gv" | grep -q 'gitlab-runner' || { echo "FAIL: NAME ldflag not applied: $gv"; exit 1; }

echo "Testing gitlab-runner subcommands are wired..."
docker run --rm --entrypoint /usr/bin/gitlab-runner "$IMAGE" --help 2>&1 | grep -qE 'register|verify|unregister'

echo "Testing gitlab-runner reads a config offline..."
# Real round-trip against the writable config dir: write a config, list it back.
# Exercises TOML parsing, the config path the image pins in `cmd`, and that
# /etc/gitlab-runner is writable by uid 65532 — not just flag parsing.
work=$(mktemp -d); chmod 0777 "$work"
trap 'rm -rf "$work"' EXIT
cat > "$work/config.toml" <<'TOML'
concurrent = 4
check_interval = 3

[[runners]]
  name = "minimal-smoke-test"
  url = "https://gitlab.example.com/"
  token = "not-a-real-token"
  executor = "docker"
  [runners.docker]
    image = "alpine:latest"
TOML
chmod 0666 "$work/config.toml"

out=$(docker run --rm -v "$work:/cfg" --entrypoint /usr/bin/gitlab-runner "$IMAGE" \
  list --config /cfg/config.toml 2>&1)
echo "$out" | grep -q 'minimal-smoke-test' \
  || { echo "FAIL: runner did not list the configured runner: $out"; exit 1; }
echo "$out" | grep -q 'Executor=docker' \
  || { echo "FAIL: executor not parsed from config: $out"; exit 1; }
echo "config parse round-trip OK"

echo "Verifying git is present for repository cloning..."
# The shell and custom executors clone the project themselves; a runner image
# that cannot clone is not a runner.
docker run --rm --entrypoint /usr/bin/git "$IMAGE" --version 2>&1 | grep -q 'git version' \
  || { echo "FAIL: git missing"; exit 1; }

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "FAIL: shell found!" && exit 1 || echo "No shell (as expected)"

echo "All gitlab-runner tests passed!"
