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
