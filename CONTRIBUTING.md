# Contributing

This guide covers how to add a new hardened container image to the project.

## Prerequisites

Install the following tools locally:

- [apko](https://github.com/chainguard-dev/apko) — image assembly
- [melange](https://github.com/chainguard-dev/melange) — package building (only if compiling from source)
- [Docker](https://docs.docker.com/get-docker/)
- [Trivy](https://aquasecurity.github.io/trivy/) — vulnerability scanning (optional, for local scans)

## Adding a New Image

Adding an image requires 3 things: an apko config, a test script, and a matrix entry.

### 1. Create the directory structure

```
<image-name>/
├── apko/
│   └── <image-name>.yaml   # Image definition
└── test.sh                  # Test script
```

If building from source (rare — only needed when Wolfi doesn't have the package):

```
<image-name>/
├── apko/
│   └── <image-name>.yaml
├── melange.yaml             # Source build definition
└── test.sh
```

### 2. Write the apko config

Use `python/apko/python.yaml` as a starting template. Every config must include:

```yaml
contents:
  repositories:
    - https://packages.wolfi.dev/os
  keyring:
    - https://packages.wolfi.dev/os/wolfi-signing.rsa.pub
  packages:
    - wolfi-baselayout
    - ca-certificates-bundle
    # Add your runtime packages here

accounts:
  groups:
    - groupname: nonroot
      gid: 65532
  users:
    - username: nonroot
      uid: 65532
      gid: 65532
  run-as: 65532

entrypoint:
  command: /usr/bin/<your-binary>

work-dir: /app

environment:
  PATH: /usr/bin:/bin
  LANG: C.UTF-8

paths:
  - path: /app
    type: directory
    uid: 65532
    gid: 65532
    permissions: 0o755
  - path: /tmp
    type: directory
    permissions: 0o1777

archs:
  - x86_64
  - aarch64
```

**Rules:**

- Only include packages the runtime strictly needs. Fewer packages = fewer CVEs.
- Always include `ca-certificates-bundle` for TLS support.
- Run as UID 65532 (nonroot) unless the upstream service requires a specific UID (e.g., PostgreSQL uses 70).
- Do not include a shell unless the service absolutely requires it.

### 3. Write the test script

Create `<image-name>/test.sh`. The script receives the image reference via the `$IMAGE` environment variable.

```bash
#!/bin/bash
set -euo pipefail

echo "Testing <image-name> version..."
docker run --rm "$IMAGE" --version

echo "Verifying no shell..."
docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo fail" 2>/dev/null \
  && echo "::error::Shell found in image!" && exit 1 \
  || echo "No shell confirmed"
```

**Requirements:**

- Use `set -euo pipefail` — fail on any error.
- Reference the image via `$IMAGE`, never hardcode.
- Verify the binary runs and produces expected output.
- Verify no shell is present (unless unavoidable via transitive dependencies).
- For services (databases, web servers): start a container, verify it's running, then clean up.

Make the script executable:

```bash
chmod +x <image-name>/test.sh
```

Test locally:

```bash
IMAGE=ghcr.io/<owner>/minimal-<image-name>:latest ./<image-name>/test.sh
```

### 4. Add the matrix entry

Add your image to the `matrix.include` list in `.github/workflows/build.yml`:

```yaml
- name: <image-name>
  apko_config: <image-name>/apko/<image-name>.yaml
  build_type: apko
```

For source builds (melange):

```yaml
- name: <image-name>
  apko_config: <image-name>/apko/<image-name>.yaml
  melange_config: <image-name>/melange.yaml
  build_type: melange
```

That's it. The path triggers, scan, test, publish, sign, summary, and cleanup steps all pick up the new image automatically.

## Build Locally

```bash
# Simple image (Wolfi package)
make <image-name>

# Source build (melange + apko)
make keygen
make <image-name>

# Test
IMAGE=ghcr.io/$(git config user.name | tr '[:upper:]' '[:lower:]' | tr ' ' '-')/minimal-<image-name>:latest \
  ./<image-name>/test.sh

# Scan
trivy image --severity CRITICAL,HIGH ghcr.io/.../minimal-<image-name>:latest
```

## Conventions

| Convention | Value |
|------------|-------|
| Image naming | `minimal-<image-name>` (kebab-case) |
| Default UID/GID | 65532 (nonroot) |
| Shell | None (distroless) unless unavoidable |
| Entrypoint | Full path to binary (e.g., `/usr/bin/python3`) |
| Working directory | `/app` |
| TLS | Always include `ca-certificates-bundle` |
| Architectures | `x86_64` and `aarch64` |
| Package source | Prefer Wolfi pre-built packages over source builds |

## Submitting a PR

1. Create a branch with your new image.
2. Verify it builds and tests pass locally.
3. Open a PR. The CI will build, scan, and test your image automatically.
4. The vulnerability scan is non-blocking — CVEs are reported but won't prevent the build.
5. Images are signed and published after merge to main.
