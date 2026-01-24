# Minimal Zero-CVE Python Image

A minimal Python container image with **zero known CVEs**, built daily using [Chainguard's apko](https://github.com/chainguard-dev/apko) and [Wolfi](https://github.com/wolfi-dev) packages.

## Features

- **Zero CVEs** - Wolfi packages are patched within 24-48 hours of disclosure
- **Minimal footprint** - Only essential packages (~29MB compressed)
- **Multi-arch** - Supports x86_64 and aarch64
- **Daily rebuilds** - Automatic CI builds ensure latest security patches
- **Reproducible** - Declarative apko builds guarantee consistency
- **SBOM included** - Full software bill of materials generated

## Quick Start

### Prerequisites

```bash
# Install apko
go install chainguard.dev/apko@latest
# or: brew install apko

# Install trivy for scanning
brew install trivy

# Docker for loading/testing images
```

### Build Locally

```bash
make build      # Build multi-arch image
make scan       # Verify zero CVEs
make test       # Run Python tests
```

### Use the Image

```bash
# Run Python interactively
docker run -it ghcr.io/YOUR_USER/minimal-python:latest

# Run a script
docker run --rm -v $(pwd):/app ghcr.io/YOUR_USER/minimal-python:latest /app/script.py

# Install packages (as root in Dockerfile)
FROM ghcr.io/YOUR_USER/minimal-python:latest
USER root
RUN pip install requests flask
USER python
```

## How It Works

```
┌─────────────────────┐     ┌──────────────┐     ┌─────────────────┐
│  Wolfi Packages     │ ──▶ │    apko      │ ──▶ │   OCI Image     │
│  (CVE patched 24h)  │     │ (declarative)│     │   (zero CVE)    │
└─────────────────────┘     └──────────────┘     └─────────────────┘
         │                                               │
         │                                               ▼
         │                                    ┌─────────────────┐
         └───── melange (custom pkgs) ──────▶│ Custom Packages │
                                              └─────────────────┘
```

### Components

| Component | Purpose |
|-----------|---------|
| **[Wolfi](https://wolfi.dev)** | Linux distro for containers, rapid CVE patching |
| **[apko](https://github.com/chainguard-dev/apko)** | Declarative OCI image builder |
| **[melange](https://github.com/chainguard-dev/melange)** | Build custom APK packages (optional) |
| **[Trivy](https://trivy.dev)** | Vulnerability scanner |

## Image Details

### Included Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `python-3.12` | Latest | Python interpreter |
| `py3.12-pip` | Latest | Package installer |
| `ca-certificates-bundle` | Latest | TLS/SSL certificates |
| `libstdc++` | Latest | C++ standard library |
| `wolfi-baselayout` | Latest | Base filesystem layout |

### Configuration

- **User**: `python` (uid: 65532)
- **Workdir**: `/app`
- **Entrypoint**: `/usr/bin/python3.12`
- **Environment**:
  - `PYTHONDONTWRITEBYTECODE=1`
  - `PYTHONUNBUFFERED=1`
  - `PYTHONFAULTHANDLER=1`

## Customization

### Change Python Version

Edit `python/apko/python.yaml`:

```yaml
contents:
  packages:
    - python-3.13        # Change to 3.11, 3.12, or 3.13
    - python-3.13-base
    - py3.13-pip
```

### Add System Packages

```yaml
contents:
  packages:
    - python-3.12
    - py3.12-pip
    - git              # Add git
    - curl             # Add curl
    - postgresql-16    # Add PostgreSQL client
```

### Build Custom Packages with Melange

For packages not in Wolfi, use melange to build custom APKs:

```bash
# See melange/ directory for examples
melange build melange/my-package.yaml --arch x86_64
```

## CI/CD

The GitHub Actions workflow runs:

- **On push** to main branch
- **On pull requests** for validation
- **Daily at 2am UTC** to get latest CVE patches

Each build:
1. Builds the image with apko
2. Scans with Trivy for CRITICAL/HIGH CVEs
3. Publishes only if zero vulnerabilities found
4. Uploads SBOM and scan results to GitHub Security

## Project Structure

```
minimal/
├── python/
│   └── apko/
│       └── python.yaml     # apko image definition
├── melange/                 # (optional) Custom package builds
│   └── example.yaml
├── .github/
│   └── workflows/
│       └── build.yml       # Daily CI build
├── Makefile                # Local build commands
└── README.md
```

## Why Wolfi + apko?

| Feature | Traditional Dockerfile | Wolfi/apko |
|---------|----------------------|------------|
| CVE patching | Manual updates | Auto (24-48h) |
| Reproducibility | Varies | Guaranteed |
| Image size | Often bloated | Minimal |
| Supply chain | Complex | Signed packages |
| Build speed | Slow (layers) | Fast (parallel) |
| SBOM | Manual | Automatic |

## License

MIT
