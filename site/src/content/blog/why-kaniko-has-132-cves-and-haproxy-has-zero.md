---
title: "Why kaniko has 132 CVEs and haproxy has zero, in the same catalog"
description: "43% of our images scan clean. One of the rest has 132 unique CVEs. Both numbers are honest; the gap is about what the scanner can see, not how carefully either image was built."
published: "2026-10-21"
---

As of the scan behind our published comparison data, 58 of our 135 scanned
images report zero unique CVEs. One image, kaniko, reports 132: 8 critical,
26 high. Same catalog, same build pipeline, same daily-rebuild policy. The
gap is real, and it is not the story you'd expect from a "zero CVEs" badge.

## What's actually inside each image

haproxy, redis-slim, nginx, postgres-slim, unbound: all zero. All of them
are C binaries built from source, and the image contains three or four apk
packages total, something like `haproxy`, `wolfi-baselayout`,
`ca-certificates-bundle`. That's the entire inventory Syft can produce for
them, because apk packages are the only unit it knows how to catalog in a
C image.

kaniko is also built from source, also a handful of apk packages: `kaniko`,
`wolfi-baselayout`, `ca-certificates-bundle`. Running Syft against it
directly tells a different story:

```
$ syft ghcr.io/rtvkiz/minimal-kaniko:latest -o json | jq '.artifacts | group_by(.type) | map({type: .[0].type, count: length})'
[
  { "type": "apk", "count": 3 },
  { "type": "go-module", "count": 175 }
]
```

175 Go modules, found and named individually, each one checked against
vulnerability data on its own version. kaniko statically links most of a
container-building toolchain: image layer handling, registry clients,
credential helpers, the libraries that make "build an OCI image with no
Docker daemon" possible. All of that compiles into one static binary, and
all of it was always there. The scanner just couldn't see it in a C image.

## This is the mirror image of a bug we wrote about before

We've covered the other direction: a C or C++ image can go completely
invisible to a scanner if its apk package is named something the advisory
feeds don't recognize, something like `haproxy-minimal` instead of
`haproxy`. That's a false zero, a scan that found nothing because it was
never looking at the right name.

kaniko's 132 is the opposite failure mode, and it isn't a failure at all.
Go's toolchain embeds a full build manifest (module path, every dependency,
every version) directly into the binary. Syft reads that manifest. So a Go
image gets audited at a depth no C image can match with apk alone, and if
any of those 175 modules has an old transitive dependency with a known CVE,
it shows up by name, with a version, with a fix available. That's the
scanner doing its job well, not badly.

## So which image is actually safer

Possibly haproxy, but you can't tell that from these two numbers, and that's
the point. haproxy's zero reflects three packages, fully resolved, nothing
unaccounted for. kaniko's 132 reflects 178 artifacts, fully resolved,
nothing unaccounted for either. Neither number says "unscanned." Both say
"here is everything we found, named and versioned." The honest comparison
isn't 0 versus 132, it's: does each finding have a fix version available,
and is it worth shipping before that fix lands.

For kaniko specifically: most of the 132 trace back to a handful of vendored
libraries whose own upstream hasn't cut a patched release yet for the
version kaniko's build currently pins. We rebuild kaniko daily against
upstream HEAD, so the number moves as those libraries patch; it is not a
number we are sitting on.

## What to actually check before trusting either number

Don't stop at the top-line count on any hardened image, ours or a
competitor's. Ask what the scanner could see:

```
syft <image> -o json | jq '.artifacts | group_by(.type) | map({type: .[0].type, count: length})'
```

If that comes back with one artifact type and a handful of packages for
something that is obviously a large piece of software, the zero you're
looking at is a coverage gap, not a security result. If it comes back with
hundreds of granular modules and a nonzero CVE count, that is usually the
more thoroughly audited image, even though the number on the page looks
worse. The [image directory](/images/) lists the package and module count
for every image we publish, and the [raw comparison data](/compare/) has the
per-image breakdown behind every total in this post, kaniko included. We
don't trim that row to make the catalog average look better.
