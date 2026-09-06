---
title: "Debugging a container that has no shell"
description: "Distroless images remove the shell an attacker would use, and the one you would use. Here are the techniques that still work, in the order you should reach for them."
published: "2026-09-06"
---

The first time `kubectl exec` fails on a distroless image, it looks like the
image is broken:

```
$ docker exec -it mycontainer sh
OCI runtime exec failed: exec: "sh": executable file not found in $PATH
```

Nothing is broken. There is no shell, on purpose. The same absence that stops an
attacker from chaining a command injection into a foothold stops you from poking
around, and the techniques below are how you work anyway.

They are listed roughly in the order to try them: cheapest and least invasive
first.

## 1. Run a different binary in the same image

`--entrypoint` replaces the command without changing the image. Most of what you
want to know early — is the binary there, what version is it, does it parse the
config — needs no shell at all:

```
docker run --rm --entrypoint /usr/bin/haproxy ghcr.io/rtvkiz/minimal-haproxy:latest -vv
docker run --rm -v "$PWD/haproxy.cfg:/etc/haproxy/haproxy.cfg:ro" \
  --entrypoint /usr/bin/haproxy ghcr.io/rtvkiz/minimal-haproxy:latest \
  -c -f /etc/haproxy/haproxy.cfg
```

Note the second one: a config check, offline, with no shell involved. A
surprising number of "the container won't start" incidents end here.

## 2. Inspect the filesystem from outside

You do not need to be inside a container to read its filesystem.

```
# what is actually in the image, without running it
docker create --name tmp ghcr.io/rtvkiz/minimal-nginx:latest
docker export tmp | tar -tv | head -50
docker cp tmp:/etc/nginx/nginx.conf ./nginx.conf
docker rm tmp
```

`docker cp` works against a running container too, and works whether or not that
container has a shell. If your question is "what file is at this path", this is
the whole answer.

## 3. Attach a debug container that has the tools

This is the technique that replaces `exec` properly, and it is the one worth
learning if you only learn one.

Kubernetes:

```
kubectl debug -it mypod --image=busybox:latest --target=mycontainer
```

The `--target` flag is what makes it useful: the debug container shares the
target's process namespace, so `ps` sees the real process, and `/proc/1/root`
gives you the target's filesystem:

```
ls /proc/1/root/etc
cat /proc/1/root/etc/nginx/nginx.conf
```

Docker has an equivalent:

```
docker run --rm -it --pid=container:mycontainer \
  --network=container:mycontainer --cap-add SYS_PTRACE \
  busybox:latest sh
```

Sharing `--network` matters more than people expect. Half of "the service is
down" turns out to be DNS or a listener bound to `127.0.0.1`, and both are only
visible from inside that network namespace:

```
wget -qO- http://127.0.0.1:8080/healthz
nslookup my-service.default.svc.cluster.local
```

## 4. Use the dev variant

Every image we publish has a `-dev` tag carrying the same primary binary plus a
shell and the usual tools — `bash`, `curl`, `openssl`, `dig`, `jq`, `git`, `apk`:

```
docker run --rm -it --entrypoint /bin/bash ghcr.io/rtvkiz/minimal-nginx:latest-dev
```

Swap the tag, reproduce the problem, keep everything else identical. Because
both variants are built from the same package, a bug that reproduces in `-dev`
is a bug in your setup or in the software; a bug that *stops* reproducing is
usually about the missing shell or the tools themselves.

The rule that makes this safe: **`-dev` is for debugging, not for production.**
It exists so that the production image never needs to grow a shell "just for
now". A shell added during an incident is a shell that is still there a year
later.

## 5. Read the logs properly

Obvious, and still skipped:

```
docker logs --timestamps --tail 200 mycontainer
kubectl logs mypod -c mycontainer --previous   # the container that just crashed
```

`--previous` is the one people forget. A container in `CrashLoopBackOff` has
already told you why it died; the current instance may not have got far enough
to repeat it.

## What actually changes

The shift is from *interactive exploration* to *asking specific questions*. You
lose "let me look around", which is genuinely convenient. You keep everything
that is diagnostic, and you gain that the same absence works against an
attacker, continuously, in every container you run.

If you find yourself needing a shell in production repeatedly for the same
reason, that is a signal about the image or the workload — a missing health
endpoint, a config that cannot be validated ahead of time, logs that do not say
enough. Fixing the underlying gap is better than keeping a shell around for it.
