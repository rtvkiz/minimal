---
title: "Permission denied: running containers as a non-root user"
description: "Almost every non-root container failure is one of four things. What each looks like, why the fix is not chmod 777, and how to make a directory writable in the image itself."
published: "2026-09-06"
---

`runAsNonRoot: true` is one of the highest-value settings in a Pod spec, and the
first thing most people hit after enabling it is this:

```
Error: EACCES: permission denied, mkdir '/data'
```

Almost every instance is one of four causes. They have different fixes, and
`chmod 777` is not any of them.

## 1. The directory does not exist, and a non-root process cannot create it

The most common one, and the most misread. The error says permission denied on
`/data`, so people chmod `/data` — but `/data` does not exist. The process is
being denied permission to create it *in `/`*, which is root-owned.

You cannot fix this at runtime, because there is no point at which a non-root
process can create a directory in `/`. It has to exist in the image, owned by
the right uid.

With apko, that is a `paths:` entry:

```yaml
paths:
  - path: /data
    type: directory
    uid: 65532
    gid: 65532
    permissions: 0o755
```

The Dockerfile equivalent:

```dockerfile
RUN mkdir -p /data && chown 65532:65532 /data
USER 65532
```

Build the directory into the image. Every image we publish that needs writable
state ships it this way.

A related trap if you build with a tool that generates an SBOM after the build:
creating `/var/...` directories inside the build pipeline can fail, because the
SBOM step may run as your host user after the sandbox exits and cannot write
into a root-owned destination. Declaring the directory in the image config
avoids that entirely.

## 2. The application writes to `$HOME`, and there is no home directory

This one is sneaky, because the error rarely mentions `$HOME`. A CLI tool wants
to cache something, resolves `~`, gets `/` or an empty string, and fails
somewhere that looks unrelated.

Set `HOME` to somewhere writable:

```yaml
environment:
  HOME: /tmp
```

Cosign caches its trust root under `$HOME/.sigstore`; plenty of tools do the
same thing. If a binary works as root and fails as non-root with a confusing
path error, check `HOME` before anything else.

## 3. The mounted volume is owned by someone else

The image is correct and the mount is not. On Kubernetes, `fsGroup` is the
supported lever:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  fsGroup: 65532
```

`fsGroup` makes the kubelet set group ownership on the volume so your uid can
write. It does not apply to every volume type — `hostPath` in particular is
whatever it already was on the node.

Locally, the equivalent trap bites in test scripts:

```bash
work=$(mktemp -d)              # 0700, owned by you
docker run -v "$work:/workspace" ...   # container is uid 65532 → denied
```

`mktemp -d` creates `0700` owned by the invoking user, so a container running as
a different uid cannot write into it. In a throwaway test directory,
`chmod 0777 "$work"` is the correct fix and nothing is weakened by it — the
directory exists for thirty seconds and holds nothing.

That is *not* a licence to `chmod 777` a real volume. The reason it is fine here
is the lifetime and the contents, not the permission bits.

## 4. You can read the file, but not the one the container wrote

The mirror image of the last problem, and it shows up in test scripts:

```bash
grep 'something' "$work/output"    # Permission denied
```

Files the container creates are owned by *its* uid, often `0600`. Your user
cannot read them even though you own the directory. Assert on existence rather
than content when you only need to know something was produced:

```bash
[ -s "$work/output" ] || { echo "no output produced"; exit 1; }
```

`stat` only needs the directory permission, which you have. Reading needs the
file permission, which you may not.

## Why 65532

It is the conventional "nonroot" uid in the distroless ecosystem, and the value
Kubernetes examples use. Nothing magic — the important properties are that it is
not 0 and that it is fixed, so a volume chowned for one image works for the next.

`runAsNonRoot: true` on its own only asserts that the image does not run as
root. It does not pick a uid. Pin `runAsUser` too, or an image that changes its
default uid silently changes who owns your data.

## The one honest exception

Some workloads genuinely require root, and pretending otherwise produces an
image that does not run. A build daemon that creates mount and user namespaces
is the clearest case: it will refuse to start under an unprivileged uid, so
"non-root" there is not a stricter setting, it is a broken one.

The right response is to say so explicitly in the image's documentation rather
than ship something that fails at deploy time — and to keep the rest of the
hardening. Non-root is one control among several, not the whole of it.

## Checklist

When a container fails as non-root, in order:

1. Does the directory exist in the image, owned by the run-as uid?
2. Is `HOME` set to somewhere writable?
3. Is the volume owned correctly — `fsGroup` on Kubernetes, real permissions locally?
4. Are you trying to read a file the container wrote as a different uid?

Four questions. One of them is nearly always it.
