#!/usr/bin/env python3
"""Offline test of ghcr-gc.plan(): run before every sweep (cleanup-packages.yml).

A synthetic package with every shape the sweep must handle. If this fails the
workflow stops before any DELETE is issued.
"""
import importlib.util
import os
from datetime import datetime, timedelta, timezone

spec = importlib.util.spec_from_file_location(
    "gc", os.path.join(os.path.dirname(os.path.abspath(__file__)), "ghcr-gc.py"))
gc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gc)

now = datetime.now(timezone.utc)
old = now - timedelta(days=5)
V, G = [], {}


def dg(i):
    return "sha256:%064x" % i


def add(i, tags, created=old, kids=()):
    V.append({"id": i, "digest": dg(i), "tags": tags, "created": created})
    G[dg(i)] = [dg(k) for k in kids]


add(1, ["latest", "1.2.3-r0", "1.2"], kids=(2, 3))   # live multi-arch index
add(2, []); add(3, [])                                # its untagged per-arch manifests
add(4, ["sha256-%064x.sig" % 1])                      # signature of a live image
add(5, ["sha256-%064x" % 1], kids=(6,)); add(6, [])   # referrer index of a live image + child
add(7, ["sha256-%064x.sig" % 99])                     # orphan signature
for d in range(35):                                   # 35 prod + 35 dev dated builds
    add(100 + d, [f"1.2.3-r0-202610{d:02d}"], created=old - timedelta(days=d), kids=(300 + d,))
    add(300 + d, [])
    add(500 + d, [f"1.2.3-r0-202610{d:02d}-dev"], created=old - timedelta(days=d))
add(900, ["20260130"])                                # legacy bare date only
add(901, ["1.0.0-r1-amd64"])                          # legacy per-arch only
add(902, ["1.0.0-r1", "1.0.0-r1-arm64"])              # legacy co-tagged with a real tag: kept
add(950, [], created=now - timedelta(hours=2))        # fresh untagged (mid-publish): kept

live, sweep, info = gc.plan(V, lambda ds: {d: G.get(d, []) for d in ds}, now, keep_dated=30, min_age_hours=24)
swept = {v["id"] for v in sweep}
expect = ({7, 900, 901}
          | {100 + d for d in range(30, 35)}
          | {300 + d for d in range(30, 35)}
          | {500 + d for d in range(30, 35)})
assert swept == expect, f"unexpected sweep set: extra={sorted(swept - expect)} missing={sorted(expect - swept)}"
assert info["has_latest"]
assert info["broken"] == [] and info["broken_moving"] == []

# Broken roots: an old exact-version tag whose per-arch manifests are gone is
# swept; a broken moving tag is reported and nothing of it is swept.
add(1000, ["1.1.0-r0"], kids=(1001, 1002))            # index ok, both children 404
add(1003, ["sha256-%064x.sig" % 1000])                # its signature
add(1010, ["3.14", "3.14-dev"], kids=(1011,))         # moving tag, child 404
gone = {dg(1001), dg(1002), dg(1011)}
present = {k: v for k, v in G.items() if k not in gone}
live, sweep, info = gc.plan(V, lambda ds: {d: present.get(d, []) if d not in gone else [] for d in ds},
                            now, keep_dated=30, min_age_hours=24, missing=lambda: gone)
swept = {v["id"] for v in sweep}
assert 1000 in swept and 1003 in swept, sorted(swept)
assert 1010 not in swept, "broken moving tag must never be swept"
assert info["broken"] == ["1.1.0-r0"], info["broken"]
assert info["broken_moving"] == ["3.14,3.14-dev"], info["broken_moving"]
assert dg(1) in live and 1 not in swept
print("ghcr-gc plan test OK:", {k: info[k] for k in ("versions", "live", "sweep", "broken", "broken_moving")})
