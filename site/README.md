# minimalcontainers.com — catalog site

The public image catalog for the `minimal` project, built with [Astro](https://astro.build)
and deployed to GitHub Pages on the custom domain **minimalcontainers.com**.

It is built and deployed by `.github/workflows/deploy-site.yml`, which reuses the scan and
SBOM artifacts produced by the image build (`build.yml`) — so it stays in sync with what's
published to `ghcr.io/rtvkiz/minimal-*`, while deploying independently of the 6-hour build.

**Deploy is decoupled from the image build.** `deploy-site.yml` triggers on:
- `workflow_run` — after each build completes, to redeploy with fresh scan data;
- `push` to `main` touching `site/**`, `catalog.json`, or any `apko` config — a fast
  (~2 min) redeploy that reuses the latest full build's data, no rebuild;
- `workflow_dispatch` — manual.

It always sources scan data from the latest successful **full** build (schedule/dispatch),
never a partial push build, so a data-thin dataset can't be published over a complete one.

## How it works

```
catalog.json  (repo root, source of truth: 57 images + metadata)
      +  <name>/apko/*.yaml         → specs: env, entrypoint, user, arch, labels
      +  reports/grype-<name>.json  → CVE advisories        (CI artifact)
      +  reports/meta-<name>.json   → size, digest, VEX      (CI artifact)
      +  reports/sbom-<name>.spdx.json → package closure     (CI artifact)
      +  GHCR Packages/registry API → all published tags
                    │
        scripts/build-data.mjs  →  src/data/images.json
                    │
                 astro build     →  dist/   →  GitHub Pages
```

`scripts/build-data.mjs` isolates every image in its own try/catch: a missing or corrupt
source degrades just that image (shown as "partial data") and never fails the build. The
only fatal conditions are an unreadable `catalog.json` or a reports dir that yields zero
scanned images.

## Local development

```bash
cd site
npm install
npm run dev        # predev regenerates src/data/images.json (metadata + specs + live tags)
```

No CVE/SBOM data locally (those come from CI scans), so Advisories/Packages show a graceful
"appears after the next scheduled build" state. To preview the full-data experience, drop a
few real `grype-<name>.json` / `meta-<name>.json` / `sbom-<name>.spdx.json` into `site/reports/`
and run:

```bash
node scripts/build-data.mjs reports && npx astro build && npm run preview
```

Set `SKIP_TAGS=1` to skip the GHCR tag fetch entirely (fully offline).

## Adding an image

1. Add it to the build matrix in `.github/workflows/build.yml` (as today).
2. Add a matching entry to `catalog.json` (name, category, variants, summary, upstream_url).

The `validate-catalog` CI job fails if `catalog.json` and the build matrix ever drift.

## Deployment / DNS (one-time)

The site deploys automatically from CI. To point the domain at it:

1. **Repo → Settings → Pages → Custom domain** → `minimalcontainers.com`, then enable
   **Enforce HTTPS** once DNS resolves. (`public/CNAME` is already committed.)
2. In **GoDaddy DNS** for `minimalcontainers.com`:

   | Type  | Name | Value |
   |-------|------|-------|
   | A     | @    | `185.199.108.153` |
   | A     | @    | `185.199.109.153` |
   | A     | @    | `185.199.110.153` |
   | A     | @    | `185.199.111.153` |
   | CNAME | www  | `rtvkiz.github.io` |

   (Optional IPv6: AAAA `@` → `2606:50c0:8000::153`, `…8001::153`, `…8002::153`, `…8003::153`.)

GitHub auto-provisions the TLS certificate. Once live, `https://rtvkiz.github.io/minimal/`
redirects to the custom domain.
