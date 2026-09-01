---
title: "Migrating from Minimus to Minimal"
description: "A step-by-step guide to moving container images from Minimus to Minimal: mapping image references, handling non-root and shell-less images, pinning tags, and verifying signatures and SBOMs."
published: "2026-08-31"
---

If you are already running hardened images, most of the work of switching is
mechanical: change the reference, fix the two or three assumptions your
Dockerfile makes about the base, and verify what you pulled. This guide walks
that path for Minimal.

A note on scope up front. This describes what **Minimal** expects and
guarantees, with each claim checkable from the commands below. It does not
document Minimus's internals — their documentation is the authority on that,
and asserting details of someone else's images that we have not verified is how
comparison content becomes wrong. Where your current base differs, the checklist
in step 3 is designed to surface it rather than assume it.

## 1. Map the image reference

Minimal publishes to GitHub Container Registry, one repository per image, with a
`minimal-` prefix:

```
ghcr.io/rtvkiz/minimal-<name>:<tag>
```

So the substitution is usually a single line in a Dockerfile or Helm values file:

```diff
-FROM <your-current-registry>/python:latest
+FROM ghcr.io/rtvkiz/minimal-python:latest
```

Pulls need no account and no login:

```
docker pull ghcr.io/rtvkiz/minimal-python:latest
```

Names follow the upstream project (`nginx`, `redis-slim`, `postgres-slim`,
`kafka`). Browse the [image directory](/images) for the full list — the catalogue
is deliberately smaller than a commercial vendor's, so **check your images are
covered before you start**. If something you depend on is missing, that is the
blocker, and it is better found now than halfway through.

## 2. Pick the right tag

Do not carry `:latest` into production out of habit. `:latest` on Minimal moves
across major versions, which is almost never what a deployment wants.

| You want | Pin | Behaviour |
| --- | --- | --- |
| A byte-identical artifact | `minimal-caddy@sha256:…` | Immutable, never moves |
| Patches, no breaking upgrades | `minimal-caddy:2` | Newest release in that major line |
| Tighter still | `minimal-caddy:2.11` | Newest patch in that minor line |

Pinning a major line is the usual answer: you keep receiving security rebuilds
without being moved across an upstream breaking release. An exact version tag
never moves forward at all, which means it also stops receiving fixes. Full
detail is in [tags and pinning](/docs/tags).

## 3. Check the three assumptions that actually break builds

This is where migrations fail, and the causes are nearly always the same three.

### There is no shell in production images

Most Minimal production images ship without a shell or package manager. That
breaks anything of this shape:

```dockerfile
RUN apt-get update && apt-get install -y curl
```

```yaml
command: ["/bin/sh", "-c", "exec myapp --flag"]
```

Two fixes, in order of preference:

1. **Build in a `-dev` variant, ship in the production one.** Every image has a
   `-dev` companion with a shell, package manager and toolchain, intended
   exactly for the builder stage of a multi-stage build:

   ```dockerfile
   FROM ghcr.io/rtvkiz/minimal-node-slim:latest-dev AS build
   WORKDIR /src
   COPY package*.json ./
   RUN npm ci
   COPY . .
   RUN npm run build

   FROM ghcr.io/rtvkiz/minimal-node-slim:latest
   COPY --from=build --chown=65532:65532 /src/dist /app
   ENTRYPOINT ["node", "/app/server.js"]
   ```

2. **Drop the shell wrapper.** Use exec-form `ENTRYPOINT`/`command` so no `/bin/sh`
   is needed to start the process. If you need shell features — variable
   expansion, pipes, `&&` — move that logic into your entrypoint binary or an
   init container.

> Do not "fix" this by shipping the `-dev` variant to production. It exists for
> builders and debugging, and it deliberately carries a shell and toolchain you
> do not want on a running workload.

### Images run as non-root

Production images run as a non-root user, UID `65532`. A small number that need
kernel capabilities to do their job (kube-vip, for instance) are the exception,
and every image's page lists the UID it actually runs as. Anything writing to a
path owned by root fails. Common fixes:

- Write to a volume or `emptyDir` your workload owns, not to `/`.
- Set `fsGroup` in the pod security context so mounted volumes are group-writable.
- If you build on top of a Minimal image and need to `COPY` files the process
  will write to, use `COPY --chown=65532:65532`.

Check the exact user and architecture for any image on its page in the
[directory](/images) — each one lists the UID it runs as.

### Paths and entrypoints may differ

Config file locations and entrypoints follow the upstream project's conventions,
which will not always match a repackaged image you were using before. The fastest
way to find out is to look, using the dev variant:

```
docker run --rm -it --entrypoint /bin/sh ghcr.io/rtvkiz/minimal-nginx:latest-dev
```

Then compare against the **Specifications** and **Packages** tabs on that image's
page, which list the entrypoint, exposed ports and the full package inventory.

## 4. Verify what you pulled

The reason to use hardened images at all is that the claims are checkable. Do
this once as part of the migration, and ideally keep it in CI.

Build provenance — proves the image came from the workflow in the public repo,
at a specific commit:

```
gh attestation verify oci://ghcr.io/rtvkiz/minimal-python:latest --owner rtvkiz
```

The SBOM, as an SPDX attestation:

```
cosign verify-attestation --type spdxjson \
  --certificate-identity-regexp='https://github.com/rtvkiz/minimal/' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/rtvkiz/minimal-python:latest \
  | jq -r '.payload | @base64d | fromjson | .predicate' > python-sbom.spdx.json
```

Minimal publishes SLSA v1.0 **Build L2** provenance. Not L3 — L3 needs a
reusable workflow isolating the build from its caller, and this project does not
have that yet. If your compliance programme requires L3, that is a real reason to
stay on a commercial vendor.

## 5. Scan it yourself before you commit

Do not take our comparison on faith — reproduce it:

```
grype ghcr.io/rtvkiz/minimal-python:latest
```

We publish the [full head-to-head scan data](/compare/minimus), including the
raw CSV and the images where **Minimal comes off worse**. Solr is the clearest
current example: it carries materially more findings than the Minimus
equivalent, most of it in bundled Java libraries. If Solr is on your critical
path, that row should inform your decision, and it is why we publish it rather
than quietly omitting it.

## 6. Roll out gradually

1. Migrate one low-risk service first — an internal tool or a batch job.
2. Run it through your normal test suite, watching for the three failure modes
   in step 3 rather than for subtle runtime differences.
3. Add the verification from step 4 to CI so a bad or unsigned image cannot ship.
4. Migrate the rest in batches, by image family rather than by service, so each
   batch exercises one base at a time.

## When not to migrate

Worth stating plainly. Stay where you are if you need thousands of images, a
support contract with an SLA, FedRAMP or STIG artefacts, SLSA Build L3, or CVE
remediation someone is contractually obliged to deliver. Minimal is a small,
auditable, MIT-licensed catalogue that costs nothing and asks for no account. It
is not a commercial product and does not replace one.

If that trade is the one you want, start with the [image directory](/images) and
the [comparison data](/compare).
