---
title: "Migrating from Minimus to Minimal"
description: "What actually breaks when you move a container image to Minimal: the missing shell, the non-root UID, and the tag you should not have pinned. With the commands to verify what you pulled."
published: "2026-08-31"
---

Swapping one hardened base for another is mostly a find-and-replace. The
interesting part is the small number of things that break afterward, and they
are the same ones every time: something calls `/bin/sh`, something writes to a
directory it does not own, or someone pinned `:latest` and got moved across a
major version.

This covers what Minimal does. It does not describe Minimus's internals — their
docs are the authority there, and guessing at someone else's images is how
comparison content ends up wrong.

## Change the reference

One repository per image on GHCR, `minimal-` prefixed:

```diff
-FROM <your-current-registry>/python:latest
+FROM ghcr.io/rtvkiz/minimal-python:latest
```

No login, no account:

```
docker pull ghcr.io/rtvkiz/minimal-python:latest
```

Names follow the upstream project — `nginx`, `redis-slim`, `postgres-slim`,
`kafka`. Before you go further, check the [image directory](/images/) and confirm
everything you depend on is actually there. The catalog is deliberately smaller
than a commercial vendor's. Finding the gap now is much cheaper than finding it
with half your services moved.

## Pick a tag that will not surprise you

`:latest` on Minimal crosses major versions. That is rarely what a deployment
wants, so decide deliberately:

| You want | Pin | Behavior |
| --- | --- | --- |
| A byte-identical artifact | `minimal-caddy@sha256:…` | Immutable, never moves |
| Patches without breaking upgrades | `minimal-caddy:2` | Newest release in that major line |
| Tighter still | `minimal-caddy:2.11` | Newest patch in that minor line |

Most people want the major line. You keep getting security rebuilds and you
never get moved across an upstream breaking release. Note that an exact version
tag like `:2.11.4-r0` is not the safe conservative choice it looks like — it
never moves, which also means it never picks up a fix. [Tags and
pinning](/docs/tags/) has the rest.

## Then fix the things that break

### No shell

Most production images have no shell and no package manager. Anything using the
shell form fails immediately, and the error is usually some variation of:

```
exec: "/bin/sh": stat /bin/sh: no such file or directory
```

So this stops working:

```yaml
command: ["/bin/sh", "-c", "exec myapp --flag"]
```

Two ways out. The better one is to keep the shell in the builder stage only —
every image has a `-dev` companion carrying a shell, package manager and
toolchain, which exists for exactly this:

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

The other is to drop the wrapper entirely and use exec form, so nothing needs a
shell to start. If you were relying on the shell for variable expansion or
pipes, that logic has to move into your entrypoint binary or an init container.

> Shipping the `-dev` variant to production is not a fix. It carries the shell
> and toolchain you were trying to get rid of.

### Non-root by default

Production images run as UID `65532`. A handful that need kernel capabilities
(kube-vip, for one) differ, and every image's page lists the UID it actually
uses.

What this breaks is writes to root-owned paths, which surface as a plain
`permission denied` somewhere unhelpful. Usually one of these fixes it:

- Write to a volume or `emptyDir` the workload owns rather than into `/`.
- Set `fsGroup` in the pod security context so mounted volumes are group-writable.
- `COPY --chown=65532:65532` for files your process needs to write to later.

### Paths that moved

Config locations and entrypoints follow upstream conventions, which may not
match whatever repackaged image you were on before. Rather than guess, go and
look:

```
docker run --rm -it --entrypoint /bin/sh ghcr.io/rtvkiz/minimal-nginx:latest-dev
```

The **Specifications** and **Packages** tabs on each image's page list the
entrypoint, exposed ports and full package inventory if you would rather read
than poke.

## Verify what you pulled

Worth doing once during the migration and then leaving in CI, since the whole
argument for hardened images is that you do not have to take anyone's word for
it.

Provenance, which ties the image to the workflow and commit that built it:

```
gh attestation verify oci://ghcr.io/rtvkiz/minimal-python:latest --owner rtvkiz
```

The SBOM:

```
cosign verify-attestation --type spdxjson \
  --certificate-identity-regexp='https://github.com/rtvkiz/minimal/' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/rtvkiz/minimal-python:latest \
  | jq -r '.payload | @base64d | fromjson | .predicate' > python-sbom.spdx.json
```

That is SLSA v1.0 **Build L2**, not L3. L3 needs a reusable workflow isolating
the build from its caller and this project does not have one yet. If your
compliance program requires L3, that is a genuine reason not to migrate.

## Scan it before you commit to it

```
grype ghcr.io/rtvkiz/minimal-python:latest
```

The [full head-to-head data](/compare/minimus/) is published, raw CSV included,
and it contains the images where Minimal comes off worse. Solr is the current
example: materially more findings than the Minimus equivalent, most of it in
bundled Java libraries. If Solr is on your critical path, that is a reason to
wait, and you should know it from us rather than discover it yourself.

## Rolling it out

Start with something you can afford to break — an internal tool, a batch job —
and run it through your normal tests. You are watching for the three failure
modes above, not for subtle runtime differences; if it starts and serves
traffic, it is almost certainly fine.

After that, move in batches grouped by base image rather than by service. Each
batch then exercises one runtime at a time, so when something does break you
know which base to blame.

## When to stay where you are

If you need thousands of images, an SLA, FedRAMP or STIG artifacts, SLSA Build
L3, or CVE remediation somebody is contractually obliged to deliver, buy the
commercial product. Minimal is a small MIT-licensed catalog that costs nothing
and asks for no account. It is not a substitute for a vendor relationship and
does not pretend to be.

If that trade suits you, the [image directory](/images/) and the [comparison
data](/compare/) are the places to start.
