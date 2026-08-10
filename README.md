<p align="center">
  <img src="assets/logo.svg" alt="minimal — hardened container images" width="600">
</p>

<p align="center">
  Small, hardened container images, free and MIT-licensed.<br>
  Built with Chainguard's <a href="https://github.com/chainguard-dev/apko">apko</a>, <a href="https://github.com/chainguard-dev/melange">melange</a>, and <a href="https://github.com/wolfi-dev">Wolfi</a> packages; rebuilt every six hours.<br>
  Production images are signed and published with SPDX SBOM and SLSA build-provenance attestations.
</p>

<p align="center">
  <a href="https://minimalcontainers.com"><strong>Browse the live image catalog at minimalcontainers.com →</strong></a>
</p>

<p align="center">
  <a href="https://github.com/rtvkiz/minimal/actions/workflows/build.yml"><img src="https://github.com/rtvkiz/minimal/actions/workflows/build.yml/badge.svg" alt="Build status"></a>
  <a href="https://minimalcontainers.com"><img src="https://img.shields.io/badge/Image_Catalog-Live-0d9488" alt="Image catalog"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <a href="https://slsa.dev/spec/v1.0/levels#build-l3"><img src="https://img.shields.io/badge/SLSA-Level_3-0d9488" alt="SLSA Level 3"></a>
  <img src="https://img.shields.io/badge/Images-96-0d9488" alt="Images: 96">
  <img src="https://img.shields.io/badge/Arch-amd64_%7C_arm64-0d9488" alt="Architectures: amd64 and arm64">
</p>

<p align="center">
  <a href="#pull-and-verify-an-image">Verify an image</a> ·
  <a href="https://minimalcontainers.com/images">All 96 images</a> ·
  <a href="#how-images-stay-current">Update model</a> ·
  <a href="https://minimalcontainers.com/docs">Docs</a>
</p>

---

## Pull and verify an image

Public images are available from GHCR without an account:

```bash
docker pull ghcr.io/rtvkiz/minimal-python:latest
```

Verify the GitHub build provenance:

```bash
gh attestation verify \
  oci://ghcr.io/rtvkiz/minimal-python:latest \
  --owner rtvkiz
```

Verify the keyless Cosign signature:

```bash
cosign verify \
  --certificate-identity-regexp='https://github.com/rtvkiz/minimal/' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/rtvkiz/minimal-python:latest
```

Download the attached SPDX SBOM attestation:

```bash
cosign verify-attestation --type spdxjson \
  --certificate-identity-regexp='https://github.com/rtvkiz/minimal/' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/rtvkiz/minimal-python:latest \
  | jq -r '.payload | @base64d | fromjson | .predicate' \
  > python-sbom.spdx.json
```

More verification examples and the vulnerability-reporting policy are in [`.github/SECURITY.md`](.github/SECURITY.md).

## What the project provides

- Public, readable build recipes for every image.
- Native `linux/amd64` and `linux/arm64` packages and images.
- A keyless Cosign signature for each published image digest.
- SPDX SBOM attestations for the published architectures and image index.
- SLSA v1.0 build provenance tied to the GitHub workflow and commit.
- Grype reports in the [live catalog](https://minimalcontainers.com) and GitHub Security tab.
- Non-root execution by default, except where an upstream application requires another user model.
- Shell-less production images where the application permits it.
- A `:latest-dev` companion for every production image.
- Six-hour rebuilds to consume current Wolfi packages and security fixes.
- Automated application-version and transitive-dependency update PRs.

The project does not provide a vendor SLA, an on-call support contract, or FedRAMP/FIPS/STIG accreditation. The signatures, SBOMs, and provenance help with verification and audits, but do not replace those programs.

## Available images — 96 total

Browse the full, always-current inventory with sizes and CVE counts at
**[minimalcontainers.com/images](https://minimalcontainers.com/images)**.
The canonical source is [`catalog.json`](catalog.json), validated against the
build matrix in CI.

| Category | Count |
|---|---:|
| Kubernetes, CI & IaC | 29 |
| Observability | 15 |
| Infrastructure | 11 |
| Databases | 9 |
| Caches, Queues & Messaging | 9 |
| Languages & Runtimes | 9 |
| Web Servers & Proxies | 8 |
| Apps | 5 |

## Quick start

```bash
# Python application
docker run --rm -v "$PWD:/app" \
  ghcr.io/rtvkiz/minimal-python:latest /app/main.py

# Nginx web server
docker run --rm -p 8080:80 \
  ghcr.io/rtvkiz/minimal-nginx:latest

# PostgreSQL
docker run --rm -p 5432:5432 -v pgdata:/var/lib/postgresql/data \
  ghcr.io/rtvkiz/minimal-postgres-slim:latest

# Redis
docker run --rm -p 6379:6379 \
  ghcr.io/rtvkiz/minimal-redis-slim:latest

# Caddy version
docker run --rm --entrypoint /usr/bin/caddy \
  ghcr.io/rtvkiz/minimal-caddy:latest version
```

## Using images in production

Pin by digest when you need an immutable artifact:

```dockerfile
FROM ghcr.io/rtvkiz/minimal-python@sha256:<digest>
```

Or pin a **major line** (`:3`) to get ongoing patches without being carried across a
breaking upstream release — `:latest` crosses major versions, an exact version tag
never moves forward at all.

Every image also publishes a `:latest-dev` companion with a shell and toolchain,
intended for multi-stage builds and debugging rather than production.

→ **[Tags & pinning](https://minimalcontainers.com/docs/tags)** ·
**[Development variants](https://minimalcontainers.com/docs/dev-variants)**

## How images stay current

Rebuilding an image and upgrading its application are different operations, so they
run on separate loops — neither waits on the other, and neither needs a human.

- **Every 6 hours** — the full catalog is rebuilt against current Wolfi packages, so
  upstream fixes land without any code change.
- **Daily** — upstream releases are detected, checksummed, and opened as auto-merging PRs.
- **Every 6 hours** — transitive CVEs in Go, Ruby, Rust, and Maven dependencies are
  patched into the build recipes.
- **Every build** — guardrails assert that no image can be silently frozen and that the
  catalog matches the build matrix.

→ **[How images stay current](https://minimalcontainers.com/docs/updates)** for the
full model, workflows, and guardrails.

## Understanding vulnerability results

A successful build does not mean an image has zero reported vulnerabilities. Grype
scans every production image; findings are informational and do not block publication.
The catalog shows both raw and VEX-effective counts, and VEX suppressions are
reconciled against every fresh scan so they cannot quietly go stale.

→ **[Reading scan results](https://minimalcontainers.com/docs/vulnerabilities)**

## Build locally

```bash
make python && make test-python        # apko-only image
make caddy-melange && make caddy && make test-caddy   # source-built image
```

Tooling, the project layout, and the full pre-push checklist are in
[CONTRIBUTING.md](CONTRIBUTING.md) and [`docs/onboarding.md`](docs/onboarding.md).

## Contributing

PRs are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), then use [`docs/onboarding.md`](docs/onboarding.md) for the complete image registration and validation checklist. The demand-ranked image backlog is in [`docs/roadmap.md`](docs/roadmap.md).

For security issues, use [GitHub private vulnerability reporting](https://github.com/rtvkiz/minimal/security/advisories/new) instead of opening a public issue.

## License

The repository is MIT-licensed; see [LICENSE](LICENSE). Container images include Wolfi and upstream packages under their respective licenses. Package and license details are available in each image's attached SPDX SBOM.
