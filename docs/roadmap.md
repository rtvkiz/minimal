# Image Roadmap — the road to 100 (demand-ranked)

**Status: 124 images — the 100 target is met.** This is the source-of-truth plan for
growing the catalog. The tier tables below stay useful as the demand-ranked backlog;
the "road to 100" batch section near the end is kept as a build log of how the first
100 were reached, not as remaining work.
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
| [x] | cmctl | cert-manager/cmctl | 🟢 Apache-2.0 | — | 1k | cert-manager CLI — the "klone build" note below was wrong: `go_cmctl_main_dir := .` builds the repo root directly with four plain `-X` ldflags (`make/00_mod.mk`); klone only vendors cert-manager's own shared Makefile tooling, it is not a build dependency. Generated API-conversion code ships pre-committed. |

**Reclassified out of Tier 1 (not clean Go single-binaries — moved to "deferred"):**
- **pomerium** — huge demand (1.6B pulls) but `//go:embed`s an arch-specific **Envoy** binary as its data plane → Tier-3-complexity build, own effort.

## Tier 2 — solid demand, easy Go CLIs

| ✓ | Image | Upstream | License | 🐳 pulls | ⭐ | Notes |
|---|---|---|---|---:|---:|---|
| [x] | helmfile | helmfile/helmfile | 🟢 MIT | — | 5k | declarative Helm, CD pipelines |
| [x] | regctl | regclient/regclient | 🟢 Apache-2.0 | — | 2k | registry client, CI |
| [x] | stern | stern/stern | 🟢 Apache-2.0 | — | 5k | multi-pod log tail (borderline: often local) |
| [x] | kube-vip | kube-vip/kube-vip | 🟢 Apache-2.0 | — | 3k | control-plane VIP + LB for bare metal — shipped; runs as root (NET_ADMIN/NET_RAW for netlink+ARP) |

## Tier 3 — high demand, heavier builds (deliberate; fills thin DB/proxy/app categories)

Real container demand, but C/Rust/C++/Node — each is its own effort, not a crank. Sequence
by effort. Fills the catalog's thinnest categories (databases, proxies, apps).

| ✓ | Image | Upstream | License | Build | 🐳 pulls | ⭐ | Notes |
|---|---|---|---|---|---:|---:|---|
| [x] | pgbouncer | pgbouncer/pgbouncer | 🟢 ISC | C | 20M | 4k | Postgres pooler (thin DB cat) — shipped; underscore tags (tag-rewrite) |
| [x] | unbound | NLnetLabs/unbound | 🟢 BSD | C | 12M | 5k | DNS resolver — shipped; `--sbindir=/usr/bin`, builtin evloop, local-data smoke test |
| [ ] | ~~varnish~~ | varnishcache/varnish-cache | 🟢 BSD | C | 21M | 4k | **Deferred → see below.** varnishd compiles VCL with `cc` at runtime → needs gcc+binutils+headers in prod (breaks the shell-less/minimal thesis). |
| [ ] | apisix | apache/apisix | 🟢 Apache-2.0 | C/Lua/OpenResty | 37M | 17k | API gateway (harder: OpenResty) |
| [x] | vaultwarden | dani-garcia/vaultwarden | 🟡 AGPL-3.0 | Rust | 304M | 64k | self-hosted Bitwarden — shipped |
| [x] | kvrocks | apache/kvrocks | 🟢 Apache-2.0 | C++ | 3.5M | 4k | Redis-on-RocksDB — shipped |
| [x] | patroni | patroni/patroni | 🟢 MIT | Python | — | 9k | Postgres HA — shipped; first Python-daemon pattern |
| [ ] | ~~woodpecker~~ | woodpecker-ci/woodpecker | 🟢 Apache-2.0 | Go+frontend | 2.7M | 7k | **Blocked → see below.** |
| [x] | zipkin | openzipkin/zipkin | 🟢 Apache-2.0 | JVM-jlink | 60M | 17k | distributed tracing — shipped; Spring Boot fat jar EXPLODED so its 157 bundled jars are scannable/patchable |
| [x] | timescaledb | timescale/timescaledb | 🟢 Apache-2.0 (APACHE_ONLY=1) | C/CMake (Postgres ext) | 123M | 19k | time-series Postgres extension — shipped 2026-10-15, see below for why it needed its own image instead of folding into postgres-slim |

## Deferred / heavier efforts (own project, not a batch)

| Image | Reason |
|---|---|
| varnish | varnishd compiles VCL → C → `.so` by invoking `cc` at runtime (`VCC_CC="exec cc … -fpic -shared -o %o %s"`), on every config load. A working prod image must therefore ship gcc + binutils + C headers + varnish's headers — a permanent compiler/attack-surface that breaks the "no compiler, minimum packages" thesis (Chainguard ships the toolchain for the same reason). Revisit only as a deliberate, documented exception, or pick a compiler-free HTTP-cache alternative. |
| kubescape | Go, but a large build — needs ~40 G local disk freed (stale `/tmp/bubblewrap-guest-*`). Recipe already generated in batch-b; onboard once disk allows. |
| pomerium | 1.6B pulls but `//go:embed`s an arch-specific Envoy binary (data plane). Needs an Envoy-fetch step + cross-arch handling — Envoy-image-class effort, not a clean crank. |
| cert-manager (core) | Multi-image (controller + webhook + cainjector + startupapicheck + acmesolver). High demand, in-cluster. Mirror the upstream image split — own effort after Tier 1. |
| flux (controllers) | source/kustomize/helm/notification-controller, separate repos. Multi-image, in-cluster. Own effort. |
| uptime-kuma | 166M pulls (MIT) but Node/yarn frontend → the bwrap frontend quagmire (see grafana). Backend-from-source + prebuilt frontend assets, own effort. |
| pgadmin4 | **Blocked — frontend-in-bwrap, verified 2026-10-14.** Upstream's own `Dockerfile` builds `web/` with `yarn install --immutable && yarn run bundle` in a Node stage; no prebuilt JS bundle is committed to the repo and no sdist/wheel ships one either. Same shape as alloy/authelia. argocd was in this same bucket from-source (embeds a yarn-built React UI) but shipped anyway via Wolfi's pre-built package instead — see Tier W2 below, same resolution as kong/couchdb avoiding their own from-source build problems. |
| apisix | **Blocked, verified 2026-10-16.** Wolfi packages `apisix-ingress-controller` (the Kubernetes controller, Go) but not bare `apisix` itself (the OpenResty/Lua data plane) — confirmed against the live APKINDEX, no `apisix`/`apisix-N.N` package of any kind exists. Building apisix from source means building the full OpenResty+LuaJIT stack ourselves, the same class of runtime-config-compile concern that keeps varnish deferred (apisix's routes/plugins are Lua evaluated at request time, not compiled upfront, so this needs its own licensing/attack-surface read before attempting — not a quick crank). Revisit only as a deliberate, documented exception like varnish, or wait for Wolfi to package it. |
| woodpecker (server) | **Blocked — frontend-in-bwrap, verified 2026-10-15.** `web/` is source-only (`src/`, `package.json`, `pnpm-lock.yaml`, no `dist/`), and `web/web.go`'s `//go:embed all:dist/*` (the default, non-`external_web`-tagged build) hard-requires that directory at compile time. Upstream's own `make build-server` depends on `build-ui` (pnpm). Confirmed via `make build-agent`/`make build-cli`: **those two targets never touch `web/` at all** (plain `CGO_ENABLED=0 go build ./cmd/agent`\|`./cmd/cli`, no frontend dependency) — but the agent/cli alone don't serve the "self-hosted CI server" demand this item tracks (nobody runs just an agent with no server to connect to), so not shipped as a consolation. Revisit only if there's standalone demand for the agent/cli, or the frontend-in-bwrap pattern gets solved generally. |

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

## Road to 100 — remaining batches (F–K), policy × usage × license

Ordered by our **proven build templates first** (fastest impact-per-effort), then demand.
Policy filter = buildable under the shell-less/minimal thesis: ✅ static-Go binary · clean
C daemon (no *runtime* compiler — the varnish lesson) · JVM-jlink · interpreter ·
binary-repackage. Excluded from the 100-path: frontend-in-bwrap (grafana/argocd/uptime-kuma),
runtime-compiler (varnish), tangled force-bump graphs, huge-disk C++ (clickhouse), and
🔴 SSPL/BUSL/EULA. This section is a completed build log — the 100 target was reached and
the catalog now stands at 108.

### Batch F — static Go (the crank) → 88   [DONE]
| Image | Upstream | License | Build notes |
|---|---|---|---|
| external-dns | kubernetes-sigs/external-dns v0.21.0 | 🟢 Apache | main `.`, CGO=0, `-X …/pkg/apis/externaldns.Version` |
| velero | vmware-tanzu/velero v1.18.2 | 🟢 Apache | main `./cmd/velero`, CGO=0, `…/pkg/buildinfo.Version` |
| kaniko | GoogleContainerTools/kaniko v1.24.0 | 🟢 Apache | main `./cmd/executor` (binary `executor` → /kaniko/executor), `…/pkg/version.version` |
| step-ca | smallstep/certificates v0.30.2 | 🟢 Apache | main `./cmd/step-ca`, CGO=0 (drops pkcs11 KMS), `-X main.Version`; server |
| skopeo | containers/skopeo v1.23.0 | 🟢 Apache | module `go.podman.io/skopeo`; CGO=0 + `-tags containers_image_openpgp` drops libgpgme/btrfs |

### Batch G — clean C daemon (pgbouncer/unbound template) → 93   [DONE]
| Image | Upstream | License | Build notes |
|---|---|---|---|
| dnsmasq | Wolfi `dnsmasq` 2.93 | 🟡 GPL-2.0-or-later | **apko-only** — Wolfi packages it, so no melange recipe and no `versions.yaml` row (classified `wolfi-rolling`). Flag-driven: the package ships no config and apko cannot author file contents, so `--conf-file=` disables config lookup and `--log-facility=-` moves logs off syslog. |
| keepalived | acassen/keepalived 2.4.3 | 🟡 GPL-2.0-or-later | source-built; `--disable-dbus --disable-snmp --with-init=none`, `--sbindir=/usr/bin` (usrmerge). Needs CAP_NET_ADMIN/NET_RAW/NET_BROADCAST at runtime — still runs as nonroot 65532. `github-tags` needs `strip-prefix: 'v'`, **not** `strip-v` (that key is only read by other source types). |

Fills thin **Infrastructure**.

### Batch H — JVM-jlink (kafka/zookeeper template)
cassandra (🟢 wide-column DB, Java-17 + jamm agent) · solr (🟢 search, Java-21) ·
pulsar (🟢 messaging, Java-21) · flink (🟢 stream processing, Java-21) — **all DONE**.
All Apache. Fills thin DB/search/messaging.

### Batch I — Rust (qdrant/vector precedent, own effort each)
vector (🟢 MPL-2.0, observability pipeline) · vaultwarden (🟡 AGPL-3.0, Bitwarden
server; ~304M pulls) — **both DONE**.

### Batch J — Erlang / Python
patroni (🟢 MIT, Postgres HA — new Python-daemon pattern) — **DONE**.
couchdb (🟢 Apache, Erlang — rabbitmq precedent) remaining.

### Batch K — own-effort revisit
cmctl shipped 2026-10-14 (the klone build was never a real blocker — see Tier 1 note).
Remaining: one of {cert-manager core (multi-image) / pomerium (Envoy fetch) / apisix (OpenResty)}.

Batches H–K name more candidates than the 4 slots left to 100; the last slots go to
whichever land first.

**Beyond the 100-path (deliberate exceptions, not scheduled):** varnish (runtime cc), grafana/argocd/uptime-kuma
(frontend-in-bwrap), clickhouse/kubescape (disk-cap). See the deferred table above.

## Wave 2 — beyond 108 (demand-ranked, re-surveyed 2026-08-30)

Candidate survey after the 100 target was met. Same lens as above (license ·
container demand · use case), with one new input: **many of these already have a
Wolfi package**, which moves them from "own effort" into the cheapest bucket we
have (apko-only, `dnsmasq`/`vector` precedent — no melange recipe, no
`versions.yaml` row, just an `autoupdate-coverage.yaml` classification).

Pull counts are Docker Hub `pull_count` read on 2026-08-30; treat as
order-of-magnitude (cumulative, CI/bot-inflated).

### Tier W1 — apko-only from an existing Wolfi package (cheapest crank)

Verified present in the Wolfi `x86_64` APKINDEX on 2026-08-30. `(v)` = versioned
package ⇒ `wolfi-versioned`; `(r)` = unversioned/rolling ⇒ `wolfi-rolling`.

| ✓ | Image | Wolfi package | License | 🐳 pulls | Category | Notes |
|---|---|---|---|---:|---|---|
| [ ] | wordpress | `wordpress` (r) + `wordpress-oci-entrypoint` | 🟡 GPL-2.0-or-later | 1.5B | Apps | Largest single demand number in the survey. Pairs with our `php`/`httpd`; Wolfi ships the OCI entrypoint too. Fills the thinnest category (Apps, 6). Note: shipped separately as our own `wordpress` (php-fpm, not this Wolfi package) — see W3 note below on why sonarqube/nextcloud didn't follow the same cheap path. |
| moved → W3 | sonarqube | `sonarqube` (r) | 🟡 LGPL-3.0 | 1.2B | K8s, CI & IaC | **Reclassified 2026-09-28: not W1.** See Tier W3. |
| moved → W3 | nextcloud | `nextcloud-server-33` (v) | 🟡 AGPL-3.0 | 1.0B | Apps | **Reclassified 2026-09-28: not W1.** See Tier W3. |
| [ ] | maven | `maven-3.9` (v) | 🟢 Apache-2.0 | 767M | Languages & Runtimes | Build-tool image on top of our `java`. Near-zero effort, very high demand. |
| [x] | kong | `kong` (r) + coreutils + busybox | 🟢 Apache-2.0 | 359M | Web Servers & Proxies | **Shipped 2026-09-28.** Not `kong-entrypoint` (needs bash for KONG_* env translation that CLI/env overrides already do). Two real gaps found in the Wolfi package: LuaJIT's shared lib isn't on the default loader path (needs `LD_LIBRARY_PATH`), and `kong start` shells out `ulimit -n` internally — carries `busybox` only (never bash) for that one call, same exception shape as the postgres family. |
| [x] | neo4j | `neo4j-2025.12` (v) | 🟡 GPL-3.0 | 322M | Databases | **Shipped** (source-built, ahead of this survey). |
| [ ] | gradle | `gradle-9` (v) | 🟢 Apache-2.0 | 300M | Languages & Runtimes | Same shape as maven. |
| [x] | perl | `perl` (r) | 🟡 Artistic-1.0 / GPL-1.0+ | 255M | Languages & Runtimes | **Shipped** (source-built, ahead of this survey). |
| [x] | couchdb | `couchdb-3.3` (v) + busybox | 🟢 Apache-2.0 | 205M | Databases | **Shipped 2026-09-28.** `/usr/bin/couchdb` is itself a `#!/bin/sh` launcher script that builds the `erlexec` command line — no way to start it without a shell, so it carries `busybox` only (never bash), same exception shape as the postgres family. No admin account ships by default (CouchDB refuses to boot without one) — mount your own `local.ini`. |
| [x] | argo-cd | `argo-cd-3.4` + `-repo-server` (v) | 🟢 Apache-2.0 | 148M | K8s, CI & IaC | **Shipped 2026-10-16, as two images.** Wolfi packaging removes the yarn-frontend build entirely - `argo-cd-3.4` is a pure static Go binary, no `D:` deps at all, genuinely shell-less. `argo-cd-3.4-repo-server` carries real runtime deps (git/git-lfs/gnupg/helm~3/kustomize/openssh/tzdata) as apk dependencies, and its own packaged entrypoint (`uid_entrypoint.sh`) needs a shell to patch `/etc/passwd` for an arbitrary runtime UID - bypassed entirely by setting `run-as: 65532` directly and execing `/usr/local/bin/argocd-repo-server` (the `-compat` package's symlink set) as the entrypoint, so this image is shell-less too despite the tooling. Verified for real, not assumed: built and smoke-tested locally (prod+dev, both images, x86_64) - repo-server actually boots and opens its gRPC port on :8081 with no shell present. |
| [ ] | rust | `rust-1.92` (v) | 🟢 MIT OR Apache-2.0 | 143M | Languages & Runtimes | Toolchain image (builder-shaped, like our `go`). |
| [x] | erlang | `erlang-28` (v) | 🟢 Apache-2.0 | 65M | Languages & Runtimes | **Shipped** (source-built, ahead of this survey). |
| [x] | meilisearch | source-built | 🟢 MIT | 51M | Databases | Wolfi lagged seven releases, so v1.53.2 was built from source using the established Rust pattern. |
| [x] | temporal | source-built (temporal-server/-admin-tools/-ui-server) | 🟢 MIT | 47M | Apps | **Shipped** (source-built, three images, ahead of this survey — not the single apko-only `temporal` package this row originally named). |

**Also packaged in Wolfi, parked deliberately:** `argo-workflows` (🟢 Apache — take
with argo-cd or not at all), `mattermost-11.4` (⚠️ mixed AGPL + Mattermost Source
Available License in the same tree — needs a license read before onboarding),
`apisix-ingress-controller` (🟢 Apache — note Wolfi packages the *controller*,
not apisix itself, so the Tier-3 apisix entry above is unchanged).

**Harbor — partially shipped, 2026-10-24.** `harbor-2.14-portal` (UI + nginx
reverse proxy) shipped as `harbor-portal`: cheap to build and smoke-test, same
shape as our other nginx-fronted apko images. The rest of the stack
(`harbor-2.14` core, `harbor-2.14-jobservice`, `harbor-2.14-registryctl` +
`harbor-registry`) remains deliberately deferred: none of those binaries has a
graceful `--version`/`--help` exit — every invocation falls straight into full
startup, which reads `conf/app.conf`/`config.yml` and then needs live
Postgres **and** Redis to get anywhere. A real smoke test for those three means
a 3-container compose plus hand-authored config, not a `make test-<name>`
one-liner — genuinely the "own effort like cert-manager" scope the original
entry called out, confirmed empirically (binaries extracted and run directly)
rather than assumed from the packaging.

### Wave 3 survey — verified 2026-09-07

Re-checked every W1/W2 candidate against the **live** Wolfi APKINDEX (120,016
packages) and a Chainguard free-tier probe, after the W1 table was found wrong
twice: it listed a `gitlab-runner-18.11` package that was actually
`gitlab-agent-*` (a different product), and a bare-name APKINDEX grep misses
versioned packages entirely. Method that actually works — check three things,
not one:

```
grep -x  "P:<name>"        APKINDEX   # exact package name
grep -E  "^P:<name>-[0-9]"  APKINDEX   # versioned package (gitlab-runner-19.3)
grep -E  "^p:(.* )?<name>=" APKINDEX   # a DIFFERENT package that provides the name
```

The Chainguard probe (validated against known-free nginx/python/static, which
all return 200) is an anonymous pull-token request against
`cgr.dev/v2/chainguard/<name>/manifests/latest`.

**Already free from Chainguard — dropped from the plan.** These were the
roadmap's "near-zero effort, very high demand" picks, and there is no reason to
publish a second free hardened build of something already free elsewhere:

| Image | 🐳 pulls | Why dropped |
|---|---:|---|
| wordpress | 1.5B | `cgr.dev/chainguard/wordpress` returns 200 anonymously |
| maven | 767M | free |
| gradle | 300M | free |
| rust | 143M | free |

**Gated on Chainguard and packaged in Wolfi** — the cheap, high-demand bucket.
Pull counts read from Docker Hub on 2026-09-07:

| Image | 🐳 pulls | License | Category | Note |
|---|---:|---|---|---|
| sonarqube | 1.3B | 🟡 LGPL-3.0 | K8s, CI & IaC | Heavier than the packaging suggests: bundles Elasticsearch, needs an external Postgres |
| nextcloud | 1.1B | 🟡 AGPL-3.0 | Apps | `nextcloud-server-33` (+ `-apache2-config`). PHP-FPM |
| kong | 360M | 🟢 Apache-2.0 | Web Servers & Proxies | The Wolfi package removes the OpenResty/Lua build that keeps apisix deferred |
| neo4j | 323M | 🟡 GPL-3.0 | Databases | Graph DB — a category with zero coverage today |
| perl | 255M | 🟡 Artistic/GPL | Languages & Runtimes | Trivial; the last mainstream scripting runtime missing |
| couchdb | 205M | 🟢 Apache-2.0 | Databases | |
| erlang | 66M | 🟢 Apache-2.0 | Languages & Runtimes | Companion to rabbitmq |
| meilisearch | 52M | 🟢 MIT | Databases | **Shipped source-built** because Wolfi lagged seven upstream releases. |
| temporal | 48M | 🟢 MIT | Apps | Durable execution; fills the thinnest category |
| cert-manager · keda · karpenter · harbor · zot | — | 🟢 Apache-2.0 | K8s, CI & IaC | All in Wolfi, all gated on Chainguard. **No pull counts exist** — they publish to quay/ghcr/registry.k8s.io, so demand cannot be ranked the way the rest of this table is. (argo-cd was in this row too — **shipped 2026-10-16**, see Tier W2. keda and zot shipped since; harbor's portal component shipped 2026-10-24, core/jobservice/registryctl still deferred — see the Harbor note above.) |

**The finding that shapes the next wave:** the source-built well has run dry at
the top of the demand curve. Every remaining high-demand candidate is either
Wolfi-packaged (so apko-only), blocked by a frontend build (alloy, authelia,
woodpecker), or already free from Chainguard. What is left to build from source
is genuinely hard and much lower demand: influxdb (1.2B, but that number is
v1/v2 — current upstream is a Rust rewrite), apisix (37M, OpenResty), emqx
(Erlang, licence read needed), fluentd (Ruby). kvrocks and timescaledb (split
licence, shipped 2026-10-15 via upstream's own `-DAPACHE_ONLY=1` flag) are
done; pgadmin4 and woodpecker (both frontend-in-bwrap) are blocked, see above.

So Wave 3 is a **decision**, not a queue: continue insisting on source builds
and accept far lower demand per unit of effort, or take the apko-only route for
things Chainguard gates. Note that apko-only is not a weaker product here — the
Wolfi package is free, Chainguard's *image* is not, so a hardened signed
SBOM-attested rebuild of a gated image is exactly the gap this catalogue
exists to fill. It also keeps full auto-update coverage via
`autoupdate-coverage.yaml`, which `check-autoupdate` enforces.

### Tier W2 — source-built Go (the proven crank; no Wolfi package)

| ✓ | Image | Upstream | License | 🐳 pulls | Category | Notes |
|---|---|---|---|---:|---|---|
| [x] | gitlab-runner | gitlab-org/gitlab-runner | 🟢 MIT | 3.6B | K8s, CI & IaC | **Shipped** — source-built. Wolfi *does* ship it as the versioned `gitlab-runner-19.3`, which `p:`-provides the bare name, so `provider-priority: 100` was mandatory; without it apko silently installed Wolfi's binary over ours. versions.yaml uses `type: json` against the GitLab tags API. |
| [x] | buildkit | moby/buildkit | 🟢 Apache-2.0 | 1.8B | K8s, CI & IaC | **Shipped** — source-built. `provider-priority: 100` needed too (Wolfi's `buildkitd` provides `buildkit`). buildkitd is the only CGO_ENABLED=1 build in the catalogue, to keep upstream's `seccomp` tag; `libseccomp-static` keeps it static. Runs as **root** — it refuses unprivileged uids, and the rootless path needs setuid newuidmap Wolfi does not ship setuid. |
| [ ] | ~~alloy~~ | grafana/alloy | 🟢 Apache-2.0 | 388M | Observability | **Blocked — frontend-in-bwrap, verified 2026-09-06.** `internal/web/ui/dist` is NOT committed; `assets_builtin.go` is behind `//go:build embedalloyui` whose `go:generate` runs `npm ci && npm run build`, and the `!embedalloyui` fallback serves from a runtime filesystem path that will not exist in the image. So there is no UI-bearing build without npm in the sandbox. Demand is real (inherits EOL promtail 2.8B + grafana-agent 470M) — reconsider if we ever take on a frontend build pattern. |
| [ ] | ~~authelia~~ | authelia/authelia | 🟢 Apache-2.0 | 81M | Web Servers & Proxies | **Blocked — frontend-in-bwrap, verified 2026-09-06.** `internal/server/public_html` contains only 3 files (index.html + the openapi pair); the React bundle is built from `web/` by pnpm and is not in the tarball. Same blocker as alloy. |
| [x] | syncthing | syncthing/syncthing | 🟢 MPL-2.0 | 346M (two repos) | Infrastructure | **Shipped** — confirmed the easiest build in this table. `CGO_ENABLED=0` picks the pure-Go `modernc.org/sqlite` driver v2.x needs; the web GUI is `.gitignore`'d upstream and regenerated by `script/genassets.go`, which is plain Go — no npm step. Built `-tags noupgrade` like upstream's own container. |
| [x] | nsq | nsqio/nsq | 🟢 MIT | 63M | Caches, Queues & Messaging | **Shipped** — was indeed about an hour. Ships all nine upstream binaries for drop-in parity with `nsqio/nsq`; nsqadmin's web assets are committed pre-built and pulled in via `go:embed`. Note upstream is quiet (v1.3.0, Dec 2023), so its auto-update loop will be idle by design. |

### Tier W3 — heavier / needs a decision

| Image | Why it's not W1/W2 |
|---|---|
| influxdb | 1.1B pulls on `library/influxdb`, but that number is v1/v2 (Go, MIT); current upstream is **InfluxDB 3 Core in Rust** (🟢 Apache-2.0), no Wolfi package, and our time-series slot is already served by prometheus/mimir/victoria-metrics/thanos. Worth it only if we want line-protocol coverage. |
| emqx | 47M pulls, but the repo is `NOASSERTION` (Apache core + BSL-ish enterprise pieces) and it's a large Erlang build. License read required first. |
| pgadmin4 | **Blocked — frontend-in-bwrap, verified 2026-10-14.** 444M pulls (🟢 PostgreSQL license), but there is no prebuilt frontend: upstream's own `Dockerfile` builds `web/` from source with `yarn install --immutable && yarn run bundle`. Moved to the deferred table above. |
| nextcloud | **Reclassified from W1, verified 2026-09-28.** `nextcloud-server-33` (307MB) bundles the full upstream Docker entrypoint model: Apache + PHP-FPM + cron + `docker-entrypoint-hooks.d` + `su-exec`, designed to boot as **root**, fix ownership, then `su -p "$user"` to a www-data-equivalent account for the actual server process — except that account does not exist in this package's `/etc/passwd`. That's an architecture mismatch with our nonroot-by-default model, not a config tweak: needs either a real user added at the apko layer plus reworking the entrypoint's privilege-drop assumptions, or accepting a root-then-drop exception like the postgres family but scoped to a much bigger, more stateful app (occ install flow, external DB requirement, persistent config/data volumes). Own effort, like harbor/argo-cd. |
| sonarqube | **Reclassified from W1, verified 2026-09-28.** `sonarqube-10` (874MB) hard-depends on `bash`, `systemd-dev`, `zstd-dev`, and its own `sonarqube-startup` wrapper package — heavier packaging than a plain Java web app suggests. Bundles Elasticsearch internally and needs an external Postgres to run at all, so a meaningful smoke test is a multi-container compose, not a single `docker run`. Own effort, like harbor/argo-cd. |

### Confirmed avoid (🔴 non-OSS) — checked in this survey

`terraform` (492M) · `vault` (554M) · `nomad` · `boundary` · `waypoint` — all
BUSL-1.1; already covered by our `opentofu` and `openbao`. `elasticsearch` /
`kibana` / `logstash` — Elastic License; covered by `opensearch`. `redpanda`
(35M) — BSL. `n8n` — Sustainable Use License. No change to the policy.

### Suggested first PR out of this survey

Six images, all W1, no new build template, spanning four categories:
**gitlab-runner · wordpress · maven · gradle · kong · perl** — the two largest
demand numbers we're missing, the two cheapest Languages entries, and the first
addition to Web Servers & Proxies since oauth2-proxy.

**2026-09-28 batch:** kong + couchdb shipped (PR #779). sonarqube and nextcloud
were pulled from this wave after inspection showed they need real design work
(see the Tier W3 entries above), not a quick apko-only crank — don't onboard
either from this table's original notes without re-reading the W3 entry first.

## Execution model

- **One PR per tier group (~6–8 images).** Each image: 10 registration points
  (see `docs/onboarding.md`) incl. a validated `cron-enabled` `versions.yaml` row — the
  `check-autoupdate` gate blocks the PR otherwise.
- Build **and** prod+dev smoke-test every image locally before push (`make <img>`,
  `make test-<img>`, and assemble+test the `-dev` variant). Never push a failing image.
- Registration inserts use **Python (newline-safe)**, not bash `$(...)` (which strips
  newlines and glues YAML lines — same failure family as the batch-b dropped paren).
