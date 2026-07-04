# Dev variant conventions

This document defines what every `minimal-<image>:latest-dev` image looks like.
Every dev variant in this repo follows these rules; the per-category
templates in `./templates/` apply them to concrete `apko` configs.

## What a dev variant is

A dev variant is the prod image plus a shell, package manager, and the
build/debug tooling appropriate to the image's category. It is intended
for two use cases:

1. **Multi-stage build environments** (`FROM ...:latest-dev AS build`)
2. **In-pod debugging** (`kubectl debug --image=...:latest-dev`)

It is **not** intended for production deployment. Use the prod tag for
runtime workloads; copy artifacts out of the dev stage if you needed it
to compile something.

## What stays identical to prod

These properties are mechanical guarantees, not best-effort:

- **Same source build of the primary binary.** Both prod and dev consume
  the same melange-built `.apk` from the same workflow run. If we run
  custom curation (e.g. ruby's json bump, bundler strip), dev inherits
  that curation unchanged — dev only *adds* packages on top.
- **Same entrypoint and cmd.** A dev variant is drop-in compatible with
  its prod counterpart for `docker run IMAGE <args>` use. See
  [Entrypoint and shell access](#entrypoint-and-shell-access) below.
- **Same workdir.**
- **Same nonroot UID** (`65532`) and group.
- **Same publish cadence**: every push to main, plus the scheduled
  rebuild every 6h.
- **Same signing, SBOM, and SLSA build provenance pipeline.**

## What is intentionally different

- **Tag suffix**: prod publishes `:latest` and `:VERSION-rEPOCH`; dev
  publishes `:latest-dev` and `:VERSION-rEPOCH-dev`. There are no
  other tag variants.
- **Larger package surface**: shell, package manager, debug tools,
  build deps (per category template below).
- **Annotation**: dev images carry
  `dev.minimal.variant: "dev"`. Admission controllers can use this to
  block dev images out of production namespaces.
- **CVE policy**: dev variants are **not** tracked on the public CVE
  dashboard. Dev images intentionally ship a larger attack surface
  (compilers, shells, libcurl, etc.) and chasing CVE counts on dev
  would be busywork. The daily rebuild still picks up upstream Wolfi
  patches; we just don't publish a vuln report.

## Entrypoint and shell access

Every dev variant **keeps the prod entrypoint** (e.g. `/usr/bin/ruby`,
`/usr/sbin/nginx`, `/usr/bin/redis-server`). This is the same convention
Chainguard uses for their `-dev` images.

Rationale: `RUN bundle install` in a Dockerfile multi-stage build
invokes `/bin/sh -c` and ignores the entrypoint — so multi-stage build
works untouched. Interactive shell access requires `--entrypoint`:

```bash
docker run -it --entrypoint /bin/sh   ghcr.io/rtvkiz/minimal-<image>:latest-dev
docker run -it --entrypoint /bin/bash ghcr.io/rtvkiz/minimal-<image>:latest-dev
```

Document this in each image's README dev variant section.

## Required packages in every dev variant

Every dev variant ships at minimum:

| Package | Why |
|---|---|
| `wolfi-baselayout` | filesystem skeleton (already in prod) |
| `busybox` | `/bin/sh`, `/bin/ls`, `/bin/cat`, etc. — the minimum to drop a shell |
| `bash` | many `docker exec` / `kubectl exec` workflows assume bash |
| `apk-tools` | lets users install ad-hoc packages without rebuilding the image |
| `ca-certificates-bundle` | TLS works (already in prod for most images) |
| `wget` | quick HTTP fetches in shell sessions |

These are non-negotiable — they define the "minimum dev experience"
across the catalog.

## Category-specific additions

The three templates in `./templates/` map our 57 images to one of
three categories. Pick the template that matches and customize the
language/daemon-specific layer.

### Runtime (language / interpreter)

Use for: `python`, `node-slim`, `bun`, `go`, `deno`, `java`, `dotnet`,
`php`, `ruby` (done), `rails`.

Adds on top of the required minimum:

- Full C/C++ toolchain for native extensions: `build-base`, `gcc`,
  `binutils`, `make`, `pkgconf`, `posix-cc-wrappers`, `linux-headers`,
  `openssf-compiler-options`
- Common dev headers: `glibc-dev`, `libstdc++-dev`, `libxcrypt-dev`
- `git` for fetching dependencies (`bundle install --git`,
  `pip install git+...`, `go get`)
- Language-specific package manager **baked in** when the prod variant
  strips it (e.g. ruby's `bundler` subpackage). If Wolfi ships the
  package manager as a separate apk that's compatible with our build,
  prefer that.

### Daemon (database / cache / message broker)

Use for: `mysql`, `mariadb`, `postgres-slim`, `redis-slim`, `valkey`,
`memcached`, `kafka`, `rabbitmq`, `nats`, `etcd`, `sqlite`,
`opensearch`, `qdrant`.

Adds on top of the required minimum:

- The daemon's **client/CLI** (`psql`, `redis-cli`, `mysql`,
  `valkey-cli`, etc.)
- Connection/diagnostic tools: `curl`, `socat` (for unix sockets where
  applicable)
- For data-tier daemons: `jq` for parsing JSON output from admin
  endpoints

No C toolchain by default. Add it only if the daemon's debug workflow
involves building extensions (e.g. postgres `CREATE EXTENSION` from
source).

### Server (HTTP server / proxy)

Use for: `nginx`, `httpd`, `caddy`, `haproxy`, `traefik`, `envoy`,
`jaeger`, `otelcol`, `prometheus`, `victoria-metrics`, `loki`,
`fluent-bit`, `minio`, `coredns`, `gitea`, `jenkins`, `keycloak`,
`openbao`.

Adds on top of the required minimum:

- HTTP debugging: `curl`, `wget` (wget already in minimum)
- TLS debugging: `openssl` CLI
- Network diagnosis: `bind-tools` (dig, host), `iputils` (ping),
  `tcpdump` for the few cases where packet capture in-pod is needed
- Server-specific admin CLI if one exists (e.g. `mc` for minio,
  `nginx -t` is the binary itself)

## Where to deviate

These conventions are defaults, not laws. Deviate when:

- An upstream tool only ships as a Wolfi apk under a non-obvious name
  (e.g. `mongo-shell` vs `mongosh`).
- The daemon embeds its own debug surface (e.g. nginx `-T` dumps config;
  no extra CLI needed).
- A required minimum package conflicts with the image (`apk-tools`
  conflicts in some apko-only images that don't carry the apk DB).

In every deviation, leave a comment in the image's `apko-dev.yaml`
explaining what was dropped/added vs the template and why. Future
readers (including a 6-months-from-now-you) should be able to see the
delta at a glance.

## Source of truth for package choices

Where a Chainguard public `*-public/devConfigs` exists for the
corresponding upstream image, **start by mirroring their package set**.
They've already debugged the long tail of "what do native gem authors
actually need?" for popular runtimes.

Where Chainguard has no public dev variant (most servers + daemons in
their catalog are Enterprise-only), default to the category template.
Open an issue if a real user reports needing something the template
missed — don't speculate.

## Adding a dev variant: the 7-step checklist

For each new image:

1. Add `"variants":["prod","dev"]` to the image entry in
   `.github/workflows/build.yml`.
2. Copy the appropriate template from `./templates/` to
   `<image>/apko/<image>-dev.yaml` and fill in the customization
   comments.
3. If anything needs baking (CLIs, package managers), add a subpackage
   to `<image>/melange.yaml`. Prefer a Wolfi apk if one exists.
4. Create `<image>/test-dev.sh` mirroring `ruby/test-dev.sh`.
5. Add Makefile targets (will be a one-line macro call once Phase 0
   PR #3 lands; for now copy ruby's pattern).
6. Add the image to the dev variant tracker table in the main
   `README.md`.
7. Local validation per `CLAUDE.md`:
   `make <image>(-melange) && make <image>-dev && make test-<image> && make test-<image>-dev`.
   All four must pass before pushing.
