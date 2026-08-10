# Contributing

This guide covers how to add a new hardened container image to the project.

## Prerequisites

Install the same major tool versions CI uses — a version mismatch is a common
source of "works locally, fails in CI":

```bash
go install chainguard.dev/apko@v1.1.6
go install chainguard.dev/melange@v0.41.1
brew install anchore/grype/grype
```

- [apko](https://github.com/chainguard-dev/apko) — image assembly
- [melange](https://github.com/chainguard-dev/melange) — package building (only if compiling from source)
- [Docker](https://docs.docker.com/get-docker/)
- [Grype](https://github.com/anchore/grype) — vulnerability scanning; this is what CI scans with

Note: `melange build` cross-architecture builds need QEMU. Without it, an
`--arch x86_64,aarch64` build fails on the aarch64 leg with
`bwrap: execvp /bin/sh: Exec format error`. Build `--arch x86_64` locally; CI
builds ARM on native runners.

## Project structure

```text
minimal/
├── <image>/
│   ├── apko/<name>.yaml          # production image assembly
│   ├── apko/<name>-dev.yaml      # development/debug variant
│   ├── melange.yaml              # source build, when applicable
│   ├── test.sh                   # production smoke test
│   └── test-dev.sh               # development-variant smoke test
├── vex/<name>.openvex.json       # per-image vulnerability statements
├── .github/
│   ├── versions.yaml             # source-version update registry
│   ├── patch-deps.yaml           # non-Go dependency patch registry
│   ├── autoupdate-coverage.yaml  # package-based update classification
│   ├── scripts/                  # shared updater implementation
│   └── workflows/                # build, update, security, site, and cleanup automation
├── catalog.json                  # canonical public image inventory
├── docs/                         # onboarding, update, and variant standards
├── site/                         # minimalcontainers.com Astro site
├── Makefile
└── README.md
```

## Adding a New Image

> **📋 The complete, authoritative checklist is [`docs/onboarding.md`](docs/onboarding.md).**
> This section is a quick intro; that file is the source of truth and covers every
> registration point (including the CI-enforced ones — `catalog.json` and `vex/` —
> and the build/test patterns, versions.yaml conventions, and gotchas). Onboard
> from the checklist, not from memory: two past incidents (the "frozen-8" and the
> catalog-drift PR failure) were skipped-step bugs.

Adding an image is mechanical. Every registration point:

| File | When you need it |
|---|---|
| `<name>/apko/<name>.yaml` + `<name>/test.sh` (`chmod +x`) | always |
| `<name>/apko/<name>-dev.yaml` + `<name>/test-dev.sh` | recommended — see [dev variant conventions](docs/dev-variants/CONVENTIONS.md) |
| `vex/<name>.openvex.json` | always (CI-validated) |
| Entry in `.github/workflows/build.yml` matrix | always (CI-enforced) |
| Entry in `catalog.json` | always — **`validate-catalog` fails the PR without it** |
| `Makefile` version var + `.PHONY` + build/test targets | always |
| `<name>/melange.yaml` | only when building from source (try Wolfi first) |
| Row in `.github/versions.yaml` | source-built — to auto-bump the app version |
| Three dicts in `.github/workflows/patch-go-deps.yml`, **or** `SKIP_IMAGES` | source-built **Go** — transitive CVE patching (or a documented exclusion) |
| Row in `.github/patch-deps.yaml` | source-built Ruby/Rust/Maven |

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

### 4. Register the image with the build pipeline

`.github/workflows/build.yml` keeps two JSON arrays in a `Detect changes and
generate matrices` step. Add your image to the right one. The arrays are at the
top of that step; search for `MELANGE_IMAGES=` and `APKO_IMAGES=`.

**Apko-only image** (uses a Wolfi pre-built package — most common):

```jsonc
APKO_IMAGES='[
  ...
  {"name":"<image-name>","grep":"<wolfi-pkg-pattern>","variants":["prod","dev"]}
]'
```

The `grep` field is the regex used by the change-detection logic to decide
whether your image needs a rebuild when Wolfi packages change. Use the apk
name (e.g. `"nginx-mainline"`, `"openjdk-[0-9]+"`).

**Source-built image** (you have a `melange.yaml`):

```jsonc
MELANGE_IMAGES='[
  ...
  {"name":"<image-name>","variants":["prod","dev"]}
]'
```

If your apko config file isn't at the default `<name>/apko/<name>.yaml`,
add an `"apko":"<path>"` field. Drop the `dev` variant from the list if
you haven't created a `-dev.yaml`.

That's it for builds: path triggers, scan, test, publish, sign, summary,
and cleanup all pick up the new image automatically.

### 5. (Optional) Wire up upstream-version auto-bumps

If you want CI to open a PR whenever your upstream cuts a new release, add a
row to `.github/versions.yaml`. The matrix workflow `update-versions.yml`
reads this file and runs the discover → checksum → patch → PR cycle for
every row daily.

Pick the source type that matches your upstream:

| Type | Use when |
|---|---|
| `github-releases-latest` | upstream publishes a single "latest" release on GitHub |
| `github-tags` | upstream publishes tags but `/releases/latest` is unreliable (mixed-major repo, no GitHub Releases, etc.) |
| `scrape` | upstream version lives in an HTML directory listing or homepage scrape |
| `json` | upstream exposes a REST API returning JSON |
| `plain-text` | a single URL returns the bare version as text |

Minimal example (most common case — a Go/Rust project that publishes a
release per tag on GitHub):

```yaml
- name: <image-name>
  files: [<image-name>/melange.yaml]
  source:
    type: github-releases-latest
    repo: <owner>/<repo>
    strip-v: true
    pin-major: 1
  tarball:
    url: "https://github.com/<owner>/<repo>/archive/refs/tags/v{version}.tar.gz"
    field: sha256
  major-issue: true        # open a tracking issue if a new major appears
  links:
    releases: "https://github.com/<owner>/<repo>/releases"
    notes:    "https://github.com/<owner>/<repo>/releases/tag/v{version}"
```

Full schema and worked examples for each source type live at the top of
`.github/versions.yaml`. For dispatch testing before scheduling, run:

```bash
gh workflow run update-versions.yml -f only=<image-name>
```

To enable the daily cron for your row, add `cron-enabled: true` once
you've verified the dispatch run produces a clean PR.

### 6. (Optional) Wire up transitive-dep CVE patching

If your image ships Ruby gems, Rust crates, or Maven JARs and you want
grype-driven CVE patches auto-opened on a 6h cron, add an entry under
the matching row in `.github/patch-deps.yaml`:

```yaml
- name: bundler           # or rust / maven
  ...
  images:
    - { name: <image-name>, src-root: "/home/build/<name>-<<PKG_VERSION>>", build-marker: "<unique line in your melange pipeline>" }
```

`build-marker` is grepped against your melange.yaml; the patch block is
inserted before the `- runs:` step containing that marker. Go images use
the separate, bespoke `patch-go-deps.yml` workflow — its accumulated
production-tested rules (OTel family pinning, `+incompatible` suffix list,
main-module self-bump filter, etc.) aren't worth lifting into a generic
schema for one language.

### 6a. Go images: register in patch-go-deps.yml

> **Easy to miss.** A new Go image will sit with unpatched transitive CVEs
> forever unless you add three entries to `.github/workflows/patch-go-deps.yml`.
> alertmanager shipped with 24 critical/high CVEs from `golang.org/x/crypto`,
> `golang.org/x/net`, and `go.opentelemetry.io/otel/*` for exactly this
> reason — the workflow walks `for IMAGE in "${!MODROOTS[@]}"`, so an image
> not in MODROOTS is silently skipped every cron cycle.

Three dictionaries inside the `Scan ... and generate patches` step:

```bash
declare -A MODROOTS=(
  # ...
  [<image-name>]="/home/build/<source-tarball-dir>-${D}{{package.version}}"
)

declare -A MAIN_MODULES=(
  # The image's OWN module path — used to drop self-bump `go get <self>@<ver>`
  [<image-name>]="github.com/<upstream-owner>/<upstream-repo>"
)

declare -A BUILD_MARKERS=(
  # A literal line that EXISTS in your melange.yaml's pipeline. The patch
  # block gets spliced before the `- runs:` step containing this marker.
  [<image-name>]='# Build foo from source'
)
```

After adding, dispatch the workflow once (`gh workflow run patch-go-deps.yml`)
to validate the splice and produce an initial patch PR. Without this step,
the next 6h scheduled run will still skip your image.

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
