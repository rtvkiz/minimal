# Minimal: Hardened Container Images

A collection of production-ready container images with **minimal CVEs**, rebuilt daily using [Chainguard's apko](https://github.com/chainguard-dev/apko) and [Wolfi](https://github.com/wolfi-dev) packages. By including only required packages, these images maintain a reduced attack surface and typically have zero or near-zero known vulnerabilities.

## Available Images

| Image | Size | Shell | Use Case |
|-------|------|-------|----------|
| **minimal-python** | ~25MB | No | Python applications, microservices, Lambda-style workloads |
| **minimal-node** | ~50MB | Yes (same as chainguard)| Node.js applications, npm-based builds,  |
| **minimal-go** | ~300MB | No | Go development, CGO-enabled builds |
| **minimal-nginx** | ~15MB | No | Reverse proxy, static file serving, load balancing |
| **minimal-jenkins** | ~250MB | Yes (same as chainguard) | CI/CD automation, Jenkins controller |
| **minimal-httpd** | ~30MB | Yes (same as chainguard) | Apache HTTPD for static sites and reverse proxies |
| **minimal-redis-slim** | ~15MB | No | Redis in-memory data store, caching, message broker |
| **minimal-postgres-slim** | ~150MB | No | PostgreSQL relational database |

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

# Nginx - reverse proxy
docker run -d -p 8080:80 ghcr.io/rtvkiz/minimal-nginx:latest

# Jenkins - start controller
docker run -p 8080:8080 ghcr.io/rtvkiz/minimal-jenkins:latest

# HTTPD - serve static content
docker run -d -p 8080:80 ghcr.io/rtvkiz/minimal-httpd:latest

# Redis - in-memory data store
docker run -d -p 6379:6379 ghcr.io/rtvkiz/minimal-redis-slim:latest

# PostgreSQL - relational database
docker run -d -p 5432:5432 ghcr.io/rtvkiz/minimal-postgres-slim:latest
```

## Image Details

### Python (`minimal-python`)

Shell-less/distroless Python image using Wolfi's pre-built package.

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

Shell-less Node.js image using Wolfi's pre-built package.

| Property | Value |
|----------|-------|
| Node.js | 22.x (LTS) |
| User | `nonroot` (65532) |
| Workdir | `/app` |
| Entrypoint | `/usr/bin/dumb-init -- /usr/bin/node` |
| Shell | None (distroless) |

**Included:** dumb-init (proper signal handling), SSL/TLS. **Not included:** npm (use multi-stage builds), shell.

```dockerfile
FROM ghcr.io/rtvkiz/minimal-node:latest
COPY --chown=nonroot:nonroot dist/ /app/
CMD ["index.js"]
```

### Go (`minimal-go`)

Shell-less Go development image with build tools, using Wolfi's pre-built package.

| Property | Value |
|----------|-------|
| Go | 1.24.x (latest) |
| User | `nonroot` (65532) |
| Workdir | `/app` |
| Entrypoint | `/usr/bin/go` |
| CGO | Enabled |
| Shell | None (distroless) |

**Included:** gcc, make, git, openssh-client, linux-headers. **Not included:** shell.

```dockerfile
FROM ghcr.io/rtvkiz/minimal-go:latest AS builder
COPY . /app/
RUN go build -o /app/myapp .

FROM ghcr.io/rtvkiz/minimal-python:latest  # or scratch
COPY --from=builder /app/myapp /usr/local/bin/
CMD ["/usr/local/bin/myapp"]
```

### Nginx (`minimal-nginx`)

Shell-less Nginx image using Wolfi's pre-built package.

| Property | Value |
|----------|-------|
| Nginx | mainline (Wolfi) |
| User | `nginx` (65532) |
| Workdir | `/` |
| Entrypoint | `/usr/sbin/nginx -g "daemon off;"` |
| Shell | None (distroless) |

**Included:** Nginx mainline, SSL/TLS, PCRE, common modules.

```dockerfile
FROM ghcr.io/rtvkiz/minimal-nginx:latest
COPY nginx.conf /etc/nginx/nginx.conf
COPY --chown=nginx:nginx html/ /var/lib/nginx/html/
```

### Jenkins (`minimal-jenkins`)

Full-featured Jenkins controller with custom jlink JRE. **Includes shell** for plugin compatibility.

| Property | Value |
|----------|-------|
| Jenkins | 2.541.x (LTS) |
| Java | 21 (custom jlink JRE) |
| User | `jenkins` (1000) |
| Workdir | `/var/jenkins_home` |
| Shell | Yes (coreutils, sed, grep, perl) |

**Included:** git, git-lfs, openssh, curl, bash, coreutils, gnupg.

```bash
docker run -d -p 8080:8080 -v jenkins_home:/var/jenkins_home \
  ghcr.io/rtvkiz/minimal-jenkins:latest
```

### HTTPD (`minimal-httpd`)

Minimal Apache HTTPD image using Wolfi's pre-built package.

| Property | Value |
|----------|-------|
| HTTPD | 2.4.x (Wolfi) |
| User | `www-data` (65532) |
| Workdir | `/var/www/localhost/htdocs` |
| Entrypoint | `/usr/sbin/httpd -DFOREGROUND` |
| Shell | Maybe* (see note below) |

**Included:** Apache HTTPD, SSL/TLS, common modules, `/var/www/localhost/htdocs` as default docroot.

```dockerfile
FROM ghcr.io/rtvkiz/minimal-httpd:latest
COPY --chown=www-data:www-data ./public /var/www/localhost/htdocs
```

**Note on `minimal-httpd` and `/bin/sh`:** Depending on upstream Wolfi package dependencies, Apache HTTPD images may include a minimal `/bin/sh`. Our CI gates `minimal-httpd` on **CVE scan + successful startup**, and treats shell presence as **informational**. This is what the `Shell` column `Yes*` refers to above.

### Postgres Slim (`minimal-postgres-slim`)

Minimal PostgreSQL image using Wolfi's pre-built package.

| Property | Value |
|----------|-------|
| PostgreSQL | 18.x (Wolfi) |
| User | `postgres` (70) |
| Workdir | `/` |
| Entrypoint | `/usr/bin/postgres` |
| Shell | No |

**Included:** PostgreSQL server, psql client, contrib extensions, pgaudit, ICU, LLVM JIT, SSL/TLS.

```bash
docker run -d -p 5432:5432 -v pgdata:/var/lib/postgresql/data \
  ghcr.io/rtvkiz/minimal-postgres-slim:latest
```

### Redis Slim (`minimal-redis-slim`)

Minimal Redis image built from source via melange.

| Property | Value |
|----------|-------|
| Redis | 8.4.x (Wolfi) |
| User | `redis` (65532) |
| Workdir | `/` |
| Entrypoint | `/usr/bin/redis-server` |
| Shell | No |

**Included:** Redis server, redis-cli, SSL/TLS.

```bash
docker run -d -p 6379:6379 -v redis_data:/data \
  ghcr.io/rtvkiz/minimal-redis-slim:latest
```

## How Images Are Built

```
┌─────────────────────────────────────────────────────────────────────┐
│                         BUILD PIPELINE                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Package Source            Image Assembly           Verification    │
│  ──────────────           ──────────────           ──────────────   │
│                                                                     │
│  ┌─────────────┐          ┌────────────┐          ┌────────────┐   │
│  │   Wolfi     │─────────▶│    apko    │─────────▶│   Trivy    │   │
│  │ (pre-built) │  install │ (OCI image)│  scan    │ (CVE gate) │   │
│  │ Python, Go, │          │            │          │            │   │
│  │ Node, etc.  │          │            │          │            │   │
│  └─────────────┘          └─────┬──────┘          └─────┬──────┘   │
│                                 │                       │          │
│  ┌─────────────┐                │                       ▼          │
│  │   melange   │────────────────┘              ┌────────────────┐  │
│  │ (Jenkins    │  build from                   │ cosign + SBOM  │  │
│  │  only)      │  source                       │ (sign & publish│  │
│  └─────────────┘                               └────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Package Sources

| Image | Source | Build Time |
|-------|--------|------------|
| Python | Wolfi pre-built package | ~30 sec |
| Go | Wolfi pre-built package | ~30 sec |
| Node.js | Wolfi pre-built package | ~30 sec |
| Nginx | Wolfi pre-built package | ~30 sec |
| HTTPD | Wolfi pre-built package | ~30 sec |
| Postgres Slim | Wolfi pre-built package | ~30 sec |
| Redis Slim | Source build via melange | ~5 min |
| Jenkins | jlink JRE + WAR via melange | ~10 min |

### Update Schedule

Images are rebuilt automatically:

| Trigger | When | Purpose |
|---------|------|---------|
| **Scheduled** | Daily at 2:00 AM UTC | Pick up latest CVE patches from Wolfi |
| **Push** | On merge to `main` | Deploy configuration changes |
| **Manual** | Workflow dispatch | Emergency rebuilds |

All builds must pass a CVE gate (no CRITICAL/HIGH severity vulnerabilities) before publishing.

### Version Updates

| Type | Frequency | Action |
|------|-----------|--------|
| **Patch versions** | Automatic (daily rebuild) | Wolfi packages updated automatically |
| **Minor/major versions** | Weekly check | PR opened for review (Python, Go, Node.js) |
| **Jenkins LTS** | Daily check | PR opened for review |

## Build Locally

```bash
# Prerequisites
go install chainguard.dev/apko@latest
go install chainguard.dev/melange@latest  # only needed for Jenkins
brew install trivy  # or: apt install trivy

# Build all images
make build

# Build specific image
make python
make node
make go
make nginx
make jenkins
make httpd
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
├── python/
│   └── apko/python.yaml      # Image definition (uses Wolfi pkg)
├── node/
│   └── apko/node.yaml        # Image definition (uses Wolfi pkg)
├── go/
│   └── apko/go.yaml          # Image definition (uses Wolfi pkg)
├── nginx/
│   └── apko/nginx.yaml       # Image definition (uses Wolfi pkg)
├── jenkins/
│   ├── apko/jenkins.yaml
│   └── melange.yaml          # Source build recipe (jlink JRE)
├── httpd/
│   └── apko/httpd.yaml       # Image definition (uses Wolfi pkg)
├── redis-slim/
│   ├── apko/redis.yaml        # Image definition
│   └── melange.yaml           # Source build recipe (Redis)
├── postgres-slim/
│   └── apko/postgres.yaml     # Image definition (uses Wolfi pkg)
├── .github/workflows/
│   ├── build.yml             # Daily CI pipeline
│   ├── update-jenkins.yml    # Jenkins version updates
│   ├── update-redis.yml      # Redis version updates
│   └── update-wolfi-packages.yml  # Wolfi package updates
└── Makefile
```

## Security Features

- **CVE gate** - Builds fail if any CRITICAL/HIGH vulnerabilities detected
- **Signed images** - All images signed with [cosign](https://github.com/sigstore/cosign) keyless signing
- **SBOM generation** - Full software bill of materials in SPDX format
- **Non-root users** - All images run as non-root by default
- **Minimal attack surface** - Only essential packages included
- **Shell-less images** - Python, Node.js, Go, and Nginx have no shell
- **Reproducible builds** - Declarative apko configurations

## License

MIT
