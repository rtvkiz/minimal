---
title: "The Redis license field nobody rechecked for nine months"
description: "Our redis-slim build has declared SSPL-1.0 since it was created in January. Redis stopped being SSPL-only in May. The field was correct on day one, which is how it stayed wrong for nine months."
published: "2026-10-21"
---

`images/redis-slim/melange.yaml` has declared `license: SSPL-1.0` since the
file was created on 2026-01-29. Nothing has touched that line since. The
image we build today is Redis 8.10.2, and Redis 8.10.2 is not SSPL-only.

## What actually changed upstream

Redis relicensed away from the permissive BSD-3-Clause in March 2024,
replacing it with a choice of SSPLv1 or RSALv2 for versions 7.4 and later.
That part people mostly remember, because it was the controversial change:
Redis stopped being OSI-approved open source, forks like Valkey appeared,
and the licensing news cycle happened.

What gets forgotten is the second change. Redis 8.0, released in May 2025,
added AGPLv3 as a third option alongside the two source-available licenses.
AGPL is OSI-approved. Practically, that means current Redis is usable under
an actual open source license again, you just have to pick it, and the
"Redis went closed" story that made headlines in 2024 stopped being accurate
eighteen months before we wrote `SSPL-1.0` into a melange recipe.

## Why a stale field is worse than a wrong one you'd notice

A build failure gets fixed because the pipeline is red until someone fixes
it. A license field has no such pressure. It sits in `copyright:`, gets
baked into the SBOM and the `org.opencontainers.image.licenses` annotation,
and every one of those downstream consumers (a procurement checklist, a
compliance scanner, someone reading the image page before they pull it)
treats it as a fact rather than a value someone typed once at onboarding
time and never revisited. The image built, the tests passed, the scanner
found what it was supposed to find. None of that checks whether the license
string still matches reality nine months later.

This is the same failure shape as the stale-`lastmod` problem we fixed on
this site: a field that is technically present and technically well-formed,
but nobody re-derives it, so it quietly diverges from the thing it's
supposed to describe. The fix there was a CI check that verifies claims
against their source instead of trusting that someone remembered to update
them. We don't have the equivalent check for license fields yet. This post
is partly us noticing we should.

## What we're changing

`SSPL-1.0` becomes `AGPL-3.0-only`, since that's the OSI-approved option we
want attached to a catalog that advertises itself as open source, and it's
the option our own onboarding policy already names as the resolution for
this exact image (`docs/onboarding.md` has carried a note to redeclare this
since before this post was written). We're not relicensing anything; Redis
offers AGPLv3 and we're choosing to build under the license we actually
distribute, instead of the one we happened to write down in January.

## What to check on your own images

Grep every `melange.yaml`, Dockerfile `LABEL`, or image-build manifest you
maintain for a hardcoded SPDX license string, and ask one question: has the
upstream project's actual license changed since whoever wrote that line last
looked? The answer is usually no. The cost of checking is one `grep` and
five minutes reading a CHANGELOG. The cost of not checking is a field that
looks authoritative, gets copied into an SBOM, and is quietly wrong for as
long as nobody has a reason to look at it again.

```
grep -rn "license:" images/*/melange.yaml
```

For anything with a recent major version bump, cross-check against the
version's own `LICENSE` file in the upstream repo rather than against what
you remember the license being. Memory is exactly what goes stale here.
