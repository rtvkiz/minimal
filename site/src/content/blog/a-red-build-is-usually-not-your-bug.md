---
title: "A red build is usually not your bug"
description: "Most CI failures in a dependency-heavy pipeline are someone else's outage wearing a convincing error message. How to classify one in about two minutes before you start debugging."
published: "2026-09-06"
---

A build that pulls from GitHub, a module proxy, Maven Central and a package
index has four ways to fail that have nothing to do with your code. In a
pipeline that rebuilds continuously, those transient failures outnumber the real
ones — and the expensive mistake is spending an hour debugging a change that was
never broken.

The problem is that upstream outages rarely announce themselves. They arrive
wearing an error message about your code.

## Three real examples

**"No release of log4j-web 2.25.4"** — a build step checked whether an artifact
existed and reported it missing. It was not missing. Maven Central was returning
`403` because we had been rate-limited, and the check used `curl -sfI`, where
`-f` collapses every HTTP error into the same non-zero exit. "Server refused to
answer me" and "the file is not there" became the same signal. The fix was to
read the status code instead of the exit code, and say `unavailable` when the
answer is neither 200 nor 404.

**"Missing go.sum entry"** — a classic real error, and this time it was a stream
error from `proxy.golang.org` mid-download. The next run passed with no change.

**A dependency conflict that named the wrong module** — the resolver reported a
version requirement conflict, and the actual cause was a workspace file pinned
below what a bumped dependency required. The message pointed at the module; the
fix was three directories up.

Pattern: the error is generated at the point of *failure*, which is often far
from the *cause*.

## The tell that saves the most time

**If one architecture passes and the other fails on the same commit, it is
almost never your code.**

The source is identical. The build config is identical. A genuine bug in either
would fail both. What differs is which runner, which mirror, which moment in
time — so a split result points at the network or the environment, not the
diff.

This one observation resolves more red builds than any other, and it takes five
seconds to check. Look at the matrix before you look at the diff.

## A two-minute triage

Before debugging, answer these in order:

**1. Did this exact commit pass before?**
If the scheduled rebuild was green an hour ago and nothing merged since, the
code is not the variable.

**2. Do the failures cluster by architecture, or by upstream?**
One arch failing is environmental. Several unrelated images failing the same
step at the same time is an upstream outage — unrelated images do not develop
the same bug simultaneously.

**3. What is the actual status code?**
Not the exit code. `403`, `429`, `502` and a timeout are all "they would not
answer"; `404` is "it is not there". Any check that treats those as one thing
will eventually report an outage as a missing file.

**4. Does it reproduce on a re-run?**
Cheap, and decisive. A flake fails once. A real bug fails every time. Re-run
*before* you start reading code — but re-run **once**. Re-running until green is
how a real intermittent bug gets shipped.

## Building this into the pipeline

Triage that lives only in someone's head does not survive. Two things worth
encoding:

**Retry with meaning.** Add retries to network fetches, but be careful what you
retry with. `curl -sfI --retry 5` does not retry HTTP errors the way people
expect — without `--retry-all-errors`, and with `-f` in play, a `403` is not
necessarily a retryable condition to curl. Test that your retry actually
retries; a flag that looks right and does nothing is worse than no flag, because
it stops anyone from looking again.

**Make the failure message name the class.** Compare:

```
ERROR: no release of log4j-web 2.25.4 found
```

with:

```
Maven Central unreachable for log4j-web (HTTP 403 after retries)
  — transient, not a missing release
```

Same failure, and the second one ends the investigation in the first line. Every
check that reaches the network should be able to distinguish "the answer is no"
from "there was no answer", and should say which it got.

## What this is not

This is not an argument for ignoring red builds. It is an argument for spending
the first two minutes deciding *which kind* of red you have, because the two
kinds need completely different responses — and the wrong response to a
transient failure is a code change that papers over it.

The failure mode to avoid is the opposite one: treating everything as flaky and
re-running until green. That is how a genuine intermittent bug reaches
production with a green checkmark on it. The discipline is to classify honestly,
not to classify optimistically.
