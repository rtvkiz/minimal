---
title: "The x86_64 package that needed an ARM dynamic loader"
description: "Ghost 6.78.0 compiled cleanly and then could not be installed on amd64: its package declared a runtime dependency on the aarch64 loader. The cause was a binary nobody on x86 would ever run."
published: "2026-11-17"
tags: ["packaging-and-licensing", "ci-and-automation"]
---

The Ghost 6.78.0 bump looked like the most boring change in the repository: a
version number and a checksum. The package built on both architectures. Then
image assembly failed on x86_64 with this:

```
for arch "amd64": solving "ghost" constraint: resolving "ghost-6.78.0-r0.apk" deps:
solving "so:ld-linux-aarch64.so.1" constraint: nothing provides "so:ld-linux-aarch64.so.1"
```

The amd64 build of Ghost had declared that it needs the ARM64 dynamic loader
to run. Nothing in an amd64 repository provides that, so the package could not
be installed, so there was no image.

## Where the dependency came from

We build packages with melange, and melange does automatic dependency
detection: after the build, it walks every ELF file in the package, reads what
each one links against, and adds those as runtime dependencies. You do not list
`libc.so.6` by hand; melange finds it. That is a good default, and it is the
whole mechanism behind this failure.

Ghost is a Node application, installed with `npm install` inside the build.
6.78.0's dependency tree now included a family of modules named `bare-fs`,
`bare-buffer`, `bare-path` and `bare-url`, which npm describes as native
modules for Bare, a separate JavaScript runtime. Each ships its compiled
addons for every platform it supports, in a `prebuilds/` directory:

```
bare-fs/prebuilds/darwin-arm64/bare-fs.bare
bare-fs/prebuilds/win32-arm64/bare-fs.bare
bare-fs/prebuilds/linux-arm64/bare-fs.bare
...
```

melange flagged the macOS and Windows files with a warning about unsupported
architectures and moved on. The `linux-arm64` ones are Linux ELF shared
objects, linked against the aarch64 glibc and its loader,
`ld-linux-aarch64.so.1`. So the x86_64 package dutifully recorded
`so:ld-linux-aarch64.so.1` as something it needs at runtime.

None of these files would ever be loaded. Ghost runs on Node, not Bare, and
even if it did, an x86 host cannot execute an ARM binary. They were dead weight
that happened to be shaped exactly like a hard dependency.

## Why it compiled fine

Every step that actually runs code passed. npm installed, Ghost's own SQLite
driver built its native addon, and our build-time check that loads it and runs
`select 1` succeeded. The failure only exists at the boundary between "here is
a package" and "install this package", which is the first place anything reads
the dependency metadata seriously.

That is a useful thing to know about this class of bug. A smoke test that runs
the application inside the build sandbox will not catch it. Only resolving the
package the way a user would, against a repository for that architecture, does.

## The fix

Strip prebuilt binaries for every platform except the one being built, before
packaging:

```sh
case "$(uname -m)" in
  x86_64)  NODE_ARCH=x64 ;;
  aarch64) NODE_ARCH=arm64 ;;
esac
find /usr/lib/ghost/node_modules -type d -name prebuilds -prune | while read -r d; do
  for e in "$d"/*; do
    case "${e##*/}" in
      linux-"$NODE_ARCH"|linux-"$NODE_ARCH".*) ;;
      *) rm -rf "$e" ;;
    esac
  done
  find "$d" -name '*musl*' -exec rm -rf {} +
done
```

`musl` variants go too: the image is glibc-based, and a musl build needs a
loader the base does not ship, which would reproduce the same failure one name
over.

This is not specific to Ghost. Any package that vendors an `npm install`, or a
Python wheel cache, or anything else that ships "binaries for every platform,
pick one at runtime", is carrying files that automatic dependency detection
will read as requirements. It works until an upstream release adds the first
module whose foreign-architecture binary happens to be a Linux ELF. Then it
fails on the one architecture that does not match, at install time, in a
change that only touched a version number.
