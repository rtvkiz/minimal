# Minimal: Hardened Container Images

A collection of production-ready container images with **minimal CVEs**, rebuilt daily using [Chainguard's apko](https://github.com/chainguard-dev/apko) and [Wolfi](https://github.com/wolfi-dev) packages. By including only required packages, these images maintain a reduced attack surface and typically have zero or near-zero known vulnerabilities.

## Available Images

| Image | Size | Shell | Use Case |
|-------|------|-------|----------|
| **minimal-python** | ~25MB | No | Python applications, microservices, Lambda-style workloads |
| **minimal-node** | ~50MB | Yes | Node.js applications, npm-based builds |
| **minimal-go** | ~300MB | Yes | Go development, CGO-enabled builds |
| **minimal-jenkins** | ~250MB | Yes | CI/CD automation, Jenkins controller |

## Why This Matters

Container vulnerabilities are a top attack vector. Most base images ship with dozens of known CVEs that take weeks or months to patch:

```
Traditional images:     Your containers:
┌──────────────────┐    ┌──────────────────┐
│ debian:latest    │    │ minimal-python   │
│ 127 CVEs         │    │ 0-5 CVEs         │
│ Patched: ~30 days│    │ Patched: <48 hrs │
└──────────────────┘    └──────────────────┘
```

**Impact:**
- Pass security audits and compliance requirements (SOC2, FedRAMP, PCI-DSS)
- Reduce attack surface with minimal, distroless images
- Get CVE patches within 24-48 hours of disclosure (vs weeks for Debian/Ubuntu)
- Cryptographically signed images with full SBOM for supply chain security

## Quick Start

```bash
# Python - run your app
docker run --rm -v $(pwd):/app ghcr.io/rtvkiz/minimal-python:latest /app/main.py

# Node.js - run your app
docker run --rm -v $(pwd):/app -w /app ghcr.io/rtvkiz/minimal-node:latest index.js

# Go - build and run
docker run --rm -v $(pwd):/app -w /app ghcr.io/rtvkiz/minimal-go:latest build -o /tmp/app .

# Jenkins - start controller
docker run -p 8080:8080 ghcr.io/rtvkiz/minimal-jenkins:latest
```

## Image Details

### Python (`minimal-python`)

Shell-less/distroless Python image built from source.

| Property | Value |
|----------|-------|
| Python | 3.13.x (latest) |
| User | `nonroot` (65532) |
| Workdir | `/app` |
| Entrypoint | `/usr/bin/python3` |
| Shell | None (distroless) |

**Included:** Full stdlib, SSL/TLS, sqlite, zlib, bz2, lzma. **Not included:** pip, shell, package managers.

```dockerfile
FROM ghcr.io/rtvkiz/minimal-python:latest
COPY --chown=nonroot:nonroot app.py /app/
CMD ["/app/app.py"]
```

### Node.js (`minimal-node`)

Lightweight Node.js image using Wolfi's pre-built package.

| Property | Value |
|----------|-------|
| Node.js | 22.x (LTS) |
| User | `nonroot` (65532) |
| Workdir | `/app` |
| Entrypoint | `/usr/bin/dumb-init -- /usr/bin/node` |
| Shell | busybox |

**Included:** npm, dumb-init (proper signal handling), SSL/TLS.

```dockerfile
FROM ghcr.io/rtvkiz/minimal-node:latest
COPY --chown=nonroot:nonroot package*.json /app/
RUN npm ci --only=production
COPY --chown=nonroot:nonroot . /app/
CMD ["index.js"]
```

### Go (`minimal-go`)

Full Go development image with build tools, built from source.

| Property | Value |
|----------|-------|
| Go | 1.24.x (latest) |
| User | `nonroot` (65532) |
| Workdir | `/app` |
| Entrypoint | `/usr/bin/go` |
| CGO | Enabled |

**Included:** gcc, make, git, openssh-client, linux-headers.

```dockerfile
FROM ghcr.io/rtvkiz/minimal-go:latest AS builder
COPY . /app/
RUN go build -o /app/myapp .

FROM ghcr.io/rtvkiz/minimal-python:latest  # or scratch
COPY --from=builder /app/myapp /usr/local/bin/
CMD ["/usr/local/bin/myapp"]
```

### Jenkins (`minimal-jenkins`)

Full-featured Jenkins controller with custom jlink JRE.

| Property | Value |
|----------|-------|
| Jenkins | 2.541.x (LTS) |
| Java | 21 (custom jlink JRE) |
| User | `jenkins` (1000) |
| Workdir | `/var/jenkins_home` |

**Included:** git, git-lfs, openssh, curl, bash, coreutils, gnupg.

```bash
docker run -d -p 8080:8080 -v jenkins_home:/var/jenkins_home \
  ghcr.io/rtvkiz/minimal-jenkins:latest
```

## How Images Are Built

```
┌─────────────────────────────────────────────────────────────────────┐
│                         BUILD PIPELINE                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Source Code          Package Build           Image Assembly        │
│  ────────────         ─────────────           ──────────────        │
│                                                                     │
│  ┌─────────┐         ┌───────────┐           ┌────────────┐        │
│  │ Python  │──────▶  │  melange  │──────────▶│            │        │
│  │ Go      │  build  │ (APK pkg) │   assemble│    apko    │        │
│  │ Jenkins │  source └───────────┘           │ (OCI image)│        │
│  └─────────┘              │                  │            │        │
│                           ▼                  │            │        │
│  ┌─────────┐         ┌───────────┐           │            │        │
│  │ Node.js │─────────│   Wolfi   │──────────▶│            │        │
│  └─────────┘  use    │ (pre-built)│          └─────┬──────┘        │
│               pkg    └───────────┘                 │               │
│                                                    ▼               │
│                                           ┌────────────────┐       │
│                                           │  Trivy Scan    │       │
│                                           │  (CVE gate)    │       │
│                                           └────────┬───────┘       │
│                                                    │               │
│                                                    ▼               │
│                                           ┌────────────────┐       │
│                                           │ cosign + SBOM  │       │
│                                           │ (sign & publish)│      │
│                                           └────────────────┘       │
└─────────────────────────────────────────────────────────────────────┘
```

### Package Sources

| Image | Source | Build Time |
|-------|--------|------------|
| Python | Built from source via melange | ~15 min |
| Go | Built from source via melange | ~20 min |
| Jenkins | jlink JRE + WAR via melange | ~10 min |
| Node.js | Wolfi pre-built package | ~30 sec |

### Update Schedule

Images are rebuilt automatically:

| Trigger | When | Purpose |
|---------|------|---------|
| **Scheduled** | Daily at 2:00 AM UTC | Pick up latest CVE patches from Wolfi |
| **Push** | On merge to `main` | Deploy configuration changes |
| **Manual** | Workflow dispatch | Emergency rebuilds |

All builds must pass a CVE gate (no CRITICAL/HIGH severity vulnerabilities) before publishing.

## Build Locally

```bash
# Prerequisites
go install chainguard.dev/apko@latest
go install chainguard.dev/melange@latest
brew install trivy  # or: apt install trivy

# Build all images
make build

# Build specific image
make python
make node
make go
make jenkins

# Scan for CVEs
make scan

# Run tests
make test
```

## Project Structure

```
minimal/
├── python/
│   ├── apko/python.yaml      # Image definition
│   └── melange.yaml          # Source build recipe
├── node/
│   └── apko/node.yaml        # Image definition (uses Wolfi pkg)
├── go/
│   ├── apko/go.yaml
│   └── melange.yaml
├── jenkins/
│   ├── apko/jenkins.yaml
│   └── melange.yaml
├── .github/workflows/
│   └── build.yml             # Daily CI pipeline
└── Makefile
```

## Comparison with Alternatives

| Feature | Debian/Ubuntu | Alpine | Distroless | Chainguard | **Minimal** |
|---------|--------------|--------|------------|------------|-------------|
| CVE patch time | ~30 days | ~14 days | ~7 days | <48 hours | <48 hours |
| Typical CVE count | 50-200 | 10-50 | 0-10 | 0-5 | 0-5 |
| Image size | Large | Small | Small | Small | Small |
| Cost | Free | Free | Free | Paid | Free |
| Signed images | No | No | Yes | Yes | Yes |
| SBOM | Manual | Manual | Yes | Yes | Yes |
| Customizable | Limited | Limited | No | Limited | Full |

## Security Features

- **CVE gate** - Builds fail if any CRITICAL/HIGH vulnerabilities detected
- **Signed images** - All images signed with [cosign](https://github.com/sigstore/cosign) keyless signing
- **SBOM generation** - Full software bill of materials in SPDX format
- **Non-root users** - All images run as non-root by default
- **Minimal attack surface** - Only essential packages included
- **Reproducible builds** - Declarative apko configurations

## License

MIT
