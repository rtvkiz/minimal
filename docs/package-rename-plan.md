# Plan: rename `<app>-minimal` apk packages to upstream names

Status: **planned**. Pilot landed (`redis`, commit `df7c509`). 84 images remain on main (86 melange.yaml files; `redis` renamed, `cuda-python` never suffixed).

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

**Wave 1 — 20 images.** Non-Go, no Wolfi name collision. Start with `haproxy`
(carries the 2 Criticals, proven 0 → 14).

```
cassandra envoy fluent-bit haproxy jenkins kafka keepalived memcached
mosquitto mysql opensearch php pulsar rabbitmq rails ruby tomcat
unbound zookeeper
```

**Wave 2 — 6 images.** Non-Go, Wolfi ships the same name; `provider-priority`
becomes load-bearing.

```
deno keycloak mariadb pgbouncer qdrant solr valkey
```

**Wave 3 — 58 Go images.** Real but partially mitigated. Mechanical by this point.

**Wave 4 — the guard.** CI check failing if any melange package name collides with
a Wolfi `APKINDEX` entry without `provider-priority` set. Prevents silent regression
as Wolfi's catalog grows.

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
