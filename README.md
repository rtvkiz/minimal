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
  <img src="https://img.shields.io/badge/Images-91-0d9488" alt="Images: 91">
  <img src="https://img.shields.io/badge/Arch-amd64_%7C_arm64-0d9488" alt="Architectures: amd64 and arm64">
</p>

<p align="center">
  <a href="#pull-and-verify-an-image">Verify an image</a> ·
  <a href="#available-images--91-total">All 91 images</a> ·
  <a href="#how-images-stay-current">Update model</a> ·
  <a href="#build-locally">Build locally</a>
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

## Available images — 91 total

The inventory below is derived from [`catalog.json`](catalog.json), which is validated against the build matrix in CI.

| Category | Count | Images |
|---|---:|---|
| **Languages & Runtimes** | 9 | python, node-slim, bun, go, java, ruby, php, dotnet, deno |
| **Databases** | 8 | mysql, mariadb, postgres-slim, pgbouncer, sqlite, opensearch, cassandra, solr |
| **Caches, Queues & Messaging** | 9 | redis-slim, valkey, memcached, kafka, zookeeper, pulsar, rabbitmq, nats, mosquitto |
| **Web Servers & Proxies** | 8 | tomcat, nginx, httpd, caddy, haproxy, traefik, envoy, oauth2-proxy |
| **Observability** | 14 | prometheus, alertmanager, victoria-metrics, thanos, mimir, jaeger, loki, tempo, otelcol, fluent-bit, telegraf, node-exporter, blackbox-exporter, pushgateway |
| **Infrastructure** | 9 | unbound, step-ca, coredns, etcd, openbao, keycloak, qdrant, registry, consul |
| **Kubernetes, CI & IaC** | 29 | Kubernetes, supply-chain security, policy, registry, GitOps, backup, and IaC tools |
| **Apps** | 5 | jenkins, gitea, minio, rails, mailpit |

Live versions, image sizes, CVE results, packages, digests, and verification data are available at [minimalcontainers.com](https://minimalcontainers.com).

<details>
<summary><strong>Full image catalog with pull commands</strong></summary>

<br>

| Image | Pull command | Purpose |
|---|---|---|
| **Languages & Runtimes** |  |  |
| `python` | `docker pull ghcr.io/rtvkiz/minimal-python:latest` | Shell-less Python 3 runtime built on Wolfi. |
| `node-slim` | `docker pull ghcr.io/rtvkiz/minimal-node-slim:latest` | Shell-less Node.js runtime built on Wolfi. |
| `bun` | `docker pull ghcr.io/rtvkiz/minimal-bun:latest` | Shell-less Bun JavaScript runtime built on Wolfi. |
| `go` | `docker pull ghcr.io/rtvkiz/minimal-go:latest` | Go builder image built on Wolfi. |
| `java` | `docker pull ghcr.io/rtvkiz/minimal-java:latest` | Shell-less OpenJDK JRE built on Wolfi. |
| `ruby` | `docker pull ghcr.io/rtvkiz/minimal-ruby:latest` | Ruby runtime built from source with melange. |
| `php` | `docker pull ghcr.io/rtvkiz/minimal-php:latest` | PHP runtime built from source with melange. |
| `dotnet` | `docker pull ghcr.io/rtvkiz/minimal-dotnet:latest` | .NET runtime built on Wolfi. |
| `deno` | `docker pull ghcr.io/rtvkiz/minimal-deno:latest` | Shell-less Deno TypeScript runtime built on Wolfi. |
| **Databases** |  |  |
| `mysql` | `docker pull ghcr.io/rtvkiz/minimal-mysql:latest` | MySQL LTS built from source with melange. |
| `mariadb` | `docker pull ghcr.io/rtvkiz/minimal-mariadb:latest` | MariaDB LTS built from source with melange. |
| `postgres-slim` | `docker pull ghcr.io/rtvkiz/minimal-postgres-slim:latest` | PostgreSQL built on Wolfi. |
| `pgbouncer` | `docker pull ghcr.io/rtvkiz/minimal-pgbouncer:latest` | Shell-less PostgreSQL connection pooler. |
| `sqlite` | `docker pull ghcr.io/rtvkiz/minimal-sqlite:latest` | Shell-less SQLite CLI and library. |
| `opensearch` | `docker pull ghcr.io/rtvkiz/minimal-opensearch:latest` | OpenSearch with a curated Wolfi runtime. |
| `cassandra` | `docker pull ghcr.io/rtvkiz/minimal-cassandra:latest` | Apache Cassandra with a custom jlink JRE. |
| `solr` | `docker pull ghcr.io/rtvkiz/minimal-solr:latest` | Apache Solr with a custom jlink JRE. |
| **Caches, Queues & Messaging** |  |  |
| `redis-slim` | `docker pull ghcr.io/rtvkiz/minimal-redis-slim:latest` | Shell-less Redis built from source. |
| `valkey` | `docker pull ghcr.io/rtvkiz/minimal-valkey:latest` | Shell-less Valkey built from source. |
| `memcached` | `docker pull ghcr.io/rtvkiz/minimal-memcached:latest` | Shell-less Memcached built from source. |
| `kafka` | `docker pull ghcr.io/rtvkiz/minimal-kafka:latest` | Apache Kafka with a custom jlink JRE and KRaft support. |
| `zookeeper` | `docker pull ghcr.io/rtvkiz/minimal-zookeeper:latest` | Apache ZooKeeper with a custom jlink JRE. |
| `pulsar` | `docker pull ghcr.io/rtvkiz/minimal-pulsar:latest` | Apache Pulsar with a custom jlink JRE. |
| `rabbitmq` | `docker pull ghcr.io/rtvkiz/minimal-rabbitmq:latest` | RabbitMQ with Wolfi Erlang/OTP. |
| `nats` | `docker pull ghcr.io/rtvkiz/minimal-nats:latest` | Shell-less NATS server. |
| `mosquitto` | `docker pull ghcr.io/rtvkiz/minimal-mosquitto:latest` | Shell-less Eclipse Mosquitto MQTT broker. |
| **Web Servers & Proxies** |  |  |
| `tomcat` | `docker pull ghcr.io/rtvkiz/minimal-tomcat:latest` | Apache Tomcat with a custom jlink JRE and default webapps removed. |
| `nginx` | `docker pull ghcr.io/rtvkiz/minimal-nginx:latest` | Shell-less Nginx built on Wolfi. |
| `httpd` | `docker pull ghcr.io/rtvkiz/minimal-httpd:latest` | Apache HTTP Server built on Wolfi. |
| `caddy` | `docker pull ghcr.io/rtvkiz/minimal-caddy:latest` | Shell-less Caddy web server. |
| `haproxy` | `docker pull ghcr.io/rtvkiz/minimal-haproxy:latest` | Shell-less HAProxy load balancer. |
| `traefik` | `docker pull ghcr.io/rtvkiz/minimal-traefik:latest` | Shell-less Traefik reverse proxy. |
| `envoy` | `docker pull ghcr.io/rtvkiz/minimal-envoy:latest` | Shell-less Envoy proxy. |
| `oauth2-proxy` | `docker pull ghcr.io/rtvkiz/minimal-oauth2-proxy:latest` | OAuth2/OIDC authenticating reverse proxy. |
| **Observability** |  |  |
| `prometheus` | `docker pull ghcr.io/rtvkiz/minimal-prometheus:latest` | Prometheus monitoring server. |
| `alertmanager` | `docker pull ghcr.io/rtvkiz/minimal-alertmanager:latest` | Prometheus Alertmanager. |
| `victoria-metrics` | `docker pull ghcr.io/rtvkiz/minimal-victoria-metrics:latest` | VictoriaMetrics time-series database. |
| `thanos` | `docker pull ghcr.io/rtvkiz/minimal-thanos:latest` | Thanos HA Prometheus long-term storage. |
| `mimir` | `docker pull ghcr.io/rtvkiz/minimal-mimir:latest` | Grafana Mimir long-term Prometheus storage. |
| `jaeger` | `docker pull ghcr.io/rtvkiz/minimal-jaeger:latest` | Jaeger distributed tracing backend. |
| `loki` | `docker pull ghcr.io/rtvkiz/minimal-loki:latest` | Grafana Loki log aggregation server. |
| `tempo` | `docker pull ghcr.io/rtvkiz/minimal-tempo:latest` | Grafana Tempo distributed tracing backend. |
| `otelcol` | `docker pull ghcr.io/rtvkiz/minimal-otelcol:latest` | OpenTelemetry Collector core. |
| `fluent-bit` | `docker pull ghcr.io/rtvkiz/minimal-fluent-bit:latest` | Fluent Bit log processor and forwarder. |
| `telegraf` | `docker pull ghcr.io/rtvkiz/minimal-telegraf:latest` | Telegraf metrics collection agent. |
| `node-exporter` | `docker pull ghcr.io/rtvkiz/minimal-node-exporter:latest` | Prometheus hardware and OS metrics exporter. |
| `blackbox-exporter` | `docker pull ghcr.io/rtvkiz/minimal-blackbox-exporter:latest` | Prometheus endpoint probing exporter. |
| `pushgateway` | `docker pull ghcr.io/rtvkiz/minimal-pushgateway:latest` | Prometheus Pushgateway for batch and ephemeral jobs. |
| **Infrastructure** |  |  |
| `unbound` | `docker pull ghcr.io/rtvkiz/minimal-unbound:latest` | Validating recursive DNS resolver. |
| `step-ca` | `docker pull ghcr.io/rtvkiz/minimal-step-ca:latest` | Smallstep online certificate authority. |
| `coredns` | `docker pull ghcr.io/rtvkiz/minimal-coredns:latest` | CoreDNS DNS server. |
| `etcd` | `docker pull ghcr.io/rtvkiz/minimal-etcd:latest` | Distributed key-value store. |
| `openbao` | `docker pull ghcr.io/rtvkiz/minimal-openbao:latest` | OpenBao secret-management server. |
| `keycloak` | `docker pull ghcr.io/rtvkiz/minimal-keycloak:latest` | Identity and access-management server. |
| `qdrant` | `docker pull ghcr.io/rtvkiz/minimal-qdrant:latest` | Qdrant vector search engine. |
| `registry` | `docker pull ghcr.io/rtvkiz/minimal-registry:latest` | OCI distribution registry. |
| `consul` | `docker pull ghcr.io/rtvkiz/minimal-consul:latest` | HashiCorp Consul service discovery and KV. |
| **Kubernetes, CI & IaC** |  |  |
| `external-dns` | `docker pull ghcr.io/rtvkiz/minimal-external-dns:latest` | Kubernetes DNS controller. |
| `velero` | `docker pull ghcr.io/rtvkiz/minimal-velero:latest` | Kubernetes backup and restore tool. |
| `kaniko` | `docker pull ghcr.io/rtvkiz/minimal-kaniko:latest` | Kaniko container image builder. |
| `skopeo` | `docker pull ghcr.io/rtvkiz/minimal-skopeo:latest` | Container image inspection and copy tool. |
| `helm` | `docker pull ghcr.io/rtvkiz/minimal-helm:latest` | Helm package manager CLI. |
| `kubectl` | `docker pull ghcr.io/rtvkiz/minimal-kubectl:latest` | Kubernetes command-line client. |
| `opentofu` | `docker pull ghcr.io/rtvkiz/minimal-opentofu:latest` | Terraform-compatible OpenTofu IaC CLI. |
| `trivy` | `docker pull ghcr.io/rtvkiz/minimal-trivy:latest` | Vulnerability, IaC, and secret scanner. |
| `cosign` | `docker pull ghcr.io/rtvkiz/minimal-cosign:latest` | Sigstore signing and verification CLI. |
| `syft` | `docker pull ghcr.io/rtvkiz/minimal-syft:latest` | SBOM generator. |
| `grype` | `docker pull ghcr.io/rtvkiz/minimal-grype:latest` | Vulnerability scanner. |
| `osv-scanner` | `docker pull ghcr.io/rtvkiz/minimal-osv-scanner:latest` | OSV dependency vulnerability scanner. |
| `oras` | `docker pull ghcr.io/rtvkiz/minimal-oras:latest` | OCI registry client. |
| `notation` | `docker pull ghcr.io/rtvkiz/minimal-notation:latest` | OCI artifact signing and verification CLI. |
| `conftest` | `docker pull ghcr.io/rtvkiz/minimal-conftest:latest` | OPA-based configuration policy testing CLI. |
| `kubeconform` | `docker pull ghcr.io/rtvkiz/minimal-kubeconform:latest` | Kubernetes manifest validator. |
| `kube-bench` | `docker pull ghcr.io/rtvkiz/minimal-kube-bench:latest` | CIS Kubernetes benchmark checker. |
| `trufflehog` | `docker pull ghcr.io/rtvkiz/minimal-trufflehog:latest` | Secret scanner. |
| `flux` | `docker pull ghcr.io/rtvkiz/minimal-flux:latest` | Flux CD GitOps CLI. |
| `kustomize` | `docker pull ghcr.io/rtvkiz/minimal-kustomize:latest` | Kubernetes configuration customization tool. |
| `sops` | `docker pull ghcr.io/rtvkiz/minimal-sops:latest` | Secrets-file encryption tool. |
| `crane` | `docker pull ghcr.io/rtvkiz/minimal-crane:latest` | OCI registry tool from go-containerregistry. |
| `kubeseal` | `docker pull ghcr.io/rtvkiz/minimal-kubeseal:latest` | Sealed Secrets CLI. |
| `helmfile` | `docker pull ghcr.io/rtvkiz/minimal-helmfile:latest` | Declarative Helm release manager. |
| `regctl` | `docker pull ghcr.io/rtvkiz/minimal-regctl:latest` | OCI registry client from regclient. |
| `stern` | `docker pull ghcr.io/rtvkiz/minimal-stern:latest` | Multi-pod Kubernetes log tailing tool. |
| `gitleaks` | `docker pull ghcr.io/rtvkiz/minimal-gitleaks:latest` | Secret scanner. |
| `step-cli` | `docker pull ghcr.io/rtvkiz/minimal-step-cli:latest` | Smallstep PKI and certificate CLI. |
| `opa` | `docker pull ghcr.io/rtvkiz/minimal-opa:latest` | Open Policy Agent policy engine. |
| **Apps** |  |  |
| `jenkins` | `docker pull ghcr.io/rtvkiz/minimal-jenkins:latest` | Jenkins with a custom jlink JRE. |
| `gitea` | `docker pull ghcr.io/rtvkiz/minimal-gitea:latest` | Self-hosted Git service. |
| `minio` | `docker pull ghcr.io/rtvkiz/minimal-minio:latest` | S3-compatible object storage. |
| `rails` | `docker pull ghcr.io/rtvkiz/minimal-rails:latest` | Ruby on Rails runtime. |
| `mailpit` | `docker pull ghcr.io/rtvkiz/minimal-mailpit:latest` | SMTP and email testing tool. |

</details>

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

Pin production deployments by digest when you need an immutable artifact:

```dockerfile
FROM ghcr.io/rtvkiz/minimal-python@sha256:<digest>
```

Published tags serve different purposes:

| Reference | Example | Behavior |
|---|---|---|
| Digest | `minimal-python@sha256:…` | Immutable content identity; preferred for deployment pinning. |
| Version | `minimal-caddy:2.11.4-r0` | Moves when that application version is rebuilt with newer packages. |
| Dated version | `minimal-caddy:2.11.4-r0-20260725` | Build-history tag; may move if the image is rebuilt again on the same UTC date. |
| Minor line | `minimal-caddy:2.11` | Tracks the newest patch within that minor line. |
| Major line | `minimal-caddy:2` | Tracks the newest release within that major line; does not cross a major bump. |
| Latest | `minimal-caddy:latest` | Tracks the newest published production build, **including across major versions**. |
| Dev | `minimal-caddy:latest-dev` | Tracks the newest development/debug variant. |

Pin a major line (`:2`) if you want ongoing patches without being moved across a
breaking upstream release — `:latest` will cross a major bump, an exact version
tag never moves forward at all. Every tag above has a `-dev` companion
(`:2-dev`, `:2.11-dev`).

Two exceptions, by design: images on a `0.x` version publish only the minor line
(`:0.42`, not `:0`) because semver permits breaking changes between `0.x` minors;
and calendar-versioned images (minio, `2025.10.15`) publish no line tags at all.

The Melange epoch resets to `r0` on an upstream application-version bump. It increments when the recipe itself changes while the upstream version stays the same.

### Development variants

All 91 images publish a `:latest-dev` companion. Prod and dev consume the same primary package from the same build; the dev image adds a shell, package manager, and image-appropriate build or debugging tools.

Dev variants are intended for multi-stage builds and in-cluster debugging, not production workloads:

```dockerfile
FROM ghcr.io/rtvkiz/minimal-ruby:latest-dev AS build
WORKDIR /work
COPY Gemfile Gemfile.lock ./
RUN bundle install

FROM ghcr.io/rtvkiz/minimal-ruby:latest
COPY --from=build /work /work
```

Dev images retain the production entrypoint. Override it for an interactive shell:

```bash
docker run -it --entrypoint /bin/sh \
  ghcr.io/rtvkiz/minimal-caddy:latest-dev
```

Dev images use the same signing, SBOM, provenance, and publish pipeline as prod. They are not included in the public CVE dashboard because their intentionally larger toolchain surface is not representative of the production image. Composition rules are documented in [`docs/dev-variants/CONVENTIONS.md`](docs/dev-variants/CONVENTIONS.md).

## How images stay current

Image maintenance uses separate loops because rebuilding an image and upgrading its application are different operations.

### 1. Six-hour rebuilds

[`build.yml`](.github/workflows/build.yml) rebuilds the complete catalog every six hours. It keeps the currently pinned application version but consumes current Wolfi packages, toolchains, and any dependency-patch block already stored in the recipe.

For a source-built image, the pipeline is:

```text
verified source archive
  → native x86_64 and ARM64 Melange packages
  → production and dev Apko images
  → smoke test and production-image Grype scan
  → multi-architecture publish
  → Cosign signature, SPDX SBOM, and SLSA provenance
  → verification and catalog artifacts
```

Pull requests build and test but do not publish. Only trusted non-PR runs publish to GHCR.

### 2. Application-version updates

[`update-versions.yml`](.github/workflows/update-versions.yml) checks 80 source-built applications daily using the declarative registry in [`.github/versions.yaml`](.github/versions.yaml). It updates the application version, verifies the upstream artifact checksum, resets the epoch, opens a PR, and enables auto-merge after required checks pass.

Major-version pins stop unattended breaking upgrades. A new major can create an issue for explicit review instead.

MinIO's date-based release tags are handled separately by [`update-minio.yml`](.github/workflows/update-minio.yml).

For package-based images:

- Rolling Wolfi package names (`nginx-mainline`, `apache2`, `sqlite`, `bun`) advance through the six-hour rebuild.
- Versioned Wolfi package families (Python, Go, Node.js, .NET, Java, PostgreSQL) receive patch releases through rebuilds, while [`update-wolfi-packages.yml`](.github/workflows/update-wolfi-packages.yml) opens PRs when the package family itself must change.

CI enforces complete update coverage using [`.github/autoupdate-coverage.yaml`](.github/autoupdate-coverage.yaml).

### 3. Transitive dependency patches

[`patch-go-deps.yml`](.github/workflows/patch-go-deps.yml) scans published Go binaries every six hours and proposes targeted module updates for fixable vulnerabilities. It preserves existing security pins, harmonizes related module families, and uses compile-before-keep checks for dependency-sensitive applications.

[`patch-deps.yml`](.github/workflows/patch-deps.yml) performs the corresponding work for:

- Rails gems.
- Qdrant Rust crates.
- Keycloak Maven dependencies.
- Bundled Java archives in OpenSearch and Keycloak.

Cassandra, Solr, and Pulsar bundled-JAR findings are report-only until their tightly coupled dependency families receive an explicit compatibility review.

Generated changes are committed to automated PRs. The normal image build is the integration gate before auto-merge.

### 4. Catalog and retention workflows

| Workflow | Trigger | Responsibility |
|---|---|---|
| [`deploy-site.yml`](.github/workflows/deploy-site.yml) | Successful full build or site/catalog change | Builds `minimalcontainers.com` from recent complete scan and SBOM artifacts. |
| [`auto-update-pr-branches.yml`](.github/workflows/auto-update-pr-branches.yml) | Push to `main` and every 30 minutes | Updates behind auto-merge PR branches so strict branch protection can continue. |
| [`lint.yml`](.github/workflows/lint.yml) | Workflow or script changes | Runs Actionlint and ShellCheck before scheduled automation reaches `main`. |
| [`cleanup-packages.yml`](.github/workflows/cleanup-packages.yml) | Weekly and manual | Reports untagged/expired dated versions; deletion is dry-run unless explicitly enabled. |

## Understanding vulnerability results

A successful build does not mean an image has zero reported vulnerabilities.

- Grype scans production images and publishes raw JSON and SARIF results.
- OpenVEX documents can mark a finding `not_affected` or `fixed` with justification.
- The catalog shows both raw and VEX-effective counts.
- VEX documents are schema-validated, and stale or newly fixable statements produce drift warnings.
- Vulnerability findings are currently informational; the build has no global severity threshold that blocks publication.
- Dev images are intentionally excluded from the public CVE dashboard.

See [`tools/vex/README.md`](tools/vex/README.md) for the VEX workflow.

## Build locally

Install the same major tools used by CI:

```bash
go install chainguard.dev/apko@v1.1.6
go install chainguard.dev/melange@v0.41.1
brew install anchore/grype/grype
```

Build and test an Apko-only image:

```bash
make python
make test-python
```

Build and test a source-built image:

```bash
make caddy-melange
make caddy
make test-caddy
```

The authoritative onboarding and pre-push checklist is in [`docs/onboarding.md`](docs/onboarding.md). See the [Makefile](Makefile) for all local targets.

## Project structure

```text
minimal/
├── <image>/
│   ├── apko/<name>.yaml          # production image assembly
│   ├── apko/<name>-dev.yaml      # development/debug variant
│   ├── melange.yaml              # source build, when applicable
│   ├── test.sh                   # production smoke test
│   └── test-dev.sh               # development-variant smoke test
├── vex/<name>.openvex.json       # per-image vulnerability statements
├── .github/
│   ├── versions.yaml             # source-version update registry
│   ├── patch-deps.yaml           # non-Go dependency patch registry
│   ├── autoupdate-coverage.yaml  # package-based update classification
│   ├── scripts/                  # shared updater implementation
│   └── workflows/                # build, update, security, site, and cleanup automation
├── catalog.json                  # canonical public image inventory
├── docs/                         # onboarding, update, and variant standards
├── site/                         # minimalcontainers.com Astro site
├── Makefile
└── README.md
```

## Contributing

PRs are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), then use [`docs/onboarding.md`](docs/onboarding.md) for the complete image registration and validation checklist. The demand-ranked image backlog is in [`docs/roadmap.md`](docs/roadmap.md).

For security issues, use [GitHub private vulnerability reporting](https://github.com/rtvkiz/minimal/security/advisories/new) instead of opening a public issue.

## License

The repository is MIT-licensed; see [LICENSE](LICENSE). Container images include Wolfi and upstream packages under their respective licenses. Package and license details are available in each image's attached SPDX SBOM.
