# Image Roadmap — the road to 100 (demand-ranked)

**Status: 83 / 100 images.** This is the source-of-truth plan for growing the catalog.
It supersedes the batch order from earlier sessions, which was ordered by *build ease* and
*GitHub popularity*. This version is ordered by **actual container demand first**, then
build effort.

## Why demand, not stars

For a hardened-**container** catalog, the metric that matters is "how often is this run as a
container," not GitHub stars. They diverge sharply:

| Image | ⭐ stars | 🐳 Docker pulls | Reality |
|---|---:|---:|---|
| dive | 54k | 1.7M | laptop image-inspector — rarely containerized |
| k9s | 34k | 169k | terminal UI run locally — almost never a prod container |
| oauth2-proxy | 15k | 97M | auth sidecar — run as a container everywhere |
| pomerium | 5k | 1.6B\* | identity-aware proxy — massive container use |

So popular-but-local tools (k9s, stern, dive, age) are **deprioritized**, and high-pull
proxies/apps (oauth2-proxy, pomerium, …) are **promoted**.

\* Docker pull counts are noisy — cumulative since inception, inflated by CI/bot pulls, and
some namespaces (bitnami/\*) are being deprecated. Treat as order-of-magnitude, not precise.

**License lens:** 🟢 permissive (MIT/BSD/Apache/MPL/ISC) add freely · 🟡 AGPL/GPL ok
(precedent: loki/tempo/mimir/minio/trufflehog) · 🔴 SSPL/BUSL/EULA avoid or fork.

**Build effort:** Go single-binary = the proven Batch-B crank (fast). C/Rust/C++ = heavier.
Node/frontend = the bwrap frontend quagmire (defer, own effort). Controllers = multi-image,
run in-cluster (high demand, more work).

---

## Tier 1 — high demand × easy Go build (do next)

Single static Go binaries **and** genuinely run as containers. Best impact-per-effort.

| ✓ | Image | Upstream | License | 🐳 pulls | ⭐ | Notes |
|---|---|---|---|---:|---:|---|
| [x] | oauth2-proxy | oauth2-proxy/oauth2-proxy | 🟢 MIT | 97M | 15k | k8s auth sidecar, ubiquitous, CG-gated (#393) |
| [x] | flux (CLI) | fluxcd/flux2 | 🟢 Apache-2.0 | 3.8M | 8k | GitOps, CG-gated — embeds install manifests (kustomize bundle at build) |
| [x] | kustomize | kubernetes-sigs/kustomize | 🟢 Apache-2.0 | 12M | 12k | CI/CD standard, CG-gated — monorepo, `kustomize/vX` tag |
| [x] | sops | getsops/sops | 🟢 MPL-2.0 | — | 22k | secrets in CI, CG-gated |
| [x] | crane | google/go-containerregistry | 🟢 Apache-2.0 | — | 4k | registry ops, heavy CI use |
| [x] | kubeseal | bitnami/sealed-secrets | 🟢 Apache-2.0 | — | 9k | sealed-secrets CLI (canonical repo, not bitnami-labs 301) |

**Reclassified out of Tier 1 (not clean Go single-binaries — moved to "deferred"):**
- **pomerium** — huge demand (1.6B pulls) but `//go:embed`s an arch-specific **Envoy** binary as its data plane → Tier-3-complexity build, own effort.
- **cmctl** — cert-manager's `makefile-modules`/klone build, no clean `-X` version injection → needs its own investigation.

## Tier 2 — solid demand, easy Go CLIs

| ✓ | Image | Upstream | License | 🐳 pulls | ⭐ | Notes |
|---|---|---|---|---:|---:|---|
| [x] | helmfile | helmfile/helmfile | 🟢 MIT | — | 5k | declarative Helm, CD pipelines |
| [x] | regctl | regclient/regclient | 🟢 Apache-2.0 | — | 2k | registry client, CI |
| [x] | stern | stern/stern | 🟢 Apache-2.0 | — | 5k | multi-pod log tail (borderline: often local) |

## Tier 3 — high demand, heavier builds (deliberate; fills thin DB/proxy/app categories)

Real container demand, but C/Rust/C++/Node — each is its own effort, not a crank. Sequence
by effort. Fills the catalog's thinnest categories (databases, proxies, apps).

| ✓ | Image | Upstream | License | Build | 🐳 pulls | ⭐ | Notes |
|---|---|---|---|---|---:|---:|---|
| [x] | pgbouncer | pgbouncer/pgbouncer | 🟢 ISC | C | 20M | 4k | Postgres pooler (thin DB cat) — shipped; underscore tags (tag-rewrite) |
| [x] | unbound | NLnetLabs/unbound | 🟢 BSD | C | 12M | 5k | DNS resolver — shipped; `--sbindir=/usr/bin`, builtin evloop, local-data smoke test |
| [ ] | ~~varnish~~ | varnishcache/varnish-cache | 🟢 BSD | C | 21M | 4k | **Deferred → see below.** varnishd compiles VCL with `cc` at runtime → needs gcc+binutils+headers in prod (breaks the shell-less/minimal thesis). |
| [ ] | apisix | apache/apisix | 🟢 Apache-2.0 | C/Lua/OpenResty | 37M | 17k | API gateway (harder: OpenResty) |
| [ ] | vaultwarden | dani-garcia/vaultwarden | 🟡 AGPL-3.0 | Rust | 304M | 64k | self-hosted Bitwarden |
| [ ] | kvrocks | apache/kvrocks | 🟢 Apache-2.0 | C++ | 3.5M | 4k | Redis-on-RocksDB |
| [ ] | patroni | patroni/patroni | 🟢 MIT | Python | — | 9k | Postgres HA (Python pattern — new) |
| [ ] | woodpecker | woodpecker-ci/woodpecker | 🟢 Apache-2.0 | Go+frontend | 2.7M | 7k | CI server (has web UI) |

## Deferred / heavier efforts (own project, not a batch)

| Image | Reason |
|---|---|
| varnish | varnishd compiles VCL → C → `.so` by invoking `cc` at runtime (`VCC_CC="exec cc … -fpic -shared -o %o %s"`), on every config load. A working prod image must therefore ship gcc + binutils + C headers + varnish's headers — a permanent compiler/attack-surface that breaks the "no compiler, minimum packages" thesis (Chainguard ships the toolchain for the same reason). Revisit only as a deliberate, documented exception, or pick a compiler-free HTTP-cache alternative. |
| kubescape | Go, but a large build — needs ~40 G local disk freed (stale `/tmp/bubblewrap-guest-*`). Recipe already generated in batch-b; onboard once disk allows. |
| pomerium | 1.6B pulls but `//go:embed`s an arch-specific Envoy binary (data plane). Needs an Envoy-fetch step + cross-arch handling — Envoy-image-class effort, not a clean crank. |
| cmctl | cert-manager's `makefile-modules`/klone build; no clean `-X` version injection. Needs its own investigation of the version mechanism. |
| cert-manager (core) | Multi-image (controller + webhook + cainjector + startupapicheck + acmesolver). High demand, in-cluster. Mirror the upstream image split — own effort after Tier 1. |
| flux (controllers) | source/kustomize/helm/notification-controller, separate repos. Multi-image, in-cluster. Own effort. |
| uptime-kuma | 166M pulls (MIT) but Node/yarn frontend → the bwrap frontend quagmire (see grafana). Backend-from-source + prebuilt frontend assets, own effort. |
| argocd | Embeds a yarn-built React UI **and** repo-server needs git/helm/kustomize at runtime (fights distroless). Grafana-bucket effort. |

## Deprioritized — popular but low container demand (laptop / CLI / embedded)

`k9s` (terminal UI) · `dive` (image inspector) · `age` (local crypto CLI) · `duckdb`
(embedded lib, not a server) · `zig`/`erlang`/`lua` (languages — official base images exist).
Add later only on explicit demand.

## Avoided — non-OSS licenses (🔴)

MongoDB / Elasticsearch (SSPL) · CockroachDB / Dragonfly (BSL). Use permissive forks if a
real need appears (e.g. `kvrocks`/`valkey` cover the Redis/BSL gap).

## Existing 🔴 exposures to resolve (pre-existing, tracked separately)

- `redis-slim` declares SSPL-1.0 but 8.x is tri-licensed → re-declare AGPL-3.0-only.
- `consul` 2.0.0 = BUSL-1.1 (no OSS fork) → keep-vs-drop decision pending.

---

## Execution model

- **One PR per tier group (~6–8 images).** Each image: 10 registration points
  (see `docs/onboarding.md`) incl. a validated `cron-enabled` `versions.yaml` row — the
  `check-autoupdate` gate blocks the PR otherwise.
- Build **and** prod+dev smoke-test every image locally before push (`make <img>`,
  `make test-<img>`, and assemble+test the `-dev` variant). Never push a failing image.
- Registration inserts use **Python (newline-safe)**, not bash `$(...)` (which strips
  newlines and glues YAML lines — same failure family as the batch-b dropped paren).
