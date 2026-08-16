# Image Onboarding Standard

The authoritative, complete checklist for adding a new hardened image. If you
follow this end to end, your image will build on both arches, pass CI, auto-update
its version, get its transitive CVEs patched (or be a documented exception), and
appear on the catalog site — with nothing silently skipped.

> `CONTRIBUTING.md` is the friendly intro. **This file is the source of truth.**
> When they disagree, this file wins. Two related deep-dives:
> [`version-management.md`](version-management.md) (the two-loop update model) and
> [`dev-variants/CONVENTIONS.md`](dev-variants/CONVENTIONS.md) (the `-dev` image).
>
> **What to onboard next:** [`roadmap.md`](roadmap.md) — the demand-ranked road to 100.

---

## 0. The prime directive — never push a failing image

Any change touching an image's `melange.yaml`, `apko/*.yaml`, `test*.sh`, or its
Makefile targets **MUST** be built and tested locally before commit/push:

```
make <name>-melange   # only if the image has a melange.yaml
make <name>           # assembles the apko image
make test-<name>      # runs the per-image smoke test
```

If any step fails, fix the root cause and re-run. Do **not** rely on CI to find
breakage a one-line `make` would have caught, and do **not** disable a failing
test to go green. A red build on `main` blocks the every-6h scheduled rebuild for
**every** image. (Exceptions: pure docs and workflow-only changes that don't
affect any image's build inputs.)

Local `make <name>-melange` builds **x86_64 only**. The aarch64 build runs on CI's
native ARM runners. Some builds (jlink JREs, QEMU-less cross-compiles) *only* work
on x86_64 locally — that's expected; CI covers ARM.

---

## 1. Pick the image type

| Type | You write | Version tracked by | Example |
|---|---|---|---|
| **apko-only** (preferred) | assembles a Wolfi pre-built apk | Wolfi (via 6-hourly rebuild) | `httpd`, `nginx`, `go`, `python` |
| **source-built** | compiles from upstream source via melange | `versions.yaml` row | `cosign`, `kafka`, `trivy` |

**Try apko-only first.** Only build from source when Wolfi doesn't ship the
package, or you need a version/build Wolfi doesn't provide. Source-built images
carry more registration and maintenance (everything in §2 below).

---

## 2. The complete registration checklist

Tick every box. The ones marked **⛔ CI-enforced** will fail your PR if missing.

### Files to create

- [ ] `images/<name>/apko/<name>.yaml` — production image (§3)
- [ ] `images/<name>/apko/<name>-dev.yaml` — dev variant ([conventions](dev-variants/CONVENTIONS.md))
- [ ] `images/<name>/test.sh` — prod smoke test, **`chmod +x`** (§5)
- [ ] `images/<name>/test-dev.sh` — dev smoke test, **`chmod +x`**
- [ ] `vex/<name>.openvex.json` — VEX statements file (§8) — every image has one
- [ ] `images/<name>/melange.yaml` — **source-built only** (§4)

### Files to edit (register the image)

- [ ] **`Makefile`** — version var + `.PHONY` + build/test targets (§6)
- [ ] **`.github/workflows/build.yml`** — add to `MELANGE_IMAGES` or `APKO_IMAGES` (§7) **⛔**
- [ ] **`catalog.json`** — one entry (§7) **⛔ validate-catalog fails the PR without it**
- [ ] **auto-update configured (§9)** **⛔ check-autoupdate fails the PR without it** —
      source-built → `cron-enabled` `.github/versions.yaml` row; apko-only →
      classify in `.github/autoupdate-coverage.yaml`
- [ ] **transitive-dep patching** — source-built only (§10):
      Go → three dicts in `patch-go-deps.yml` **or** add to `SKIP_IMAGES`;
      Ruby/Rust/Maven → `.github/patch-deps.yaml`

> **Why the checklist matters:** the "frozen-8" incident (8 source-built images
> silently never getting version updates) and the #355 catalog-drift failure both
> happened because a registration point was skipped from memory. Don't onboard
> from memory — onboard from this list.

---

## 3. The apko config (`images/<name>/apko/<name>.yaml`)

Model on an existing image (`images/python/apko/python.yaml`, or `images/cosign/apko/cosign.yaml`
for a source-built one). Required shape:

```yaml
contents:
  repositories:
    - https://packages.wolfi.dev/os
  keyring:
    - https://packages.wolfi.dev/os/wolfi-signing.rsa.pub
  packages:
    - wolfi-baselayout
    - <name>                  # source-built: your melange package. apko-only: the Wolfi apk.
    - ca-certificates-bundle  # always, for TLS

accounts:
  groups: [{ groupname: nonroot, gid: 65532 }]
  users:  [{ username: nonroot, uid: 65532, gid: 65532 }]
  run-as: 65532

entrypoint:
  command: /usr/bin/<binary>

work-dir: /workspace            # or /app; use a writable dir the app needs
environment:
  PATH: /usr/bin:/bin
  # If the tool writes cache/config under $HOME and nonroot has none, set HOME=/tmp
  HOME: /tmp

paths:
  - { path: /workspace, type: directory, uid: 65532, gid: 65532, permissions: 0o755 }
  - { path: /tmp, type: directory, uid: 65532, gid: 65532, permissions: 0o1777 }

annotations:
  org.opencontainers.image.title: "minimal-<name>"
  org.opencontainers.image.description: "Hardened shell-less <Name> ..."
  org.opencontainers.image.url: "https://github.com/rtvkiz/minimal"
  org.opencontainers.image.source: "https://github.com/rtvkiz/minimal/tree/main/<name>"
  org.opencontainers.image.licenses: "<SPDX id>"

archs: [x86_64, aarch64]
```

**Rules**
- Minimum packages. Fewer packages = fewer CVEs.
- No shell in prod (no `busybox`/`bash`) unless the service genuinely needs it.
  **Known exception — the postgres family (`postgres-slim`, `patroni`):** PostgreSQL's
  `initdb` runs `"postgres" -V` through `popen()`, which execs `/bin/sh`. With no
  shell it dies with `initdb: error: program "postgres" is needed by initdb but was
  not found`, so the image cannot initialise a fresh `PGDATA` and will not start
  against an empty volume. These images carry **`busybox` only** — never `bash` or
  `apk-tools` — and their `test.sh` asserts both that `/bin/sh` exists (regression
  guard) and that bash/apk are absent (restraint guard). If you add another image
  that wraps postgres, it inherits this. Verify with a real `initdb` in the smoke
  test; a version-string check will not catch it.
- `run-as: 65532` (nonroot) unless upstream mandates a fixed UID.
- Create `/var/*` runtime dirs here with `paths:`, **not** in the melange pipeline
  (the SBOM step runs as the host user after the sandbox exits and can't mkdir into
  the root-owned destdir).

The `-dev.yaml` adds a shell + debugging tools (`busybox bash curl openssl
bind-tools jq git …`) on top of the same package. See the dev-variant conventions.

---

## 4. The melange source build (`images/<name>/melange.yaml`)

Model on `images/cosign/melange.yaml` (Go) or `images/mosquitto/melange.yaml` (C). Skeleton:

```yaml
package:
  # Name it exactly what the upstream project is called — the same string NVD and
  # the Wolfi secdb index it under. NOT `<name>-minimal`: syft derives the CPE from
  # the apk name, so a suffix produces cpe:2.3:a:foo-minimal:foo-minimal:* which
  # matches nothing in NVD and nothing in the Wolfi secdb, and grype silently
  # reports zero CVEs. Measured: `haproxy-minimal` 0 findings vs `haproxy` 14 at an
  # identical version. See §"Package naming and scanner visibility" below.
  name: <name>
  version: X.Y.Z
  epoch: 0
  copyright: [{ license: <SPDX id> }]
  dependencies:
    # Required whenever Wolfi also ships a package of this name: apko resolves a
    # top-level name across ALL repositories and picks the highest version — it does
    # not prefer our local repo. provider-priority is evaluated before version in
    # apko's comparator, so this pins resolution to our build permanently.
    provider-priority: 100

vars:
  sha256: <tarball sha256>     # updated by update-versions.yml

environment:
  contents:
    packages: [busybox, ca-certificates-bundle, curl, build-base, go, git]  # go: for Go apps

pipeline:
  - runs: |                    # download + verify + extract
      mkdir -p /home/build/<name>-${{package.version}}
      curl -fsSL --retry 5 --retry-all-errors \
        "https://github.com/<owner>/<repo>/archive/refs/tags/v${{package.version}}.tar.gz" -o /home/build/src.tgz
      echo "${{vars.sha256}}  /home/build/src.tgz" | sha256sum -c -
      tar xzf /home/build/src.tgz -C /home/build/<name>-${{package.version}} --strip-components=1
```

### Go build pattern (static, shell-less)

```bash
cd /home/build/<name>-${{package.version}}
GOTOOLCHAIN=local CGO_ENABLED=0 go build \
  -trimpath \
  -ldflags="-s -w -buildid= -X <version-var-path>=${{package.version}}" \
  -o /home/build/<name>-bin \
  ./cmd/<name>
```

- `CGO_ENABLED=0` → static binary, no glibc/shell dependency.
- Find `<version-var-path>` from upstream's `.goreleaser.yml`/Makefile `-X` flag
  (e.g. `main.Version`, `github.com/.../version.Version`). Wrong path = empty
  version string (your test's version grep will catch it).
- Some projects need extra flags: `GOEXPERIMENT=jsonv2` (trivy: `encoding/json/v2`),
  build tags, etc. Match upstream's release build.

### melange gotchas (each cost a debugging session)

- **`--strip-components=1` into a name you control** when the archive's top-level
  dir ≠ image name. The dir is `<reponame>-<version>` — e.g. `smallstep/cli` →
  `cli-0.30.6`, not `step-cli-0.30.6`. Normalise it so `MODROOT` is predictable.
- **Relative symlinks only** in the destdir (`ln -sf ../lib/.../java`, not an
  absolute path) — absolute symlinks are dangling during the melange verify step.
- **C apps: disable optional features that pull dev deps.** Un-freezing a C app
  across a minor bump often adds build deps. mosquitto 2.1 turned on `WITH_EDITLINE`
  (→ editline), `WITH_HTTP_API` (→ libmicrohttpd), `WITH_SQLITE` (→ sqlite3); all
  disabled with `=no` for a minimal broker. Read the new version's `config.mk`.

### Package naming and scanner visibility

The melange `package.name` is not cosmetic — it is the only identity a scanner has
for a C/C++ image, and it decides whether that image is scanned at all.

Grype matches through two paths, and a `-minimal` suffix breaks both:

| Path | Keyed on | With `foo-minimal` |
|---|---|---|
| `wolfi:distro:wolfi:rolling` (secdb, fix-aware) | apk package name | no secdb entry → no matches |
| `nvd:cpe` | CPE syft derives from the apk name | `cpe:2.3:a:foo-minimal:foo-minimal:*` → matches nothing in NVD |

Syft's `apk-db-cataloger` reads `/usr/lib/apk/db/installed`, which carries no CPE
field, and it ignores the embedded SBOM at `/var/lib/db/sbom/`. A melange `cpe:`
block therefore does **not** reach `grype <image>` — renaming the package is the
only fix. A controlled test at an identical version: `haproxy-minimal` reported
**0** findings, `haproxy` reported **14**.

Go images are partially covered by accident — syft's `go-module` cataloger reads
the binary's build info and gives them a second identity. Non-Go images have no
fallback and are fully blind.

**Rules**
- Name the package exactly what upstream calls it (`redis`, `haproxy`, `nginx`).
- Add `dependencies.provider-priority: 100` whenever Wolfi ships a package of the
  same name, so apk cannot substitute Wolfi's build for ours on a version bump.
- The image name stays `minimal-<name>` — this is the *apk package* name only, and
  it must match in `melange.yaml`, `apko/<name>.yaml`, and `apko/<name>-dev.yaml`.

**Migration complete, and now enforced.** Every melange-built image in
`catalog.json` uses the bare upstream package name; the 13 apko-only images never
had one to rename. `make check-packages` (CI: the `validate-catalog` job) asserts
all four rules above and fails the PR on any violation — a suffix, a
`primary_package` that disagrees with `package.name`, a Wolfi-colliding name
without `provider-priority: 100`, or an apko variant referencing a package
melange does not build. Use `make check-packages-report` locally to list
violations without failing.

Naming judgment: prefer the name **upstream** uses, not the name another distro
uses. Adopting Wolfi's name for a package we build ourselves also adopts their
advisory stream, which is keyed to *their* epoch numbering — that is what makes
our `-r0` read as vulnerable against their `-r6` even when our build is newer.
`otelcol` keeps the upstream binary name for this reason rather than moving to
Wolfi's `opentelemetry-collector`.

---

## 5. The smoke tests (`test.sh`, `test-dev.sh`)

```bash
#!/bin/bash
set -eu     # NB: no pipefail — `docker run | grep` is SIGPIPE-prone
: "${IMAGE:?IMAGE env var required}"

echo "Testing <name> version...";  docker run --rm "$IMAGE" version 2>&1 | grep -qiE 'X\.Y'
echo "Testing <name> help...";     docker run --rm "$IMAGE" --help 2>&1 | grep -qiE 'sub|commands'
echo "Testing <name> offline...";  # an image-specific functional check that needs NO network
echo "Verifying no shell...";      docker run --rm --entrypoint /bin/sh "$IMAGE" -c "echo x" 2>/dev/null \
  && echo "FAIL: shell found" && exit 1 || echo "No shell (as expected)"
echo "All <name> tests passed!"
```

Every test must cover: **version**, **help/subcommands load**, **one offline
functional check** (proves the binary actually works — cosign generates a keypair,
opa evaluates `1+1`, gitleaks scans a clean dir, mosquitto does a pub/sub
round-trip), and **no-shell**.

### test gotchas

- **`chmod +x test.sh test-dev.sh`** — else `make test-<name>` dies with `Permission denied`.
- **Bind-mounted workdirs must be world-writable.** The container runs as uid
  65532; `mktemp -d` is 0700-owned-by-you, so the container can't write. Do
  `work=$(mktemp -d); chmod 0777 "$work"` before `-v "$work:/workspace"`.
- **Files the container writes are owned by 65532**, often `0600`, so the host
  user can't read them. Verify with `[ -s "$work/out" ]` (stat, needs only the
  0777 dir), **not** `grep` (needs read). (cosign's pubkey happens to be 0644, so
  its grep works; step-cli's keypair is 0600, so use `-s`.)
- **Never pipe a producer straight into `grep -q` under `set -o pipefail`.**
  `grep -q` exits at the first match, the producer takes SIGPIPE, and the
  pipeline returns 141 — so the test fails on a perfectly good image. It is a
  *race*: whether the producer finishes writing before grep exits. The same
  line passed in a prod job and failed in the dev job of the same run, and the
  flink and vaultwarden tests both shipped this bug. Capture first, then match:

  ```bash
  # wrong — flaky, fails with 141
  docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version 2>&1 | grep -q "21\."
  curl -sf "$url" | grep -q "<html"

  # right
  jv=$(docker run --rm --entrypoint /usr/bin/java "$IMAGE" -version 2>&1)
  echo "$jv" | grep -q "21\." || { echo "unexpected JRE: $jv"; exit 1; }
  ```

  Piping a *variable* into grep (`echo "$x" | grep -q`) is fine — the write
  completes before grep can exit. So is `docker ps | grep -q`, for the same
  reason. The danger is a producer that writes a lot, or slowly.

---

## 6. Makefile registration

```makefile
# version var (top of file, near the other *_VERSION lines)
<NAME>_VERSION ?= $(call melange_version,images/<name>/melange.yaml)

# .PHONY (with the other .PHONY lines)
.PHONY: <name> <name>-melange test-<name>

# build targets — copy an existing source-built block (e.g. cosign) verbatim,
# renaming: <name>-melange (melange build), <name> (apko assemble + docker load + tag)
# test target
test-<name>:
	@export IMAGE="$(REGISTRY)/$(OWNER)/minimal-<name>:latest" && images/<name>/test.sh
```

apko-only images skip the `-melange` target (there's no melange build).

---

## 7. build.yml matrix + catalog.json (both CI-enforced together)

`validate-catalog` asserts **`catalog.json` names == the build.yml matrix names,
exactly**. Add to both or the PR fails fast.

**build.yml** — one line in the right JSON array inside the *Detect changes* step:

```jsonc
// source-built:
MELANGE_IMAGES='[ ... {"name":"<name>","variants":["prod","dev"]} ]'
// apko-only (the "grep" is the Wolfi apk-name regex that triggers a rebuild):
APKO_IMAGES='[ ... {"name":"<name>","grep":"<apk-name>","variants":["prod","dev"]} ]'
```
Add `"apko":"<path>"` if the config isn't at `images/<name>/apko/<name>.yaml`; drop `dev`
if there's no `-dev.yaml`.

**catalog.json** — one object in `.images` (single-line style, match neighbours):

```jsonc
{ "name":"<name>", "category":"<one of the categories below>", "variants":["prod","dev"],
  "primary_package":"<name>", "upstream_url":"https://...", "summary":"Shell-less <Name> ..." }
```
Valid `category` values (must match exactly):
`Languages & Runtimes` · `Databases` · `Caches, Queues & Messaging` ·
`Web Servers & Proxies` · `Observability` · `Infrastructure` ·
`Kubernetes, CI & IaC` · `Apps`.

---

## 8. VEX (`vex/<name>.openvex.json`)

Every image gets one. Start empty:

```json
{
  "@context": "https://openvex.dev/ns/v0.2.0",
  "@id": "https://github.com/rtvkiz/minimal/vex/<name>",
  "author": "rtvkiz",
  "timestamp": "<UTC ISO8601>",
  "version": 1,
  "tooling": "tools/vex/validate.sh",
  "statements": []
}
```

VEX is how we tell scanners a reported CVE **doesn't apply** (`not_affected`,
justification e.g. `vulnerable_code_not_present`) — this is Chainguard's own
first-class alternative to force-patching (see §10). Use it for false-positives
and unreachable CVEs. Tooling: `tools/vex/{validate,reconcile}.sh`.

---

## 9. Auto-update — mandatory for every image

**Every prod image must have exactly one live auto-update mechanism.** This is
enforced by `make check-autoupdate` (§12) against `catalog.json`, so an image
cannot be onboarded without it. Which mechanism depends on the image type:

- **apko-only (package-based)** — declare it in **`.github/autoupdate-coverage.yaml`**:
  `wolfi-versioned` if apko pins a versioned package (`python-3.14`, `go-1.26`) whose
  major-line bumps come from `update-wolfi-packages.yml`; `wolfi-rolling` if apko
  references an unversioned/rolling package (`apache2`, `nginx-mainline`, `sqlite`)
  that is always current via the 6-hourly rebuild. (`exempt`/`bespoke` exist as
  documented escape hatches — each requires a reason.)
- **source-built** — add a `cron-enabled` `versions.yaml` row (below).

### versions.yaml auto-bump (source-built only)

The `update-versions.yml` cron advances the **app version** (see
[version-management.md](version-management.md) for the full two-loop model). Add a
row. Full schema + examples are at the top of `.github/versions.yaml`.

```yaml
- name: <name>
  # cron-enabled: true          # ← add ONLY after the dispatch check below passes
  files: [images/<name>/melange.yaml]
  source: { type: github-releases-latest, repo: <owner>/<repo>, strip-v: true, pin-major: <N> }
  tarball: { url: "https://github.com/<owner>/<repo>/archive/refs/tags/v{version}.tar.gz", field: sha256 }
  major-issue: true
  links:
    releases: "https://github.com/<owner>/<repo>/releases"
    notes:    "https://github.com/<owner>/<repo>/releases/tag/v{version}"
```

### conventions & gotchas

- **`pin-major`** locks the loop to minor/patch within that major. A new upstream
  major does **not** auto-bump — with `major-issue: true` it opens an issue for a
  human. (Majors can rename flags/config/entrypoints — always a human decision.)
- **`github-releases-latest`** for a clean single "latest" release. **`github-tags`**
  (with a `pattern:` and `strip-prefix:`) when releases are messy — e.g. `helm`
  (Helm 4 shipped, so pin `^v3\.` via tags), `mimir` (real tags buried under chart
  tags — use releases-latest + `strip-prefix: mimir-`).
- **Use the canonical repo, not a redirect.** The resolver's raw curl does **not**
  follow GitHub's 301 for renamed repos. `eclipse/mosquitto` → use
  `eclipse-mosquitto/mosquitto`. Symptom of getting this wrong: `jq: Cannot index
  string with string "name"`.
- **Non-github tarball?** Point `tarball.url` at the real host (mosquitto builds
  from `mosquitto.org/files/source/...`, not the GitHub archive).

### Safe rollout (validate once, then ship enabled)

**Validate before you enable — but the onboarding PR must land the row already
`cron-enabled: true`.** The `check-autoupdate` gate (§12) fails any PR that ships a
source-built image with a missing or frozen (not-yet-enabled) row, so you cannot
merge an image without live auto-update. Validate first, then enable in the same PR:

```bash
gh workflow run update-versions.yml -f only=<name>   # ignores the cron gate
```
Confirm it produces a correct PR (or a clean "no update"), **then** set
`cron-enabled: true` on the row before pushing. Why validate first: update-versions
PRs **auto-merge**, and a wrong row would auto-merge a bad bump to `main` and stall
the whole fleet. Never enable an unvalidated row — but never leave a validated one
frozen either (that is exactly how the batch-b CLIs silently stopped auto-updating).

---

## 10. Transitive-dep CVE patching (source-built only)

### Go images — `patch-go-deps.yml`

Add the image to **three** bash assoc-arrays in the *Scan … and generate patches*
step, or it silently accrues unpatched CVEs forever (this is how alertmanager
shipped 24 crit/high CVEs):

```bash
MODROOTS=(     [<name>]="/home/build/<archive-dir>-${D}{{package.version}}" )   # space-sep multiple modules for monorepos
MAIN_MODULES=( [<name>]="<the image's OWN module path>" )                        # so it doesn't try to go-get itself
BUILD_MARKERS=([<name>]='<a literal string from your melange build step>' )     # patch block spliced before it
```
Then `gh workflow run patch-go-deps.yml` once to validate the splice.

**When NOT to register — huge tangled graphs.** If the dependency graph is large
and tightly coupled (trivy: buildkit/containerd/rclone/sigstore/aws-sdk…), grype
flags ~20 transitive CVEs at once and pinning them to exact fix versions fights
Go's MVS into cascading conflicts that no resolver reliably untangles. **Add the
image to `SKIP_IMAGES` instead** and build from pure upstream source (no patch
block). It stays current via its §9 version bump (upstream bumps their own deps
each release) + the base rebuild; reachable gap CVEs get a **manual** targeted bump
or a **VEX** `not_affected`. This mirrors Wolfi's own `HOW_TO_PATCH_CVES.md`
("hand-resolve tangled graphs locally") and Chainguard's practice (trivy was moved
to this model in PR #383). Note: `patch-go-deps` opens **one shared PR** — one
image's build failure blocks every image's patches, so a tangled graph left in the
bot poisons the whole batch.

### Ruby / Rust / Maven images — `.github/patch-deps.yaml`

Add an entry under the matching language row (`bundler` / `rust` / `maven`) with
`{ name, src-root, build-marker }`. Simpler declarative schema than the Go workflow.

---

## 11. License policy

Record the SPDX id in `melange.yaml` `copyright:` and the apko
`org.opencontainers.image.licenses`. Tiers:

- 🟢 **Permissive** (MIT, BSD, Apache-2.0, MPL-2.0, EPL-2.0) — add freely.
- 🟡 **Copyleft, OSI-approved** (GPL, LGPL, AGPL) — allowed; precedent: loki, tempo,
  mimir, minio (AGPL).
- 🔴 **Source-available, non-open** (SSPL, BUSL, Elastic, RSAL, vendor EULA) —
  **avoid**, or use a permissive fork. Existing 🔴 exposures are tracked for
  resolution (redis SSPL→AGPL redeclare, consul BUSL, cuda-python EULA).

---

## 12. Pre-push checklist & the CI gates that will catch you

Before you push (source-built):

```bash
make <name>-melange && make <name> && make test-<name>   # §0 — must all pass
python3 -c "import json; json.load(open('catalog.json'))" # valid JSON
ruby -ryaml -e "YAML.load_file('.github/versions.yaml')"  # valid YAML
make check-autoupdate                                     # §9 — auto-update configured
make lint-workflows                                       # if you touched .github/workflows/**
```

CI will independently enforce:

| Check | Fails when |
|---|---|
| `validate-catalog` | `catalog.json` ≠ build matrix |
| `check-autoupdate` | a prod image has no live auto-update (missing/frozen row, or unclassified apko-only image) |
| `melange-build` / `build-apko` (both arches) | the image doesn't build or its test fails |
| `lint-workflows` (actionlint + shellcheck) | a workflow schema error or shell syntax error in a `run:` block |
| gitleaks (pre-commit + CI) | a secret is committed |
| VEX validation | malformed `vex/*.openvex.json` |

## 13. Post-merge follow-ups (source-built)

1. The versions.yaml row already lands **validated + `cron-enabled`** in the onboarding
   PR (§9 safe rollout) — `check-autoupdate` blocks a frozen row, so there is no
   post-merge "enable" step to forget.
2. **Dispatch `patch-go-deps`** once to seed the transitive patch block (§10), if registered.
3. First grype scan may surface transitive CVEs — let the next patch cycle handle
   them, or VEX the false-positives.
