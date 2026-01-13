# Minimal Zero-CVE Container Images

Continuous build system for generating minimal container images with zero known CVEs.

## Build Approaches

| Approach | Base | CVE Status | Complexity |
|----------|------|------------|------------|
| **Wolfi/apko** | Wolfi packages | Zero CVE | Medium |
| **Chainguard** | Pre-built images | Zero CVE | Easy |
| **Distroless** | Google distroless | May have CVEs | Easy |
| **Scratch** | From source | Zero CVE | Complex |

## Images

### Wolfi-based (Recommended for Zero CVE)

| Image | Workflow | Description |
|-------|----------|-------------|
| `minimal-nginx-wolfi` | build-apko.yml | nginx on Wolfi |
| `minimal-python-wolfi` | build-apko.yml | Python 3.12 on Wolfi |
| `minimal-jenkins-wolfi` | build-apko.yml | Jenkins on Wolfi |

### Legacy (scratch/distroless)

| Image | Base | Description |
|-------|------|-------------|
| `minimal-busybox` | scratch | BusyBox shell (musl) |
| `minimal-alpine` | scratch | Minimal Alpine filesystem |
| `minimal-nginx` | distroless | nginx web server |
| `minimal-python` | distroless | Python 3.12 runtime |
| `minimal-jenkins` | distroless | Jenkins CI server |

## Usage

### Build Wolfi images (zero CVE)

```bash
# Requires apko: https://github.com/chainguard-dev/apko
apko build nginx/apko/nginx.yaml minimal-nginx-wolfi:latest nginx.tar
docker load < nginx.tar

apko build python/apko/python.yaml minimal-python-wolfi:latest python.tar
docker load < python.tar
```

### Build with Chainguard base images (zero CVE, easiest)

```bash
docker build -f nginx/Dockerfile.chainguard -t minimal-nginx ./nginx
docker build -f python/Dockerfile.chainguard -t minimal-python ./python
docker build -f jenkins/Dockerfile.chainguard -t minimal-jenkins ./jenkins
```

### Build legacy images

```bash
make build          # Build all distroless-based images
make busybox        # Build single image
```

### Scan for CVEs

```bash
make scan           # Scan all images (fails on CRITICAL/HIGH)
make scan-nginx     # Scan single image
trivy image minimal-nginx-wolfi:latest  # Scan Wolfi image
```

## CI/CD Workflows

| Workflow | File | Purpose |
|----------|------|---------|
| Wolfi/apko builds | `build-apko.yml` | Zero CVE images using Wolfi |
| Legacy builds | `build.yml` | Distroless/scratch images |

Both run:
- On push to main
- On pull requests
- Daily at 2am UTC (scheduled rebuild)

## Customization

### nginx
- Wolfi: Edit `nginx/apko/nginx.yaml` to add packages
- Chainguard: Edit `nginx/Dockerfile.chainguard`
- Config: Edit `nginx/nginx.conf`

### Python
- Wolfi: Edit `python/apko/python.yaml` to add packages
- Chainguard: Edit `python/Dockerfile.chainguard`

### Jenkins
- Wolfi: Edit `jenkins/apko/jenkins-base.yaml` for Java base
- Update `JENKINS_VERSION` in workflows/Dockerfiles

```bash
# Run Jenkins with persistent storage
docker run -d -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  minimal-jenkins-wolfi:latest
```

## Why Wolfi?

[Wolfi](https://github.com/wolfi-dev) is a Linux distribution designed for containers:
- Packages are patched for CVEs within 24-48 hours
- Minimal package set reduces attack surface
- Built with apko for reproducible, declarative images
- Maintained by Chainguard
