# Plan: rename `<app>-minimal` apk packages to upstream names

Status: **in progress**. 20 of the 26 wave 1+2 images renamed (wave 1: 15 of 16,
wave 2: 5 of 10), plus the `redis` pilot — 21 renamed in total. 64 melange.yaml
files still carry the suffix: the 58 wave 3 Go images plus the 6 deferred below.
`cuda-python` was never suffixed, so 21 + 64 + 1 = 86 melange configs.

Deferred (build too slow to validate locally, still suffixed): `mysql`,
`keycloak`, `solr`, `mariadb`, `deno`, `qdrant`.

## Problem

Syft derives a package's CPE from its apk name. A `-minimal` suffix produces
`cpe:2.3:a:haproxy-minimal:haproxy-minimal:*`, which matches nothing in NVD
(indexed as `cpe:2.3:a:haproxy:haproxy:*`) and nothing in the Wolfi secdb. **Both
of grype's matchers miss**, so the scan reports clean while the image is unscanned.

Controlled test, identical SBOM and version `2.2.0-r0`, only the name differing:

| package name | CVEs found |
|---|---|
| `haproxy-minimal` | 0 |
| `haproxy` | 14 |

Verified end to end on real images (not edited SBOMs) — see "Evidence" below.

## Severity split

Go images carry a second identity from syft's binary cataloger
(`minimal-helm` also reports `go-module helm.sh/helm/v3`), so their application
CVEs still surface. Non-Go images have **only** the apk entry and are fully blind.

| group | count | status |
|---|---|---|
| non-Go (blind) | 26 | highest priority |
| Go (partially mitigated) | 58 | lower urgency |

Measured masked CVEs at time of analysis: 8, including 2 Criticals on HAProxy 3.4.0.
Treat as a rough signal — undercounts (naive `vendor=product=name`) and overcounts
(CPE false positives).

## The change, per image

Exactly 3 files. Example, haproxy:

```diff
 # haproxy/melange.yaml
 package:
-  name: haproxy-minimal
+  name: haproxy
   version: 3.4.0
   epoch: 0
+  dependencies:
+    provider-priority: 100
```

```diff
 # haproxy/apko/haproxy.yaml  AND  haproxy/apko/haproxy-dev.yaml
   packages:
-    - haproxy-minimal
+    - haproxy
```

`site/src/data/images.json` also contains the old name but is **generated** by
`build-data.mjs`; it regenerates on the next deploy. Do not hand-edit.

### Why `provider-priority`

apko resolves a top-level package name across **all** repositories and picks the
highest version — it does **not** prefer the local repo. In
`apko@v1.1.6/pkg/apk/apk/repo.go`, `comparePackages()` sorts by: matching repo/origin
(only when `compare != nil`) → installed → installed origin → **pin** →
**ProviderPriority** → **version** → name. At line 657 a top-level request passes
`compare = nil`, so the repository tiebreak never runs.

Without a priority, any Wolfi package of the same name at a higher version silently
replaces the source-built binary, with a green build.

### Which name to use

Use the **bare upstream name**, never Wolfi's versioned variant.

Wolfi ships both (`helm` + `helm-3`/`helm-4`; `mariadb` + `mariadb-10.6`…`12.2`).
Their versioned packages are themselves CPE-poisoned — Wolfi's own `helm-4` yields
`cpe:2.3:a:helm-4:helm-4:*`, the same bug. The bare name matched **both** namespaces
in testing.

## Waves

**Wave 1 — 16 images.** Non-Go, no Wolfi name collision. Started with `haproxy`
(carried the 2 Criticals, proven 0 → 14). All landed except `mysql`.

```
cassandra envoy fluent-bit haproxy jenkins kafka keepalived mysql
opensearch php pulsar rabbitmq rails ruby tomcat zookeeper
```

**Wave 2 — 10 images.** Non-Go, Wolfi ships the same bare name;
`provider-priority` becomes load-bearing. `memcached`, `mosquitto` and `unbound`
were originally listed under wave 1 as collision-free — they are not; Wolfi ships
all three. `mosquitto` is the live case: Wolfi's 2.1.2-r1 outranks our 2.1.2-r0,
so apk resolves to Wolfi's build without `provider-priority`.

```
deno keycloak mariadb memcached mosquitto pgbouncer qdrant solr unbound valkey
```

### Known gap: NVD vendor mismatch (not fixable by renaming)

Syft builds an apk CPE from the package name alone, then applies a hardcoded
~131-entry table (`cpegenerate/candidate_by_package_type.go`) that supplies the
real NVD vendor for names it knows — `glibc`→`gnu`, `nginx`→`f5`, `ruby`→`ruby-lang`.
Renaming is what lets that lookup fire at all: `ruby-minimal` matched nothing,
`ruby` now yields `cpe:2.3:a:ruby-lang:ruby:*`.

For names absent from that table the derived vendor is just the product name,
which NVD may not use:

- **envoy** — NVD indexes 110 CVEs under `envoyproxy:envoy` and 0 under
  `envoy:envoy`. Our CPE matches none of them. Envoy is C++ with no second
  cataloger identity, so nothing covers it. Accepted as a known gap: 1.39.0 has
  no open CVE today, so nothing is currently missed, but the next one is invisible.
- **zookeeper, tomcat, cassandra, pulsar** — NVD vendor is `apache`. Covered in
  practice by their java-archive entries, which carry `cpe:2.3:a:apache:*`.

melange's `package.cpe:` field does **not** fix this. melange ≥ v0.46.0 writes it
into the package SBOM (we run v0.41.1, which accepts the field but only uses it
for the gcc `.note.package` metadata), but syft's apk cataloger ignores the SBOM
CPE entirely — verified against melange v0.58.0 and syft v1.51.0. The real fixes
are an upstream entry in syft's table, or post-processing our published SBOM.

**Wave 3 — 58 Go images.** Real but partially mitigated. Mechanical by this point.

**Wave 4 — the guard.** CI check failing if any melange package name collides with
a Wolfi `APKINDEX` entry without `provider-priority` set, or still carries a
`-minimal` suffix. Prevents silent regression as Wolfi's catalog grows.

The guard must fail loudly when its own inputs are missing. Three checks during
waves 1-2 passed while proving nothing, all the same shape — absence read as
success: a missing `pyyaml` made YAML validation throw and get skipped, a missing
`APKINDEX` made every collision check report "clear", and a build tagged
`minimal-<img>:latest` left `make test-<img>` (which tests
`$(REGISTRY)/$(OWNER)/minimal-<img>:latest`) exercising the published pre-rename
image. The last one hid every smoke-test result for waves 1-2 until a missing
published image exposed it.

Also rename `kube-state-metrics` and `redis-exporter` as part of their onboarding
(both untracked WIP at time of writing; both are Go apps).

## Per-image recipe

1. `melange.yaml`: rename `package.name`, add `dependencies.provider-priority: 100`
2. Update **both** apko variants' `contents.packages` — atomically with step 1
3. `melange build --arch x86_64` (aarch64 cannot build locally — no QEMU; CI covers it)
4. `apko build` both variants → log must read `installing <app> (<version>)`, not a Wolfi package
5. `test.sh` and `test-dev.sh` → exit 0
6. **grype before/after** → record the delta

Batch ~5 images per PR. `strict: true` branch protection means a large PR is
repeatedly invalidated by bump merges, and one bad image shouldn't block four good ones.

## Risks and notes

- **No CVE gate exists.** `grype "$IMAGE" -o json -o sarif` — no `--fail-on`, no
  severity cutoff. Newly-surfaced CVEs cannot fail a build. They will appear on the
  catalog site, so the public "0 CVEs" number will rise — frame it before it lands.
- **NVD vendor mismatch is unresolved.** Envoy is indexed under vendor `envoyproxy`,
  not `envoy`. Syft has a CPE dictionary that may bridge some cases; unverified.
  **If the after-scan is still 0, the rename alone did not fix that image.** This is
  why step 6 is non-negotiable.
- **melange's `cpe:` field does not help.** It reaches only melange's generated SBOM.
  The apk database has no CPE field, and syft catalogued 0 packages from the image's
  `/var/lib/db/sbom/` — `grype <image>` reads `/usr/lib/apk/db/installed`.
- **Directory name ≠ package name** in some images (`redis-slim` → `redis`). Verify
  per image; do not derive mechanically.
- **Sweep for stray references** — a renamed package with a stale apko reference fails
  to resolve. haproxy had 3 real references; redis had 3 plus comments.

## Evidence

Real `apko build` runs, local package named `helm` 3.21.3 vs Wolfi's `helm-4` 4.2.3-r1:

| local package | apko installed |
|---|---|
| `helm` 3.21.3, no priority | Wolfi's `helm-4` 4.2.3-r1 |
| `helm` 3.21.3, `provider-priority: 100` | our `helm` 3.21.3-r0 |

Real image scans:

```
renamed image:  helm 3.21.3-r0  cpe:2.3:a:helm:helm:*     matches=5  ns=nvd:cpe, wolfi:distro
wolfi's build:  helm-4 4.2.3-r1 cpe:2.3:a:helm-4:helm-4:* (poisoned)
```

Pilot (`redis`, same version 8.10.0):

```
published redis-minimal  → 0 redis CVEs
locally built redis      → 1 redis CVE (CVE-2025-49112)
```
