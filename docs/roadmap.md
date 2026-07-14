# Image Roadmap — the road to 100

**Status: 79 / 100 images.** Source-of-truth plan for growing the catalog. Prioritized by
**demand × free-gap × build-obstacle** — not by GitHub stars, and not by a blunt "heavy/skip".

## Why these images now — the free-hardened gap

For a hardened-**container** catalog the metric is "how often is this run as a container"
(Docker pulls), not GitHub stars (dive has 54k⭐ / 1.7M pulls — a laptop tool; oauth2-proxy
15k⭐ / 97M pulls — run everywhere). And the *opportunity* is images whose only hardened
option is now **paid**:

- **Chainguard** free tier = **5 images of your choice** out of 2,100+ → the rest is paywalled.
- **Bitnami** (280+ apps: Postgres, Redis, Kafka, Cassandra, Solr, InfluxDB, WordPress…) moved
  to **paid ($50–72k/yr) as of Aug 2025**; the rest is archived/deleted ~Sept 2026. Source
  stays **Apache-2.0**, so we can build from it.

So "high pulls + no free hardened option" describes a large set. We rank the gap by pulls,
gate on license (🟢 permissive / 🟡 AGPL ok / 🔴 SSPL·BUSL·Elastic avoid), and classify by
**build obstacle**.

## Build obstacle — the real filter (not "heavy")

We already ship every "heavy" build class, so build weight is **not** a blocker:

| Pattern | Examples we ship |
|---|---|
| Go from source | openbao, loki, mimir, thanos, gitea, trivy |
| **JVM jlink from source** | kafka, keycloak, jenkins, opensearch |
| **C/C++ compiled** | mysql, mariadb, redis-slim, memcached, haproxy, mosquitto |
| Interpreter runtimes | php, ruby, rails |
| Binary-repackage | envoy (fetches the official binary — no compile) |

Only **three obstacle classes** are genuinely own-effort:
1. **Frontend-in-bwrap** — a yarn/React build fighting the sandbox. grafana was *added then
   removed* after 7 fix commits. Fix = backend-from-source + prebuilt official frontend assets.
2. **Local-build disk cap** — we build+test locally before push (see §0 in `onboarding.md`);
   the biggest compiles exhaust the dev box. Fine on CI native runners, awkward locally.
3. **Exotic build system** — non-standard version/build injection (cmctl's klone).

---

## Shipped this push (70 → 79)

**Tier 1** ✅ oauth2-proxy · flux · kustomize · sops · crane · kubeseal
**Tier 2** ✅ helmfile · regctl · stern

---

## Crankable next — demand-ranked gap, all on proven patterns

| ✓ | Image | 🐳 pulls | License | Pattern | Notes |
|---|---|---:|---|---|---|
| [ ] | **zookeeper** | 350M | 🟢 Apache | JVM jlink | pairs with our kafka; Bitnami-stranded |
| [ ] | **solr** | 354M | 🟢 Apache | JVM jlink | search; Bitnami-stranded |
| [ ] | **cassandra** | 259M | 🟢 Apache | JVM jlink | wide-column DB; thin DB cat |
| [ ] | **flink** | 96M | 🟢 Apache | JVM jlink | stream processing |
| [ ] | **temporal** | 44M↑ | 🟢 MIT | Go, no frontend | durable workflow engine — cleanest crank |
| [ ] | **wordpress** | 1.48B | 🟢 GPL | PHP (php/rails pattern) | app + bundled assets; huge demand |
| [ ] | **pgbouncer** | 20M | 🟢 ISC | C (mysql/haproxy pattern) | Postgres pooler |
| [ ] | **unbound** | 12M | 🟢 BSD | C | DNS resolver |
| [ ] | **varnish** | 21M | 🟢 BSD | C | HTTP cache |
| [ ] | **kong** | 356M | 🟢 Apache | OpenResty/Lua | API gateway (nginx+Lua, like apisix) |
| [ ] | **kvrocks** | 3.5M | 🟢 Apache | C++ | Redis-on-RocksDB |
| [ ] | **patroni** | — | 🟢 MIT | Python | Postgres HA |

## Batch plan: 79 → 100+ (pattern-grouped, one template per batch)

Each batch reuses a single build template so it cranks fast; ordered by aggregate demand.
Build + prod/dev test every image locally before push.

| Batch | Template | Images | Pulls (agg) | Running total |
|---|---|---|---:|---:|
| **A — JVM tier** | kafka jlink | tomcat 817M · zookeeper 350M · solr 354M · cassandra 259M · flink 96M | ~1.9B | **84** |
| **B — Go servers** | Go crank | gitlab-runner 3.6B* · pomerium 1.6B (envoy-fetch) · temporal 44M · step-ca 13M | ~5.3B | **88** |
| **C — C network** | mysql/haproxy | varnish 21M · pgbouncer 20M · unbound 12M · keepalived 4M (🟡 GPL) | ~57M | **92** |
| **D — JVM messaging+agent** | kafka jlink | jenkins-agent 480M · activemq-artemis · pulsar 36M | ~520M | **95** |
| **E — count-fillers** | Go crank (trivial) | k9s · dive · age | low | **98** |
| **→ 100+** | mixed | wordpress 1.48B (PHP) · kvrocks (C++) · couchdb 202M (Erlang†) · cmctl (#9) | ~1.7B | **102** |

\* gitlab-runner needs executor/shell semantics — flag. † couchdb needs an Erlang runtime (new pattern).

**Start with Batch A** — highest impact-per-effort: ~1.9B aggregate pulls on the jlink template
we've already proven 4× (kafka, keycloak, jenkins, opensearch). zookeeper is the simplest → use
it as the JVM template, then tomcat/solr/cassandra/flink follow.

## Own-effort — genuine obstacles (not a crank)

| Image | 🐳 pulls | Obstacle |
|---|---:|---|
| grafana | 5.3B | frontend-in-bwrap (AGPL) — backend + prebuilt assets, own effort |
| argocd | — | frontend + repo-server needs git/helm/kustomize at runtime |
| superset | 601M | Python + React frontend |
| uptime-kuma | 166M | Node/yarn frontend |
| influxdb (v2) | 1.1B | Go **but** embeds a React UI (frontend); v3 is Rust |
| harbor | 28M | multi-image + portal frontend |
| clickhouse | 260M | C++ compile too large for the local pre-push build (OK on CI) |
| kubescape | 12M | large Go build — needs ~40 G local disk freed |
| cmctl | 14k⭐ | cert-manager klone build; no clean `-X` version injection |
| pomerium | 1.6B | `//go:embed`s an Envoy binary — **tractable via our envoy binary-fetch pattern**; re-open |
| cert-manager (core) / flux (controllers) | — | multi-image, in-cluster; mirror upstream split |
| opensearch-dashboards | — | free **Kibana** replacement (we ship `opensearch`) — but has a frontend build |

## Avoid — non-free license (🔴), free fork exists

| Paywalled/closed | 🐳 pulls | Free fork we ship / should ship |
|---|---:|---|
| mongodb | 4.8B | 🔴 SSPL — no fork onboarded (skip) |
| elasticsearch | 966M | 🔴 SSPL/Elastic → **opensearch** ✅ (have) |
| kibana | 224M | Elastic → **opensearch-dashboards** (own-effort, frontend) |
| logstash | 202M | Elastic → **fluent-bit** ✅ (have) |

## Deprioritized — popular but low container demand (laptop/CLI/embedded)

`k9s` · `dive` · `age` · `duckdb` · `zig`/`erlang`/`lua` (languages have official base images).
Easy builds, but nobody runs them as a hardened container. Add only on explicit demand.

## Pre-existing 🔴 exposures to resolve (tracked separately)

- `redis-slim` declares SSPL-1.0 but 8.x is tri-licensed → re-declare AGPL-3.0-only.
- `consul` 2.0.0 = BUSL-1.1 (no OSS fork) → keep-vs-drop decision pending.

---

## Execution model

- **One PR per group (~4–6 images).** Each image: 10 registration points (`onboarding.md`)
  incl. a validated `cron-enabled` `versions.yaml` row — `check-autoupdate` blocks the PR otherwise.
- Build **and** prod+dev smoke-test every image locally before push. Never push a failing image.
- Registration inserts use **Python (newline-safe)**, not bash `$(...)`.
- Pull counts are noisy (cumulative, CI/bot pulls) — order-of-magnitude, not precise.
