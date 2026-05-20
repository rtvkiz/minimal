# Security Policy

## Supported Versions

Only the latest version of each image is supported with security updates. Images are rebuilt daily at 2am UTC to incorporate the latest CVE patches from [Wolfi](https://wolfi.dev).

| Image | Supported |
|-------|-----------|
| Latest tags (`ghcr.io/rtvkiz/minimal-*:latest`) | ✅ |
| Versioned tags | ✅ (latest version only) |
| Older versions | ❌ |

### Dev variants (`-dev` tags)

Some images publish a `:latest-dev` companion tag (e.g. `minimal-ruby:latest-dev`) that adds a shell, package manager, compiler toolchain, and language-specific build dependencies on top of the prod runtime. They are intended for CI build stages and in-pod debugging — **not for production deployment**.

Dev variants:

- Share the same source build as the prod image (same runtime, same curated gem/dep set)
- Are rebuilt on the same daily cadence
- Are signed and SBOM/SLSA attested using the same pipeline as prod
- **Are not tracked on the public CVE dashboard** — they intentionally ship a larger attack surface, and our daily rebuild keeps their base packages current rather than us chasing CVE counts

Use the prod tag (`:latest`) for runtime workloads. Use the dev tag (`:latest-dev`) as a multi-stage builder, then `COPY --from=build` into the prod image.

## Reporting a Vulnerability

If you discover a security vulnerability in this project's **build infrastructure, workflows, or container configurations**, please report it responsibly:

1. **Do NOT open a public GitHub issue** for security vulnerabilities.
2. Use [GitHub's private vulnerability reporting](https://github.com/rtvkiz/minimal/security/advisories/new) to submit your report.
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Affected images/workflows
   - Potential impact

## Response Timeline

- **Acknowledgement**: Within 48 hours
- **Initial assessment**: Within 1 week
- **Fix deployment**: Dependent on severity
  - Critical: Within 24 hours
  - High: Within 1 week
  - Medium/Low: Next scheduled release

## Security Measures

This project implements the following security practices:

- **Image signing**: All published images are signed with [cosign](https://github.com/sigstore/cosign) keyless signatures
- **Vulnerability scanning**: Every image is scanned with [Grype](https://github.com/anchore/grype) on every build
- **SBOM generation**: Software Bill of Materials generated for every image
- **Minimal base images**: Built on [Wolfi](https://wolfi.dev), a security-focused Linux undistro
- **Daily rebuilds**: Automated daily rebuilds to incorporate upstream CVE patches
- **Dependency updates**: Automated version tracking and update PRs for all upstream dependencies
- **Supply chain hardening**: GitHub Actions pinned to SHA digests, least-privilege permissions

## Verifying Image Signatures

Every published image is signed with [cosign](https://github.com/sigstore/cosign) keyless signatures (sigstore + GitHub OIDC). Every image also carries an SPDX SBOM attestation and a SLSA v1.0 build provenance attestation, all verifiable against the public Rekor transparency log.

**Requires cosign v2.6 or later** (v3.x recommended). Earlier versions cannot read attestations stored via the OCI 1.1 referrers API and will report "no signatures found" against valid images. Upgrade with `brew upgrade cosign` or download from the [cosign releases page](https://github.com/sigstore/cosign/releases).

### 1. Verify the cosign signature

```bash
cosign verify \
  --certificate-identity-regexp='https://github.com/rtvkiz/minimal/' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/rtvkiz/minimal-python:latest
```

### 2. Verify the SBOM attestation (SPDX)

```bash
cosign verify-attestation \
  --type spdxjson \
  --certificate-identity-regexp='https://github.com/rtvkiz/minimal/' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/rtvkiz/minimal-python:latest \
  | jq -r '.payload | @base64d | fromjson | .predicate' \
  > python-sbom.spdx.json
```

The same SBOM is also reachable via the legacy attachment:

```bash
cosign download sbom ghcr.io/rtvkiz/minimal-python:latest > python-sbom.spdx.json
```

### 3. Verify the SLSA build provenance

Using the GitHub CLI (recommended — checks the built-in attestation store):

```bash
gh attestation verify \
  oci://ghcr.io/rtvkiz/minimal-python:latest \
  --owner rtvkiz
```

Or using cosign directly (verifies against the registry-attached attestation):

```bash
cosign verify-attestation \
  --type slsaprovenance1 \
  --certificate-identity-regexp='https://github.com/rtvkiz/minimal/' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/rtvkiz/minimal-python:latest
```

The provenance predicate identifies the exact GitHub Actions workflow, commit SHA, and build inputs that produced the image — sufficient for [SLSA Level 3](https://slsa.dev/spec/v1.0/levels#build-l3).
