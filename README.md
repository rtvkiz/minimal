# Minimal: Hardened Container Images

A collection of production-ready container images with **minimal CVEs**, rebuilt daily using [Chainguard's apko](https://github.com/chainguard-dev/apko) and [Wolfi](https://github.com/wolfi-dev) packages. By including only required packages, these images maintain a reduced attack surface and typically have zero or near-zero known vulnerabilities.

## Available Images

| Image | Pull Command | Shell | Use Case |
|-------|--------------|-------|----------|
| **Python** | `docker pull ghcr.io/rtvkiz/minimal-python:latest` | No | Python apps, microservices |
| **Node.js** | `docker pull ghcr.io/rtvkiz/minimal-node:latest` | Yes | Node.js apps, JavaScript |
| **Bun** | `docker pull ghcr.io/rtvkiz/minimal-bun:latest` | No | Fast JavaScript/TypeScript runtime |
| **Go** | `docker pull ghcr.io/rtvkiz/minimal-go:latest` | No | Go development, CGO builds |
| **Nginx** | `docker pull ghcr.io/rtvkiz/minimal-nginx:latest` | No | Reverse proxy, static files |
| **HTTPD** | `docker pull ghcr.io/rtvkiz/minimal-httpd:latest` | Maybe* | Apache web server |
| **Jenkins** | `docker pull ghcr.io/rtvkiz/minimal-jenkins:latest` | Yes | CI/CD automation |
| **Redis-slim** | `docker pull ghcr.io/rtvkiz/minimal-redis-slim:latest` | No | In-memory data store |
| **PostgreSQL-slim** | `docker pull ghcr.io/rtvkiz/minimal-postgres-slim:latest` | No | Relational database |

*\*HTTPD, Jenkins,Node.js may include shell(sh,busybox) via transitive Wolfi dependencies. CI treats shell presence as informational.*

## Why This Matters

Container vulnerabilities are a top attack vector. Most base images ship with dozens of known CVEs that take weeks or months to patch:

```
Traditional images:     Your containers:
┌───────────────────┐    ┌──────────────────┐
│ debian:latest     │    │ minimal-python   │
│ 127 CVEs          │    │ 0-5 CVEs         │
│ Patched: ~30 days │    │ Patched: <48 hrs │
└───────────────────┘    └──────────────────┘
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

# Bun - fast JavaScript runtime
docker run --rm ghcr.io/rtvkiz/minimal-bun:latest --version

# Go - build your app
docker run --rm -v $(pwd):/app -w /app ghcr.io/rtvkiz/minimal-go:latest build -o /tmp/app .

# Nginx - reverse proxy
docker run -d -p 8080:80 ghcr.io/rtvkiz/minimal-nginx:latest

# HTTPD - serve static content
docker run -d -p 8080:80 ghcr.io/rtvkiz/minimal-httpd:latest

# Jenkins - CI/CD controller
docker run -d -p 8080:8080 -v jenkins_home:/var/jenkins_home ghcr.io/rtvkiz/minimal-jenkins:latest

# Redis - in-memory data store
docker run -d -p 6379:6379 ghcr.io/rtvkiz/minimal-redis-slim:latest

# PostgreSQL - relational database
docker run -d -p 5432:5432 -v pgdata:/var/lib/postgresql/data ghcr.io/rtvkiz/minimal-postgres-slim:latest
```

## Image Specifications

| Image | Version | User | Entrypoint | Workdir |
|-------|---------|------|------------|---------|
| Python | 3.13.x | nonroot (65532) | `/usr/bin/python3` | `/app` |
| Node.js | 22.x LTS | nonroot (65532) | `/usr/bin/dumb-init -- /usr/bin/node` | `/app` |
| Bun | latest | nonroot (65532) | `/usr/bin/bun` | `/app` |
| Go | 1.25.x | nonroot (65532) | `/usr/bin/go` | `/app` |
| Nginx | mainline | nginx (65532) | `/usr/sbin/nginx -g "daemon off;"` | `/` |
| HTTPD | 2.4.x | www-data (65532) | `/usr/sbin/httpd -DFOREGROUND` | `/var/www/localhost/htdocs` |
| Jenkins | 2.541.x LTS | jenkins (1000) | `tini -- java -jar jenkins.war` | `/var/jenkins_home` |
| Redis | 8.4.x | redis (65532) | `/usr/bin/redis-server` | `/` |
| PostgreSQL | 18.x | postgres (70) | `/usr/bin/postgres` | `/` |

## How Images Are Built

```
┌─────────────────────────────────────────────────────────────────────┐
│                         BUILD PIPELINE                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Package Source            Image Assembly           Verification    │
│  ──────────────           ──────────────           ──────────────   │
│                                                                     │
│  ┌─────────────┐          ┌────────────┐          ┌─────────────┐   │
│  │   Wolfi     │─────────▶│    apko    │─────────▶│   Trivy     │   │
│  │ (pre-built) │  install │ (OCI image)│  scan    │ (CVE gate)  │   │
│  │ Python, Go, │          │            │          │             │   │
│  │ Node, etc.  │          │            │          │             │   │
│  └─────────────┘          └─────┬──────┘          └─────┬───────┘   │
│                                 │                       │           │
│  ┌─────────────┐                │                       ▼           │
│  │   melange   │────────────────┘              ┌─────────────────┐  │
│  │ (Jenkins,   │  build from                   │ cosign + SBOM   │  │
│  │  Redis)     │  source                       │ (sign & publish │  │
│  └─────────────┘                               └─────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Update Schedule

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
go install chainguard.dev/melange@latest  # needed for Jenkins, Redis
brew install trivy  # or: apt install trivy

# Build all images
make build

# Build specific image
make python
make node
make bun
make go
make nginx
make httpd
make jenkins
make redis-slim
make postgres-slim

# Scan for CVEs
make scan

# Run tests
make test
```

## Project Structure

```
minimal/
├── python/apko/python.yaml       # Python image (Wolfi pkg)
├── node/apko/node.yaml           # Node.js image (Wolfi pkg)
├── bun/apko/bun.yaml             # Bun image (Wolfi pkg)
├── go/apko/go.yaml               # Go image (Wolfi pkg)
├── nginx/apko/nginx.yaml         # Nginx image (Wolfi pkg)
├── httpd/apko/httpd.yaml         # HTTPD image (Wolfi pkg)
├── jenkins/
│   ├── apko/jenkins.yaml         # Jenkins image
│   └── melange.yaml              # jlink JRE build
├── redis-slim/
│   ├── apko/redis.yaml           # Redis image
│   └── melange.yaml              # Redis source build
├── postgres-slim/apko/postgres.yaml  # PostgreSQL image (Wolfi pkg)
├── .github/workflows/
│   ├── build.yml                 # Daily CI pipeline
│   ├── update-jenkins.yml        # Jenkins version updates
│   ├── update-redis.yml          # Redis version updates
│   └── update-wolfi-packages.yml # Wolfi package updates
├── Makefile
└── LICENSE
```

## Security Features

- **CVE gate** - Builds fail if any CRITICAL/HIGH vulnerabilities detected
- **Signed images** - All images signed with [cosign](https://github.com/sigstore/cosign) keyless signing
- **SBOM generation** - Full software bill of materials in SPDX format
- **Non-root users** - All images run as non-root by default
- **Minimal attack surface** - Only essential packages included
- **Shell-less images** - Most images have no shell
- **Reproducible builds** - Declarative apko configurations

## Verify Image Signatures

All images are signed with [cosign](https://github.com/sigstore/cosign) keyless signing via Sigstore. To verify:

```bash
cosign verify \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp https://github.com/rtvkiz/minimal/ \
  ghcr.io/rtvkiz/minimal-python:latest
```

Replace `minimal-python` with any image name. A successful output confirms the image was built by this repository's CI pipeline and hasn't been tampered with.

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

### Third-Party Packages

Container images include packages from [Wolfi](https://github.com/wolfi-dev) and other sources, each with their own licenses (Apache-2.0, MIT, GPL, LGPL, BSD, etc.). Full license information is included in each image's SBOM:

```bash
# View package licenses in an image
cosign download sbom ghcr.io/rtvkiz/minimal-python:latest | jq '.packages[].licenseConcluded'
```
