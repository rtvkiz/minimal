# Minimal Zero-CVE Container Images

Continuous build system for generating minimal container images with zero known CVEs.

## Images

| Image | Base | Description |
|-------|------|-------------|
| `minimal-busybox` | scratch | BusyBox shell (musl) |
| `minimal-alpine` | scratch | Minimal Alpine filesystem |
| `minimal-nginx` | distroless | nginx web server |
| `minimal-python` | distroless | Python 3.12 runtime |
| `minimal-jenkins` | distroless | Jenkins CI server (Java 17) |

## Usage

### Build locally

```bash
make build          # Build all images
make busybox        # Build single image
```

### Scan for CVEs

```bash
make scan           # Scan all images (fails on CRITICAL/HIGH)
make scan-nginx     # Scan single image
```

### Push to registry

```bash
export REGISTRY=ghcr.io
export OWNER=your-username
make push
```

## CI/CD

GitHub Actions workflow runs:
- On push to main
- On pull requests
- Daily at 2am UTC (scheduled rebuild)

Build fails if Trivy detects CRITICAL or HIGH severity CVEs.

## Customization

### nginx
Edit `nginx/nginx.conf` for custom configuration.

### Python
Uncomment the `requirements.txt` lines in `python/Dockerfile` to add pip packages.

For absolute minimal Python (built from source), use:
```bash
docker build -f python/Dockerfile.from-source -t minimal-python ./python
```

### Jenkins
Run with persistent volume:
```bash
docker run -d -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  minimal-jenkins:latest
```

Note: Plugins must be installed via Jenkins UI or by pre-baking them into a custom image.
