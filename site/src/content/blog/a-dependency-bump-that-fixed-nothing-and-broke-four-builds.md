---
title: "A dependency bump that fixed nothing and broke four builds"
description: "An automated CVE patcher bumped a module nobody had a vulnerability in, and four builds broke the same way. Harmonizing a dependency family's versions is not the same thing as patching one."
published: "2026-10-14"
---

A transitive-dependency bot exists to do one job: find a package with a known
CVE, bump it to the fixed version, open a PR. The failure mode worth knowing
about is the one where it does that job correctly and still breaks your build,
because "bump the vulnerable package" quietly became "bump everything that
shares its namespace."

## What actually happened

`go.opentelemetry.io/otel/sdk/log` had a CVE-fix suggestion pointing at
`v0.21.0`. Reasonable so far: that's the next release in its own line. But
`v0.21.0` is also the release where OpenTelemetry Go rewrote the logs API:
`log.KeyValue` and `log.String`, which existed as package-level functions
through `v0.20.0`, were removed in favor of `attribute.KeyValue`. You can
verify this yourself: the file `log/keyvalue.go` is present in the `log/v0.20.0`
tag of `open-telemetry/opentelemetry-go` and absent in `log/v0.21.0`.

Four separate codebases were still calling the old API directly. Bumping the
one module that had a CVE pulled in an API their own source code didn't
support, and `go build` failed with `undefined: log.KeyValue`. Nothing in that
error mentions a version number, a security patch, or otel.

## The second break was worse

The first fix was: stop forcing that one submodule past the API boundary.
That held for exactly one run. The next time the bot ran, the same four builds
broke again. Different log lines this time, same root symptom.

The actual mechanism: `go.opentelemetry.io/otel`, the *core* module, started
hard-requiring `go.opentelemetry.io/otel/log` at its own version as of the
`v1.47.0` release. `v1.44.0` and `v1.46.0`'s `go.mod` have no such line;
`v1.47.0`'s does. Core `otel` had nothing to do with the logs API and had its
own legitimate, unrelated fix version, but bumping it dragged the same
breaking log API in as a transitive requirement. No `otel/log` entry showed up
anywhere in the bot's own diff to warn about it.

This is the part worth remembering: the dangerous version wasn't the one
grype flagged. It was a module the CVE never mentioned, pulled in by a
dependency *of* the module grype flagged.

## The fix that actually held

Stop treating "these modules share a namespace, so harmonize them to the same
version" as safe by default. A log-family submodule and a core module are
different Go modules with independent version lines; nothing requires them to
move together except a human assumption that they should. Once the fix
checked whether the harmonized *core* version itself introduced a new
cross-module requirement, not just whether the log submodule's own version
looked risky, the bot's regenerated PRs stopped reintroducing the break, even
across several more automated re-runs.

That's really the whole lesson, stated more generally than one otel bug
deserves: if your dependency bot (or your own `go get`) bumps package A for a
real CVE, and A's own `go.mod` picks up a new hard requirement on package B as
a side effect, you now have B's new behavior in your build whether or not B
had anything to fix. "Does the fix version satisfy what my code calls" and
"does the fix version satisfy what *its own dependencies* now require" are two
different questions. A patcher that only asks the first one will eventually
ship something that compiles against last week's dependency graph and fails
against today's.
