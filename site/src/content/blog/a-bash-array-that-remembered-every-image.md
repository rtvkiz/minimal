---
title: "A bash array that remembered every image it had seen"
description: "Re-declaring an associative array in a bash loop does not empty it. Our CVE patcher did that once per image, and temporal-server got pins from images it had never heard of."
published: "2026-11-17"
tags: ["ci-and-automation"]
---

Once a day a workflow scans our published Go images with grype and, for
each one, writes a block of `go get module@fixed-version` lines into that
image's build recipe. One run covers 103 images. On 14 and 15 November the
regenerated block for [temporal-server](/images/temporal-server/) failed to compile, on both
architectures, with:

```
common/wideevents/attrs.go:13:38: undefined: log.KeyValue
```

We had seen that exact error before. It is what happens when temporal's
source, which uses the pre-1.0 OpenTelemetry logs API, is built against
`go.opentelemetry.io/otel/log` v1.x, and the generator already had a guard
written specifically to keep temporal-server off that version
([the earlier story](/blog/a-dependency-bump-that-fixed-nothing-and-broke-four-builds/)).
The guard had run, and its log said it was not forcing temporal-server's otel
modules up. The block it wrote contained `otel/log@v1.47.0` anyway.

## Pins nobody logged

Comparing the block against that image's own scan log turned up 12 pins with
no line of output explaining them. Besides the otel log modules there were
`github.com/slack-go/slack`, `knative.dev/pkg` and `hashicorp/go-getter`,
none of which temporal-server's own scan had reported. They had all appeared
earlier in the same run, in other images' scans.

The generator has a step that reconciles versions inside one image's pin set:
if module A's new version requires a newer B than we were about to pin, raise
B. It keeps the pins in an associative array, declared at the top of each
image's iteration:

```bash
for IMAGE in "${!MODROOTS[@]}"; do
  ...
  declare -A PIN
  while IFS= read -r mv; do PIN["${mv%@*}"]="${mv##*@}"; done <<< "$FIXES"
  ...
  if [ "$HARMONIZED" = true ]; then
    # rebuild this image's pin list from PIN
  fi
done
```

That `declare -A PIN` reads like "give me a new, empty array". At the top level
of a script it is not. If `PIN` already exists, `declare -A` leaves it alone,
contents included:

```console
$ for i in a b; do declare -A PIN; PIN[$i]=1; echo "${!PIN[*]}"; done
a
b a
```

So `PIN` accumulated every pin from every image scanned so far. The only thing
that kept this harmless for months was the last branch: an image's list is
rebuilt from `PIN` only when the reconciler actually changed something.

## Three images out of 103

In that run the reconciler changed something for exactly three images: [mimir](/images/mimir/),
[tempo](/images/tempo/) and temporal-server. Each one got the whole accumulated array written
into its recipe, including pins from the images scanned before it. temporal-
server was 78th in line.

Two of the three were fine by luck. A pin for a module an image never imports
is a no-op: `go get` adds it and `go mod tidy` removes it again. And mimir and
tempo build cleanly against `otel/log` v1.47.0. temporal-server imports
`otel/log` and is still on the old API, so the leaked pins that mattered landed
on the one image they could break.

## The fix and the habit

```bash
unset PIN
declare -A PIN
```

That was not the only problem. Grype's own suggested fix for temporal-server
was `otel/sdk@v1.47.0`, and core otel at v1.47.0 requires `otel/log` at v1.47.0
too, so the guard's "keep grype's version" fallback still let the breaking
release in through a module that was not on its list. The guard now checks
whether core otel at that version requires `otel/log`, and defers the bump if
it does. With both fixes, temporal-server's block went from 73 pins to 60 and
the build went green.

Inside a function, `local -A` gives you a fresh array on every call. At the top
level there is no scope to reset, so a `declare` inside a loop is a statement
about type, not about contents. Any per-iteration associative array in a
top-level loop needs an explicit `unset`.

The more transferable part is why it took two days to see. The generator logs
the pins it changes, not the pins it writes, so a pin that arrived through the
array printed nothing, and the guard's own log line was accurate about what the
guard did. When a generated artifact disagrees with its generator's log, diff
the artifact against the log line by line. The difference is where the bug is.
