---
title: "Why your scanner reports zero CVEs"
description: "A clean Grype report can mean your image is clean, or it can mean the scanner never identified the software inside it. Here is the difference, and how to tell which one you have."
published: "2026-09-06"
---

A vulnerability report with nothing in it has two possible meanings, and they
look identical:

1. The scanner identified the software in your image and found no known
   vulnerabilities.
2. The scanner did not identify the software at all, so it had nothing to match
   against.

The second one is worse than a report full of findings, because it is
indistinguishable from success. Nobody escalates a green scan.

We hit this in a way that was easy to measure. Two builds of HAProxy, the same
upstream version, the same source, the same everything — except the name of the
apk package inside. One reported **0 findings**. The other reported **14**. The
binaries were byte-identical in every way that matters to an attacker.

## What the scanner is actually doing

Grype does not look at your image and recognise HAProxy. It reads a package
inventory produced by Syft, and then matches each entry in that inventory
against vulnerability data. Two of those matching paths matter here:

| Path | Keyed on |
|---|---|
| Distro security database (e.g. `wolfi:distro:wolfi:rolling`) | the apk package **name** |
| `nvd:cpe` | a CPE that Syft **derives from** the apk package name |

Both are keyed on a string. Not a hash, not a symbol table, not the contents of
the binary — the name recorded in the package database.

So if the package inside your image is called `haproxy`, the distro database has
an entry under `haproxy`, NVD has `cpe:2.3:a:haproxy:haproxy:*`, and both paths
hit. If you named it something reasonable-sounding but nonstandard —
`haproxy-minimal`, `haproxy-slim`, `our-haproxy` — then:

- the distro database has no entry under that name, so that path finds nothing;
- Syft derives `cpe:2.3:a:haproxy-minimal:haproxy-minimal:*`, which matches
  nothing in NVD, because NVD does not index a product by that name.

Two paths, both broken by the same string, and no error anywhere. The scan
succeeds. It just has nothing to say.

## Why a CPE declaration does not save you

The obvious fix is to declare the correct CPE in your build config. For scanning
the *image*, it does not help.

Syft's `apk-db-cataloger` reads `/usr/lib/apk/db/installed`. That file records
the package name, version and dependencies. It has no CPE field. A CPE you
declared at build time lives in your build metadata, and an SBOM embedded at,
say, `/var/lib/db/sbom/` is not what `grype <image>` reads either.

So the package name is not a label on the identity. For a C or C++ image it *is*
the identity, and renaming the package is the only fix.

## Go images are accidentally protected

If your image is a Go binary, you may have never seen this, and that is luck
rather than design. Syft's `go-module` cataloguer reads the build information
that the Go toolchain embeds in every binary — module path and dependency
versions. That gives the image a second, independent identity that has nothing
to do with the apk name.

The practical consequence is uneven: a Go image with a mangled package name
still gets its dependencies scanned. A C image with the same mistake is
completely invisible. If you are auditing a mixed fleet, the C and C++ images are
where to look first.

## How to check your own images

The useful question is not "does my scan pass" but "did the scanner find the
thing I care about". Ask it directly.

List what the scanner thinks is installed:

```
syft ghcr.io/rtvkiz/minimal-haproxy:latest -o json \
  | jq -r '.artifacts[] | "\(.type)\t\(.name)\t\(.version)"' | sort
```

Look at the CPEs it derived, which is where a bad name shows up:

```
syft <your-image> -o json | jq -r '.artifacts[].cpes[]?' | sort -u
```

If you see a product field that no vendor would ever publish — your internal
suffix, your company name, a `-slim` or `-minimal` — that entry is matching
nothing.

Then confirm the negative is real. Scan a version you *know* has published
advisories:

```
grype <your-image>:<an-old-tag>
```

An old build of anything widely deployed should produce findings. If an image
from a year ago is also clean, the problem is identification, not hygiene. This
takes a minute and is the single most useful check you can run against a
scanning pipeline you have not verified before.

## What we do about it

Every package we build carries the name upstream uses — `haproxy`, `nginx`,
`redis`, `postgresql` — never a decorated variant. The image is called
`minimal-haproxy`; the *package* inside it is `haproxy`. Those are different
namespaces and only one of them is load-bearing for scanners.

That rule is enforced by a check that runs on every pull request, not by
convention, because it is exactly the kind of thing that is invisible until
someone re-reads it. A suffix, or a mismatch between the package we build and
the package the image config asks for, fails the build.

The honest caveat: matching by name means you inherit whatever the advisory
feeds say about that name, including their mistakes and their timing. Naming
things correctly gets you into the conversation. It does not end it.

## The general point

Scanner output is a claim about what was *identified*, not about what is
*present*. Before you trust a clean report — ours or anyone's — confirm the
scanner listed the software you expected, with a version you recognise, under a
name the advisory databases actually use.

A clean scan of an unidentified image is not a security result. It is an empty
question.
