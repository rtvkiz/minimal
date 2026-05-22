<p align="center">
  <img src="assets/logo.svg" alt="minimal — hardened container images" width="600">
</p>

<p align="center">
  Small, hardened container images, free and MIT-licensed.<br>
  Built from source with Chainguard's <a href="https://github.com/chainguard-dev/apko">apko</a> and <a href="https://github.com/wolfi-dev">Wolfi</a> packages, rebuilt every six hours.<br>
  Every image is cosign-signed, ships an SPDX SBOM attestation, and carries SLSA Level 3 build provenance. You can verify all of it without an account.
</p>

<p align="center">
  <a href="https://github.com/rtvkiz/minimal/actions/workflows/build.yml"><img src="https://github.com/rtvkiz/minimal/actions/workflows/build.yml/badge.svg" alt="Build status"></a>
  <a href="https://rtvkiz.github.io/minimal/"><img src="https://img.shields.io/badge/CVE_Dashboard-Live-0d9488" alt="CVE Dashboard"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <a href="https://slsa.dev/spec/v1.0/levels#build-l3"><img src="https://img.shields.io/badge/SLSA-Level_3-0d9488" alt="SLSA Level 3"></a>
  <img src="https://img.shields.io/badge/Images-41-0d9488" alt="Images: 41">
  <img src="https://img.shields.io/badge/Arch-amd64_%7C_arm64-0d9488" alt="Architectures">
</p>

<p align="center">
  <a href="https://rtvkiz.github.io/minimal/">Live CVE dashboard</a> ·
  <a href="#pull-and-verify-in-30-seconds">Verify an image</a> ·
  <a href="#available-images--41-total">All 41 images</a> ·
  <a href="https://news.ycombinator.com/item?id=46840178">HN discussion</a>
</p>

---

## Pull and verify in 30 seconds

The point of these images is that you don't have to trust me. Pull one, then check the provenance yourself:

```bash
# Pull. It's public — no login, no rate limit.
docker pull ghcr.io/rtvkiz/minimal-python:latest

# Verify the build provenance. This proves the image was produced by the
# workflow file in this repo, at a specific commit, on a GitHub-hosted runner.
gh attestation verify oci://ghcr.io/rtvkiz/minimal-python:latest --owner rtvkiz

# Pull the SPDX SBOM so you can see exactly what's inside.
cosign verify-attestation --type spdxjson \
  --certificate-identity-regexp='https://github.com/rtvkiz/minimal/' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/rtvkiz/minimal-python:latest \
  | jq -r '.payload | @base64d | fromjson | .predicate' > python-sbom.spdx.json
```

More verification recipes (cosign signature, SBOM, SLSA provenance) live in [`.github/SECURITY.md`](.github/SECURITY.md).

## How `minimal` is different

|  | minimal | Chainguard | Docker Hardened | Minimus / RapidFort |
|---|:---:|:---:|:---:|:---:|
| **License** | MIT | Proprietary | Apache-2.0 | Proprietary |
| **Cost** | $0 | ~$30k/image/yr | Free + paid support | Sales call |
| **Auth to pull** | No | Yes | Yes | Yes |
| **Rate limits** | None | Yes | Yes | Yes |
| **Build recipes public** | Yes, every `melange.yaml` | No | Yes, Dockerfiles | No |
| **Cosign sig + SBOM + SLSA L3** | Yes | Yes | Yes | Yes |
| **Vendor SLA, FedRAMP/STIG** | No | Yes (paid) | Yes (paid) | Yes (paid) |

Reach for `minimal` if you want hardened images without paying or signing up, if you want to read every build recipe end-to-end, or if you want a working template to fork into your own internal catalog.

It's probably not the right fit if you need a vendor contract, FedRAMP or STIG accreditation paperwork, or a thousand-plus images on day one — those are real things this project doesn't try to solve.

## What every image ships with

- A cosign keyless signature, verifiable against the public Rekor transparency log.
- An SPDX SBOM attached as an in-toto attestation — every package, version, and license.
- SLSA v1.0 build provenance — cryptographic proof of which workflow, which commit, and which runner produced the image.
- A daily Grype scan, with results in the [public dashboard](https://rtvkiz.github.io/minimal/) and the GitHub Security tab.
- Native `linux/amd64` and `linux/arm64` builds.
- A non-root user by default (UID 65532), unless the upstream insists otherwise.
- No shell where possible — most images don't ship `/bin/sh`.
- A six-hour rebuild cadence, so Wolfi CVE patches land in hours, not days.

## Available Images — 41 total

| Category | Count | Highlights |
|---|---|---|
| **Languages & runtimes** | 9 | python, node-slim, bun, go, java, ruby, php, dotnet, deno |
| **Databases** | 5 | mysql, mariadb, postgres-slim, sqlite, opensearch |
| **Caches, queues, messaging** | 6 | redis-slim, valkey, memcached, kafka, rabbitmq, nats |
| **Web servers & proxies** | 6 | nginx, httpd, caddy, haproxy, traefik, envoy |
| **Observability** | 6 | prometheus, victoria-metrics, jaeger, loki, otelcol, fluent-bit |
| **Infrastructure** | 5 | coredns, etcd, openbao, keycloak, qdrant |
| **Apps** | 4 | jenkins, gitea, minio, rails |

<details>
<summary><strong>Full image catalog with pull commands</strong></summary>

<br>

| Image | Pull Command | Shell | Use Case |
|-------|--------------|-------|----------|
| | | **Languages** | |
| Python | `docker pull ghcr.io/rtvkiz/minimal-python:latest` | No | Python apps, microservices |
| Node.js-slim | `docker pull ghcr.io/rtvkiz/minimal-node-slim:latest` | No | Node.js apps, JavaScript |
| Bun | `docker pull ghcr.io/rtvkiz/minimal-bun:latest` | No | Fast JavaScript/TypeScript runtime |
| Go | `docker pull ghcr.io/rtvkiz/minimal-go:latest` | No | Go development, CGO builds |
| .NET Runtime | `docker pull ghcr.io/rtvkiz/minimal-dotnet:latest` | No | .NET 10 runtime for apps |
| Java | `docker pull ghcr.io/rtvkiz/minimal-java:latest` | No | OpenJDK 26 JRE for Java apps |
| Ruby | `docker pull ghcr.io/rtvkiz/minimal-ruby:latest` | No | Ruby 4.0 runtime (built from source) |
| PHP | `docker pull ghcr.io/rtvkiz/minimal-php:latest` | No | PHP 8.5 CLI (built from source) |
| Rails | `docker pull ghcr.io/rtvkiz/minimal-rails:latest` | No | Ruby 4.0 + Rails 8.1 (built from source) |
| Deno | `docker pull ghcr.io/rtvkiz/minimal-deno:latest` | No | Secure TypeScript/JavaScript runtime |
| | | **Databases** | |
| MySQL | `docker pull ghcr.io/rtvkiz/minimal-mysql:latest` | Yes | MySQL LTS 8.4.x, built from source |
| MariaDB | `docker pull ghcr.io/rtvkiz/minimal-mariadb:latest` | Yes | MariaDB LTS 11.4.x, built from source |
| PostgreSQL-slim | `docker pull ghcr.io/rtvkiz/minimal-postgres-slim:latest` | No | Relational database |
| SQLite | `docker pull ghcr.io/rtvkiz/minimal-sqlite:latest` | No | Embedded SQL database CLI |
| OpenSearch | `docker pull ghcr.io/rtvkiz/minimal-opensearch:latest` | No* | OpenSearch 3.x — search & analytics |
| | | **Caches, Queues, Messaging** | |
| Redis-slim | `docker pull ghcr.io/rtvkiz/minimal-redis-slim:latest` | No | In-memory data store |
| Memcached | `docker pull ghcr.io/rtvkiz/minimal-memcached:latest` | No | In-memory caching (built from source) |
| Valkey | `docker pull ghcr.io/rtvkiz/minimal-valkey:latest` | No | BSD-licensed Redis fork (LF) |
| Kafka | `docker pull ghcr.io/rtvkiz/minimal-kafka:latest` | Yes | Apache Kafka 4.x, KRaft mode |
| RabbitMQ | `docker pull ghcr.io/rtvkiz/minimal-rabbitmq:latest` | Yes | RabbitMQ 4.x AMQP broker |
| NATS | `docker pull ghcr.io/rtvkiz/minimal-nats:latest` | No | NATS Server with JetStream |
| | | **Web Servers & Proxies** | |
| Nginx | `docker pull ghcr.io/rtvkiz/minimal-nginx:latest` | No | Reverse proxy, static files |
| HTTPD | `docker pull ghcr.io/rtvkiz/minimal-httpd:latest` | Maybe* | Apache web server |
| Caddy | `docker pull ghcr.io/rtvkiz/minimal-caddy:latest` | No | Automatic HTTPS web server |
| HAProxy | `docker pull ghcr.io/rtvkiz/minimal-haproxy:latest` | No | TCP/HTTP load balancer |
| Traefik | `docker pull ghcr.io/rtvkiz/minimal-traefik:latest` | No | Cloud-native reverse proxy |
| Envoy | `docker pull ghcr.io/rtvkiz/minimal-envoy:latest` | No | Service proxy & load balancer |
| | | **Observability** | |
| Prometheus | `docker pull ghcr.io/rtvkiz/minimal-prometheus:latest` | No | Metrics collection & alerting |
| VictoriaMetrics | `docker pull ghcr.io/rtvkiz/minimal-victoria-metrics:latest` | No | High-perf metrics storage |
| Jaeger | `docker pull ghcr.io/rtvkiz/minimal-jaeger:latest` | No | Distributed tracing (v2) |
| Loki | `docker pull ghcr.io/rtvkiz/minimal-loki:latest` | No | Log aggregation (Grafana Labs) |
| OTel Collector | `docker pull ghcr.io/rtvkiz/minimal-otelcol:latest` | No | OpenTelemetry Collector core |
| Fluent Bit | `docker pull ghcr.io/rtvkiz/minimal-fluent-bit:latest` | No | Lightweight log processor |
| | | **Infrastructure** | |
| CoreDNS | `docker pull ghcr.io/rtvkiz/minimal-coredns:latest` | No | Kubernetes default DNS |
| etcd | `docker pull ghcr.io/rtvkiz/minimal-etcd:latest` | No | Distributed key-value store |
| OpenBao | `docker pull ghcr.io/rtvkiz/minimal-openbao:latest` | No | Secret management (Vault fork) |
| Keycloak | `docker pull ghcr.io/rtvkiz/minimal-keycloak:latest` | Yes | Identity & access management |
| Qdrant | `docker pull ghcr.io/rtvkiz/minimal-qdrant:latest` | No | Vector DB for AI/ML (Rust) |
| | | **Apps** | |
| Jenkins | `docker pull ghcr.io/rtvkiz/minimal-jenkins:latest` | Yes | CI/CD automation |
| Gitea | `docker pull ghcr.io/rtvkiz/minimal-gitea:latest` | Yes | Self-hosted Git service |
| MinIO | `docker pull ghcr.io/rtvkiz/minimal-minio:latest` | No | S3-compatible object storage |
| | | **AI / ML** | |
| CUDA Python | *disabled* | No | Python + CUDA 12.9 + cuDNN 9.10 (build paused, code retained) |

*\*HTTPD, Jenkins, Kafka, MySQL, OpenSearch, Gitea, Keycloak include shell (`sh`/`busybox`/`bash`) via transitive Wolfi dependencies or because the upstream entrypoint requires it. CI treats shell presence as informational.*

</details>

## Quick Start

```bash
# Python app
docker run --rm -v $(pwd):/app ghcr.io/rtvkiz/minimal-python:latest /app/main.py

# Nginx reverse proxy
docker run -d -p 8080:80 ghcr.io/rtvkiz/minimal-nginx:latest

# PostgreSQL
docker run -d -p 5432:5432 -v pgdata:/var/lib/postgresql/data \
  ghcr.io/rtvkiz/minimal-postgres-slim:latest

# Redis
docker run -d -p 6379:6379 ghcr.io/rtvkiz/minimal-redis-slim:latest

# Kafka (KRaft mode — auto-initializes storage on first boot)
docker run -d -p 9092:9092 -v kafkadata:/var/kafka/data \
  ghcr.io/rtvkiz/minimal-kafka:latest
```

<details>
<summary><strong>More <code>docker run</code> examples (Node, Go, MySQL, MariaDB, Java, .NET, PHP, Rails, RabbitMQ, Gitea, …)</strong></summary>

<br>

```bash
# Node.js
docker run --rm -v $(pwd):/app -w /app ghcr.io/rtvkiz/minimal-node-slim:latest index.js

# Bun
docker run --rm ghcr.io/rtvkiz/minimal-bun:latest --version

# Go
docker run --rm -v $(pwd):/app -w /app ghcr.io/rtvkiz/minimal-go:latest build -o /tmp/app .

# HTTPD
docker run -d -p 8080:80 ghcr.io/rtvkiz/minimal-httpd:latest

# Jenkins
docker run -d -p 8080:8080 -v jenkins_home:/var/jenkins_home ghcr.io/rtvkiz/minimal-jenkins:latest

# MySQL
docker run -d -p 3306:3306 -v mysqldata:/var/lib/mysql ghcr.io/rtvkiz/minimal-mysql:latest

# Memcached
docker run -d -p 11211:11211 ghcr.io/rtvkiz/minimal-memcached:latest

# SQLite
docker run --rm -v $(pwd):/data ghcr.io/rtvkiz/minimal-sqlite:latest /data/mydb.sqlite "SELECT sqlite_version();"

# .NET
docker run --rm -v $(pwd):/app ghcr.io/rtvkiz/minimal-dotnet:latest /app/myapp.dll

# Java
docker run --rm -v $(pwd):/app ghcr.io/rtvkiz/minimal-java:latest -jar /app/myapp.jar

# PHP
docker run --rm -v $(pwd):/app ghcr.io/rtvkiz/minimal-php:latest /app/index.php

# Rails
docker run --rm -v $(pwd):/app ghcr.io/rtvkiz/minimal-rails:latest -e "require 'rails'; puts Rails.version"

# RabbitMQ
docker run -d -p 5672:5672 -v rabbitmqdata:/var/lib/rabbitmq ghcr.io/rtvkiz/minimal-rabbitmq:latest

# Gitea
docker run -d -p 3000:3000 -v giteadata:/data/gitea ghcr.io/rtvkiz/minimal-gitea:latest
```

</details>

## Using in production

**Pin to immutable version tags.** Every image is published with two tags:

| Tag | Format | Example | Mutable |
|---|---|---|---|
| Version | `VERSION-rEPOCH` | `ghcr.io/rtvkiz/minimal-redis-slim:8.4.1-r0` | No |
| Latest | `latest` | `ghcr.io/rtvkiz/minimal-redis-slim:latest` | Yes |

### Dev variants (`:latest-dev`)

Most images publish a `-dev` companion built from the **same source as prod** — same runtime version, same curated package set — plus a shell, package manager, compiler toolchain, and image-appropriate debug tooling. Intended for CI build stages and in-pod debugging, **not for production deployment**.

Typical multi-stage usage:

```dockerfile
FROM ghcr.io/rtvkiz/minimal-ruby:latest-dev AS build
WORKDIR /work
COPY Gemfile Gemfile.lock ./
RUN bundle install

FROM ghcr.io/rtvkiz/minimal-ruby:latest
COPY --from=build /work /work
```

To get an interactive shell, override the entrypoint (dev images keep the prod entrypoint for drop-in compatibility):

```bash
docker run -it --entrypoint /bin/sh   ghcr.io/rtvkiz/minimal-<image>:latest-dev
docker run -it --entrypoint /bin/bash ghcr.io/rtvkiz/minimal-<image>:latest-dev
```

Dev variants share the prod image's signing, SBOM, and SLSA provenance pipeline. They are **not tracked on the public CVE dashboard** — they intentionally ship a larger attack surface. See [`.github/SECURITY.md`](.github/SECURITY.md#dev-variants--dev-tags) for the policy and [`docs/dev-variants/CONVENTIONS.md`](docs/dev-variants/CONVENTIONS.md) for the package composition rules.

**Shipping today:** 14 of 41 dev variants — all language runtimes (`ruby`, `python`, `node-slim`, `go`, `java`, `dotnet`, `bun`, `deno`, `rails`, `php`) plus 4 databases (`postgres-slim`, `mariadb`, `redis-slim`, `valkey`). The other 27 are rolling out batch by batch; see status table below.

<details>
<summary><strong>Per-image dev variant status</strong></summary>

<br>

Legend: ✅ shipping `:latest-dev` · 🚧 in progress · 📝 planned

Categories follow the three templates in [`docs/dev-variants/templates/`](docs/dev-variants/templates/) (runtime / daemon / server). The "Reference" column shows where we mirror Chainguard's public `<image>-public/devConfigs` package set; **in-house** means Chainguard ships an Enterprise-only image and we designed the dev composition ourselves.

| Image | Category | Reference | Status |
|---|---|---|---|
| ruby | runtime | Chainguard `ruby-public` | ✅ |
| python | runtime | Chainguard `python-public` | ✅ |
| node-slim | runtime | Chainguard `node-public` | ✅ |
| go | runtime | Chainguard `go-public` | ✅ |
| java | runtime | Chainguard `jdk-public` | ✅ |
| dotnet | runtime | Chainguard `dotnet-runtime-10-public` | ✅ |
| php | runtime | in-house (composer deferred — see PR) | ✅ |
| rails | runtime | in-house (derive from ruby) | ✅ |
| bun | runtime | in-house | ✅ |
| deno | runtime | in-house | ✅ |
| postgres-slim | daemon | Chainguard `postgres-public` | ✅ |
| mariadb | daemon | Chainguard `mariadb-public` | ✅ |
| mysql | daemon | in-house | 📝 |
| redis-slim | daemon | Chainguard `redis-public` | ✅ |
| valkey | daemon | Chainguard `valkey-public` | ✅ |
| memcached | daemon | in-house | 📝 |
| sqlite | daemon | in-house | 📝 |
| opensearch | daemon | in-house | 📝 |
| kafka | daemon | in-house | 📝 |
| rabbitmq | daemon | in-house | 📝 |
| nats | daemon | in-house | 📝 |
| etcd | daemon | in-house | 📝 |
| qdrant | daemon | in-house | 📝 |
| nginx | server | Chainguard `nginx-public` | 📝 |
| haproxy | server | Chainguard `haproxy-public` | 📝 |
| minio | server | Chainguard `minio-client-public` (server in-house) | 📝 |
| httpd | server | in-house | 📝 |
| caddy | server | in-house | 📝 |
| traefik | server | in-house | 📝 |
| envoy | server | in-house | 📝 |
| prometheus | server | in-house | 📝 |
| victoria-metrics | server | in-house | 📝 |
| jaeger | server | in-house | 📝 |
| otelcol | server | in-house | 📝 |
| loki | server | in-house | 📝 |
| fluent-bit | server | in-house | 📝 |
| coredns | server | in-house | 📝 |
| gitea | server | in-house | 📝 |
| jenkins | server | in-house | 📝 |
| keycloak | server | in-house | 📝 |
| openbao | server | in-house | 📝 |

</details>

```dockerfile
# Production Dockerfile — pin by version tag, ideally by digest
FROM ghcr.io/rtvkiz/minimal-go:1.26.0-r0 AS build
WORKDIR /src
COPY . .
RUN go build -o /out/app

FROM ghcr.io/rtvkiz/minimal-python:3.14.0-r0
COPY --from=build /out/app /usr/bin/app
ENTRYPOINT ["/usr/bin/app"]
```

**Enforce signature + provenance in Kubernetes** with [sigstore-policy-controller](https://docs.sigstore.dev/policy-controller/overview/) or Kyverno:

```yaml
# Kyverno ClusterPolicy — only allow signed minimal-* images
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-minimal-images
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-signature
      match:
        any:
          - resources:
              kinds: [Pod]
      verifyImages:
        - imageReferences:
            - "ghcr.io/rtvkiz/minimal-*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/rtvkiz/minimal/*"
                    issuer: "https://token.actions.githubusercontent.com"
```

The `-r0` suffix is the revision number — resets to `r0` on each upstream version bump, increments (`r1`, `r2`, …) for rebuilds of the same upstream version (e.g., dependency patches). Old version tags are preserved across rebuilds.

## Build pipeline

<details>
<summary><strong>Pipeline diagram</strong></summary>

<br>

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            BUILD PIPELINE                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Signing Keys:                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  PRs: keygen job (ephemeral) │ Main: repository secrets (persistent)│    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                              │                                              │
│                              ▼                                              │
│  ┌─────────────────────────────┐    ┌─────────────────────────────────────┐ │
│  │  melange-build              │    │      build-apko                     │ │
│  │  Native ARM64 runners       │    │      Wolfi pre-built packages       │ │
│  │  ┌────────┐  ┌────────────┐ │    │  ┌─────────┐     ┌───────────────┐  │ │
│  │  │ x86_64 │  │  aarch64   │ │    │  │  Wolfi  │────►│ apko publish  │  │ │
│  │  │ ubuntu │  │ ubuntu-arm │ │    │  │ packages│     │ (multi-arch)  │  │ │
│  │  └────┬───┘  └─────┬──────┘ │    │  └─────────┘     └───────┬───────┘  │ │
│  │       └─────┬──────┘        │    │                          │          │ │
│  │             ▼               │    └──────────────────────────│──────────┘ │
│  │     ┌──────────────┐        │                               │            │
│  │     │   artifacts  │        │                               │            │
│  │     │ (x86+arm64)  │        │                               │            │
│  │     └──────┬───────┘        │                               │            │
│  └────────────│────────────────┘                               │            │
│               ▼                                                │            │
│  ┌─────────────────────────────┐                               │            │
│  │  build-melange              │                               │            │
│  │  ┌─────────┐ ┌────────────┐ │                               │            │
│  │  │  merge  │►│   apko     │─┼───────────────────────────────┤            │
│  │  │ packages│ │  publish   │ │                               │            │
│  │  └─────────┘ └────────────┘ │                               │            │
│  └─────────────────────────────┘                               │            │
│                                                                ▼            │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                     Verification & Attestation                       │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────────────┐   │   │
│  │  │  Grype   │─►│   Test   │─►│  cosign  │─►│  SBOM + SLSA L3     │   │   │
│  │  │ CVE scan │  │  image   │  │   sign   │  │    attestations     │   │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Note: PRs build and test but do not publish. Only main branch publishes.   │
└─────────────────────────────────────────────────────────────────────────────┘
```

</details>

### Update schedule

| Trigger | When | Purpose |
|---|---|---|
| Scheduled | Every 6 hours | Pick up latest CVE patches from Wolfi |
| Push | On merge to `main` | Deploy configuration changes |
| Manual | Workflow dispatch | Emergency rebuilds |

Vulnerability scan results appear in the [live dashboard](https://rtvkiz.github.io/minimal/), the job summary, and the GitHub Security tab.

### Automated upstream tracking

Source-built images are tracked by dedicated workflows that check upstream daily and open PRs:

<details>
<summary><strong>Per-image update workflows (21 total)</strong></summary>

<br>

| Workflow | Watches | What It Does |
|---|---|---|
| `update-jenkins.yml` | Jenkins LTS releases | Updates version in melange config, Makefile, build.yml |
| `update-redis.yml` | Redis GitHub releases | Updates version and SHA256 |
| `update-mysql.yml` | MySQL LTS (8.4.x) GitHub tags | Updates version and SHA256 |
| `update-memcached.yml` | Memcached GitHub releases | Updates version and SHA256 |
| `update-kafka.yml` | Apache Kafka 4.x GitHub tags | Updates version and SHA512 |
| `update-php.yml` | php.net releases API | Updates version and SHA256; opens issue for new minor/major series |
| `update-rails.yml` | RubyGems API + Ruby GitHub tags | Updates Rails gem and Ruby source versions independently |
| `update-rabbitmq.yml` | RabbitMQ GitHub releases | Updates version and SHA256 |
| `update-minio.yml` | MinIO GitHub releases | Updates release tag, date-based version, and SHA256 |
| `update-victoria-metrics.yml` | VictoriaMetrics GitHub releases | Updates version and SHA256 |
| `update-jaeger.yml` | Jaeger v2.x GitHub releases | Updates version and SHA256; warns on major version change |
| `update-otelcol.yml` | OTel Collector stable releases | Updates version and SHA256; skips prereleases |
| `update-qdrant.yml` | Qdrant v1.x GitHub releases | Updates version and SHA256 |
| `update-etcd.yml` | etcd v3.x GitHub releases | Updates version and SHA256 |
| `update-opensearch.yml` | OpenSearch 3.x GitHub releases | Updates version in Makefile and README |
| `update-gitea.yml` | Gitea v1.x GitHub tags | Updates version and SHA256 |
| `update-coredns.yml` | CoreDNS v1.x GitHub tags | Updates version and SHA256 |
| `update-openbao.yml` | OpenBao v2.x GitHub tags | Updates version and SHA256 |
| `update-loki.yml` | Loki v3.x GitHub tags | Updates version and SHA256 |
| `update-fluent-bit.yml` | Fluent Bit v5.x GitHub tags | Updates version and SHA256 |
| `update-keycloak.yml` | Keycloak 26.x GitHub tags | Updates version and SHA256 |
| `update-wolfi-packages.yml` | Wolfi APKINDEX | Detects new Python, Node, Go, .NET, Java, PostgreSQL, Deno versions |

Patch updates are auto-PR'd and validated by CI. Minor/major bumps create a GitHub Issue with a manual upgrade checklist.

</details>

<details>
<summary><strong>Image specifications (versions, users, entrypoints)</strong></summary>

<br>

| Image | Version | User | Entrypoint | Workdir |
|-------|---------|------|------------|---------|
| Python | 3.14.x | nonroot (65532) | `/usr/bin/python3` | `/app` |
| Node.js-slim | 25.x | nonroot (65532) | `/usr/bin/dumb-init -- /usr/bin/node` | `/app` |
| Bun | latest | nonroot (65532) | `/usr/bin/bun` | `/app` |
| Go | 1.26.x | nonroot (65532) | `/usr/bin/go` | `/app` |
| Nginx | mainline | nginx (65532) | `/usr/sbin/nginx -g "daemon off;"` | `/` |
| HTTPD | 2.4.x | www-data (65532) | `/usr/sbin/httpd -DFOREGROUND` | `/var/www/localhost/htdocs` |
| Jenkins | 2.555.x LTS | jenkins (1000) | `tini -- java -jar jenkins.war` | `/var/jenkins_home` |
| Redis | 8.6.x | redis (65532) | `/usr/bin/redis-server` | `/` |
| MySQL | 8.4.x | mysql (65532) | `/usr/bin/docker-entrypoint.sh` | `/` |
| MariaDB | 11.4.x | mariadb (65532) | `/usr/bin/mariadbd` | `/var/lib/mysql` |
| Memcached | 1.6.x | memcached (65532) | `/usr/bin/memcached` | `/` |
| PostgreSQL | 18.x | postgres (70) | `/usr/bin/postgres` | `/` |
| SQLite | 3.51.x | nonroot (65532) | `/usr/bin/sqlite3` | `/data` |
| .NET Runtime | 10.x | nonroot (65532) | `/usr/bin/dotnet` | `/app` |
| Java | 26.x | nonroot (65532) | `/usr/bin/java` | `/app` |
| Ruby | 4.0.x | nonroot (65532) | `/usr/bin/ruby` | `/work` |
| PHP | 8.5.x | nonroot (65532) | `/usr/bin/php` | `/app` |
| Rails | Ruby 4.0.x + Rails 8.1.x | nonroot (65532) | `/usr/bin/ruby` | `/app` |
| Kafka | 4.2.x | kafka (65532) | `/usr/bin/kafka-entrypoint.sh` | `/` |
| RabbitMQ | 4.3.x | rabbitmq (65532) | `/opt/rabbitmq/sbin/rabbitmq-server` | `/` |
| NATS | latest | nonroot (65532) | `/usr/bin/nats-server` | `/` |
| Valkey | latest | nonroot (65532) | `/usr/bin/valkey-server` | `/` |
| MinIO | RELEASE.2025-10-15 | minio (65532) | `/usr/bin/minio server --console-address :9001 /data` | `/data` |
| OpenSearch | 3.6.0 | opensearch (65532) | `/usr/share/opensearch/opensearch-docker-entrypoint.sh` | `/usr/share/opensearch/data` |
| etcd | 3.6.x | nonroot (65532) | `/usr/bin/etcd` | `/var/lib/etcd` |
| VictoriaMetrics | 1.142.x | nonroot (65532) | `/usr/bin/victoria-metrics` | `/` |
| Jaeger | 2.18.x | nonroot (65532) | `/usr/bin/jaeger` | `/` |
| OTel Collector | 0.151.x | nonroot (65532) | `/usr/bin/otelcol` | `/` |
| Qdrant | 1.17.x | nonroot (65532) | `/usr/bin/qdrant` | `/qdrant` |
| Deno | 2.x | nonroot (65532) | `/usr/bin/deno` | `/app` |
| Gitea | 1.26.x | gitea (65532) | `/usr/bin/gitea web --config /etc/gitea/app.ini` | `/var/lib/gitea` |
| CoreDNS | 1.14.x | nonroot (65532) | `/usr/bin/coredns` | `/` |
| OpenBao | 2.5.x | openbao (65532) | `/usr/bin/bao server` | `/openbao/data` |
| Keycloak | 26.6.x | keycloak (65532) | `/opt/keycloak/bin/kc.sh start-dev` | `/opt/keycloak/data` |
| Loki | 3.6.x | loki (65532) | `/usr/bin/loki` | `/loki` |
| Fluent Bit | 5.0.x | nonroot (65532) | `/usr/bin/fluent-bit` | `/` |

</details>

## Build locally

```bash
# Prerequisites
go install chainguard.dev/apko@latest
go install chainguard.dev/melange@latest
brew install anchore/grype/grype

# Build & test a specific image
make python
make test-python

# Build everything
make build

# Scan for CVEs
make scan
```

See the [Makefile](Makefile) for the full target list.

## Project structure

<details>
<summary><strong>Repository layout</strong></summary>

<br>

```
minimal/
├── <image>/
│   ├── apko/<name>.yaml          # final image config
│   ├── melange.yaml              # source build (optional)
│   └── test.sh                   # smoke test
├── .github/
│   ├── SECURITY.md               # disclosure policy + verification recipes
│   └── workflows/
│       ├── build.yml             # main CI pipeline (6h rebuilds)
│       ├── patch-go-deps.yml     # daily Go transitive CVE patching
│       ├── update-<image>.yml    # per-image upstream version tracking
│       └── update-wolfi-packages.yml
├── Makefile
├── README.md
├── CONTRIBUTING.md
└── LICENSE
```

</details>

## Status and roadmap

Recently landed:

- Cosign keyless signatures on every image.
- SPDX SBOMs attached as in-toto attestations, verifiable with `cosign verify-attestation`.
- SLSA v1.0 build provenance, verifiable with `gh attestation verify`.
- A public CVE dashboard with per-image breakdowns.
- A six-hour rebuild cadence, plus daily patching of Go transitive CVEs.

Next up:

- VEX statements for CVEs that aren't actually exploitable in our images, so the dashboard stops showing noise.
- Consolidating the per-image update workflows into one matrix-driven job.
- Niche AI/ML images (CUDA-aware Python variants) — there's a [HN thread](https://news.ycombinator.com/item?id=46842670) where this came up and it seems worth exploring.

What this project is not:

- Solo-maintained, so there's no vendor SLA and no on-call rotation.
- Not FedRAMP / FIPS / STIG accredited. The verifiable provenance and SBOMs help with audits, but they don't replace the paperwork.

## Contributing

PRs are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) has the build setup, the image conventions, and the local validation checklist I run before pushing.

If you find a security issue, please use [GitHub's private vulnerability reporting](https://github.com/rtvkiz/minimal/security/advisories/new) rather than opening a public issue. The disclosure policy and response timeline are in [`.github/SECURITY.md`](.github/SECURITY.md).

## License

MIT — see [LICENSE](LICENSE).

Container images include packages from [Wolfi](https://github.com/wolfi-dev) and other sources, each with their own licenses (Apache-2.0, MIT, GPL, LGPL, BSD, etc.). Full license information is in each image's SBOM:

```bash
cosign download sbom ghcr.io/rtvkiz/minimal-python:latest | jq '.packages[].licenseConcluded'
```
