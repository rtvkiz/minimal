#!/bin/bash
set -eu  # NB: no pipefail — `docker run | grep` is SIGPIPE-prone

: "${IMAGE:?IMAGE env var required}"

echo "Testing gitlab-runner version..."
gv=$(docker run --rm --entrypoint /usr/bin/gitlab-runner "$IMAGE" --version 2>&1)
echo "$gv" | grep -qE 'Version:[[:space:]]+19\.[0-9]+' || { echo "unexpected version: $gv"; exit 1; }

echo "Verifying this is OUR build, not Wolfi's..."
# Provenance guard, and the most load-bearing assertion in this file.
# Wolfi's `gitlab-runner-19.3` package `p:`-provides the bare name
# `gitlab-runner`, so apk can satisfy our apko request with THEIR binary; the
# melange package carries provider-priority: 100 to stop that. Both builds are
# 19.3.1, so a version check alone cannot tell them apart — the ldflags can:
#
#   ours     Git branch: v19.3.1   Git revision: HEAD    Built: (empty)
#   Wolfi's  Git branch: HEAD      Git revision: a16f5092  Built: 2026-08-24...
#
# `Git branch` is set by our -X ...common.BRANCH flag and is HEAD by default, so
# asserting it fails the moment resolution slips back to Wolfi's package.
echo "$gv" | grep -qE 'Git branch:[[:space:]]+v19\.' \
  || { echo "FAIL: not our build — provider-priority may have regressed:"; echo "$gv"; exit 1; }

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
# The runner colourises its log fields, so the raw output reads
# `Executor<ESC>[0;m=docker` — a naive grep for 'Executor=docker' fails against
# a perfectly good image. Strip the escapes before matching.
clean=$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g')
echo "$clean" | grep -q 'minimal-smoke-test' \
  || { echo "FAIL: runner did not list the configured runner: $out"; exit 1; }
echo "$clean" | grep -q 'Executor=docker' \
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
