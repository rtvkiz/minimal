# How image versions stay current

Authoritative reference for how an image's **app version** and its **base**
get patched, how the auto-bump machinery works, and the failure mode that
freezes an image's version silently. Read this before onboarding an image or
debugging "why didn't image X get the new upstream release?".

## The two-loop mental model

Two independent schedulers keep an image current. They do **different** jobs;
confusing them is the root of most "why is this stale?" questions.

### Loop 1 — Rebuild (`build.yml`, cron `17 */6 * * *`, every 6h)

Rebuilds **every** image *at its currently-pinned version* against the latest
Wolfi apks. It re-runs melange, which re-downloads the **same** app source
tarball (`version:` is hard-pinned in the melange.yaml) and re-runs the
`patch-go-deps` block. So this loop refreshes:

- the **base** — glibc, ca-certificates, the Go/C/JVM toolchain ✅
- **transitive Go deps** inside the auto-generated `patch-go-deps` block ✅
- the app's **own version** — ❌ never; `version:` does not move here.

This is what "daily CVE patching" means for the *base*. It does nothing for
app-level CVEs.

### Loop 2 — Version bump (`update-versions.yml`, cron `0 7 * * *`, daily)

The **only** thing that advances an app to a newer upstream release. Driven
entirely by `.github/versions.yaml`. If an image has **no row** in that file
(and no bespoke `update-<name>.yml`), Loop 2 never touches it and its
`version:` can only change by hand.

## The version-bump pipeline (`update-versions.yml`)

Four stages. Logic lives in `.github/scripts/`, not in the workflow YAML.

```
plan  ─▶ check-upstream.sh ─▶ apply-update.sh ─▶ open-pr.sh
```

1. **plan** (`update-versions.yml` `plan` job)
   - Reads `versions.yaml` → JSON.
   - On `schedule`: keeps only rows with `cron-enabled: true`.
   - On `workflow_dispatch`: ignores the cron gate; respects the `only:`
     input (comma-separated names) for one-off validation runs.
   - Emits a matrix (one parallel job per surviving row, `max-parallel: 5`).

2. **check-upstream.sh** — resolve current vs latest for one row.
   - **Current** version: `grep '^  version:'` in `files[0]` (or
     `source.current-field` / `source.current-grep` overrides).
   - **Latest** version, by `source.type`:
     | type | how |
     |---|---|
     | `github-releases-latest` | `GET /repos/<repo>/releases/latest`, take `.tag_name` |
     | `github-tags` | `GET /repos/<repo>/tags?per_page=100`, filter by `pattern`, strip prefix, **numeric** semver-sort (tags come in creation order, not version order), take highest. If the tarball is a `releases/download/` asset, probe newest→oldest and return the newest tag whose asset actually exists (tags are cut before assets publish). |
     | `plain-text` | fetch one URL, return the bare version string |
     | `scrape` | fetch URL(s), `grep -oE` the pattern, extract `N.N.N`, semver-sort, take last |
     | `json` | fetch URL(s), run `source.jq` to extract the version |
   - Validates shape `^[0-9]+(\.[0-9]+){1,3}$`.
   - **pin-major guard**: if `latest`'s major ≠ `pin-major`, it does **not**
     bump. Instead it emits `next_major` → the workflow opens/updates a
     GitHub issue (when `major-issue: true`) so a human does the major upgrade
     deliberately. This is why staying on a major line is safe to automate.
   - If `latest == current`: `update=false`. Otherwise `update=true` +
     `new_version`.

3. **apply-update.sh** — only runs when `update=true`.
   - Downloads the tarball(s) from the first working URL (`tarball:` single or
     `tarballs:` plural for multi-arch), computes the digest(s).
   - For each melange.yaml in `files[]`, `sed`-rewrites in place:
     `^  version:` → new version, `^  <field>:` → each digest, `^  epoch:` → 0,
     plus any `extra-fields:` (e.g. ruby's `ruby_version`) → new version.
   - Custom `{path, pattern, template}` entries get their own `sed` (used by
     rails to write only `rails_version:`).
   - URL templates support `{version}`, `{major}`, `{minor}`, and `{vars}`.

4. **open-pr.sh** — branch `update-<name>-<new>`, commit
   `chore(<name>): bump to <new>`, force-push, create-label-if-missing, open
   (or update an existing) PR labeled `dependencies` + `<name>`, then
   **`gh pr merge --auto --squash --delete-branch`**. It auto-merges once
   required checks (the per-image build+test) pass. A red build blocks the
   merge — the pinned version only advances when the new version actually
   builds and passes its smoke test.

## `versions.yaml` row — minimal shape

The file header documents the full schema. The common case (a Go project whose
GitHub `releases/latest` is reliable) is:

```yaml
- name: <image-dir-name>
  # cron-enabled: true      # ← add ONLY after a dispatch test opens a clean PR
  files: [<dir>/melange.yaml]
  source: { type: github-releases-latest, repo: <owner>/<repo>, strip-v: true, pin-major: <N> }
  tarball: { url: "https://github.com/<owner>/<repo>/archive/refs/tags/v{version}.tar.gz", field: sha256 }
  major-issue: true
  links:
    releases: "https://github.com/<owner>/<repo>/releases"
    notes: "https://github.com/<owner>/<repo>/releases/tag/v{version}"
```

Use `github-tags` (with a `pattern`) instead when the repo's
`releases/latest` is unreliable or mixes major lines.

## Onboarding an image into auto-bump (the safe rollout)

1. Add a row to `versions.yaml` **without** `cron-enabled`.
2. Dispatch-test it end to end:
   `gh workflow run update-versions.yml -f only=<name>` — dispatch ignores the
   cron gate. Confirm it opens a **clean, buildable** PR (or correctly finds
   no update).
3. Only then set `cron-enabled: true`.
4. If migrating off a bespoke `update-<name>.yml`, flip `cron-enabled: true`
   **in the same commit that deletes the old workflow** — never leave a window
   with both, and never leave a window with neither (see below).
5. Fix the melange.yaml comment (`# … updated by update-<name>.yml`) to say
   `update-versions.yml`.

## Failure mode: the silent version freeze

An image is **frozen** — base gets patched by Loop 1, but the app version never
advances — when it has **no `cron-enabled: true` row in `versions.yaml`** and
**no bespoke `update-<name>.yml`**. It is invisible on the CVE dashboard
because the dashboard tracks base packages, which *are* still patched. Only
app-level CVEs slip through.

Root cause (verified from git history for the 8 below): the auto-bump wiring
was simply **never added when the image was onboarded** — NOT deleted. Onboarding
is a hand-synchronized checklist (melange, apko, tests, Makefile, `build.yml`
matrix, `versions.yaml` row). Every step except the last is required to make
the image build and ship; an image with a missing version row still passes CI,
publishes, and shows green. So the version-row step is the one most easily
dropped, and nothing fails when it is. Note the melange.yaml `# … updated by
update-<name>.yml` comment is boilerplate — its presence does NOT mean any such
workflow or row exists.

### How to audit for it

Every directory with a `melange.yaml` that **compiles from source** should have
a matching `versions.yaml` row (or a documented bespoke workflow). Quick check:

```sh
# compiled images with no versions.yaml row and no update-<name>.yml
comm -23 \
  <(for m in */melange.yaml; do d=${m%/melange.yaml}; \
      grep -q 'go build\|cargo build\|make ' "$m" && echo "$d"; done | sort) \
  <(grep -E '^- name:' .github/versions.yaml | sed 's/^- name: //' | sort)
```

Exceptions that legitimately have no row:
- **apko-only images** (no melange.yaml): bun, dotnet, go, httpd, java, nginx,
  node-slim, postgres-slim, python, sqlite — they repackage a Wolfi apk, so
  Loop 1 already tracks upstream via the apk. No app version of *ours* to bump.
- **minio** — bespoke `update-minio.yml` (RELEASE.<date> tag scheme).
- **redis-slim** — covered by the `redis` row (`image-name:` mapping).

### Known gap as of 2026-07-06 (TODO)

These 8 compile from source but are frozen — auto-bump wiring was never added
at onboarding (git-verified: the workflows never existed, the names never
appeared in `versions.yaml`):

`consul`, `helm`, `kubectl`, `mailpit`, `mimir`, `registry`, `telegraf`, `tempo`

Two onboarding eras: consul/helm/kubectl/mailpit/registry/tempo (added
2026-05-31→06-03, pre-consolidation) carry comments promising a per-image
`update-<name>.yml` that was never written; mimir/telegraf (added 2026-06-10/11,
post-consolidation) correctly name `update-versions.yml` but the row was never
added. Fix = add 8 rows per the rollout above. **`kubectl` is the one
caveat**: it builds out of the giant `kubernetes/kubernetes` repo whose
release/download scheme is not a plain `archive/refs/tags` source tarball, so
its row needs bespoke tarball handling, not a blind copy.

## A CI lint would prevent recurrence

The audit query above, run as a CI check ("every compiled image has a
`versions.yaml` row or a documented exception"), turns this silent freeze into
a failing build the moment a row is dropped.
