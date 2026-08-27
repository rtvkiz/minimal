<p align="center">
  <img src="assets/logo.svg" alt="minimal — hardened container images" width="600">
</p>

<p align="center">
  <strong>106 small, hardened container images. Free, MIT-licensed, signed, and rebuilt every six hours.</strong>
</p>

<p align="center">
  <a href="https://minimalcontainers.com"><strong>Browse the catalog →</strong></a>
</p>

<p align="center">
  <a href="https://github.com/rtvkiz/minimal/actions/workflows/build.yml"><img src="https://github.com/rtvkiz/minimal/actions/workflows/build.yml/badge.svg" alt="Build status"></a>
  <img src="https://img.shields.io/badge/Images-106-0d9488" alt="Images: 106">
  <a href="https://slsa.dev/spec/v1.0/levels#build-l3"><img src="https://img.shields.io/badge/SLSA-Level_3-0d9488" alt="SLSA Level 3"></a>
  <img src="https://img.shields.io/badge/Arch-amd64_%7C_arm64-0d9488" alt="Architectures: amd64 and arm64">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
</p>

---

## Quick start

```bash
docker pull ghcr.io/rtvkiz/minimal-python:latest
```

No account needed. Every image has a `:latest-dev` companion with a shell and
toolchain for debugging and multi-stage builds.

```bash
docker run --rm -p 8080:80 ghcr.io/rtvkiz/minimal-nginx:latest
docker run --rm -p 6379:6379 ghcr.io/rtvkiz/minimal-redis-slim:latest
```

**[Find an image →](https://minimalcontainers.com/images)** — all 106, with live
sizes and CVE counts.

## Verify what you pulled

```bash
gh attestation verify oci://ghcr.io/rtvkiz/minimal-python:latest --owner rtvkiz
```

Every published image carries a keyless Cosign signature, an SPDX SBOM, and SLSA
v1.0 build provenance tied to the workflow and commit that produced it.

**[Signature, SBOM, and provenance commands →](.github/SECURITY.md)**

## What makes these different

- **Small and shell-less** — production images ship no `/bin/sh` where the
  application permits it, and run as non-root by default.
- **Built from source** — public, readable `melange` recipes, not a repackaged
  base image. Native `amd64` and `arm64`.
- **Never stale** — rebuilt every six hours against current Wolfi packages;
  upstream releases and transitive CVEs open their own auto-merging PRs.
- **Verifiable** — signed, with SBOM and provenance attached to every digest.

No vendor SLA, support contract, or FedRAMP/FIPS/STIG accreditation. The
signatures, SBOMs, and provenance help with verification and audits; they do not
replace those programs.

## Pinning

```dockerfile
FROM ghcr.io/rtvkiz/minimal-python@sha256:<digest>   # immutable
FROM ghcr.io/rtvkiz/minimal-python:3                 # patched, no major jumps
```

`:latest` crosses major versions; an exact version tag never moves at all.

**[Tags and pinning →](https://minimalcontainers.com/docs/tags)**

## On vulnerability counts

A green build does not mean zero findings. Grype scans every production image and
results are informational — they do not block publication. The catalog shows raw
and VEX-effective counts side by side, and suppressions are reconciled against
each fresh scan so they cannot quietly go stale.

**[Reading scan results →](https://minimalcontainers.com/docs/vulnerabilities)**

## Contributing

```bash
make python && make test-python                       # apko-only image
make caddy-melange && make caddy && make test-caddy   # source-built image
```

PRs welcome. [CONTRIBUTING.md](CONTRIBUTING.md) covers tooling and layout;
[`docs/onboarding.md`](docs/onboarding.md) is the complete checklist for adding an
image; [`docs/roadmap.md`](docs/roadmap.md) is the demand-ranked backlog.

Security issues: please use
[private vulnerability reporting](https://github.com/rtvkiz/minimal/security/advisories/new)
rather than a public issue.

## License

MIT — see [LICENSE](LICENSE). Images include Wolfi and upstream packages under
their own licenses; each image's SPDX SBOM has the details.
