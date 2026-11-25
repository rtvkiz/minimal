#!/usr/bin/env python3
"""Mark-and-sweep garbage collection for the minimal-* GHCR packages.

Why mark-and-sweep and not "delete untagged": GHCR stores every per-arch
manifest of a multi-arch image as its own *untagged* package version, and the
cosign/attest referrer indexes (tag sha256-<digest>) point at untagged
attestation manifests too. Deleting untagged versions therefore breaks every
multi-arch image and strips its signatures. Instead:

  roots  = versions carrying a tag users pull (latest, <version>, line tags)
           + the newest KEEP_DATED pure dated builds per variant (<version>-YYYYMMDD[-dev])
  live   = roots + every manifest reachable from them (index children)
           + every signature/attestation whose subject is live (and their
           children), iterated to a fixed point
  sweep  = every version not in live and older than MIN_AGE_HOURS

Legacy tags no build produces any more (bare YYYYMMDD dates, -amd64/-arm64
single-arch tags) are not roots: a version held only by them is swept.

The REST API is rate limited (~1000 req/h for GITHUB_TOKEN), and the first
pass has a large backlog, so every run is budgeted and resumable: it stops
deleting when the remaining rate limit falls below RATE_FLOOR or MAX_DELETES
is reached, and the next run picks up where it left off (reconcile, don't
batch). Graph reads go to the registry (ghcr.io/v2), which is not REST-limited.

Modes: report (log only, the default) | apply (delete). Exit 1 in either mode
if a safety check fails, so a broken run is red rather than silently partial.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

OWNER = os.environ.get("OWNER", "rtvkiz")
PREFIX = "minimal-"
MODE = os.environ.get("MODE", "report")
KEEP_DATED = int(os.environ.get("KEEP_DATED", "30"))
MIN_AGE_HOURS = float(os.environ.get("MIN_AGE_HOURS", "24"))
MAX_DELETES = int(os.environ.get("MAX_DELETES", "700"))
RATE_FLOOR = int(os.environ.get("RATE_FLOOR", "150"))
TOKEN = os.environ.get("GH_TOKEN", "")

ARTIFACT_RE = re.compile(r"^sha256-([0-9a-f]{64})(\.(sig|att|sbom))?$")
DATED_RE = re.compile(r"-[0-9]{8}(-dev)?$")
LEGACY_RE = re.compile(r"^[0-9]{8}(-dev)?$|-(amd64|arm64)(-dev)?$")
INDEX_TYPES = (
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
)
ACCEPT = ",".join(INDEX_TYPES + (
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.docker.distribution.manifest.v2+json",
))


def classify(tag):
    """artifact | legacy | dated | root"""
    if ARTIFACT_RE.match(tag):
        return "artifact"
    if LEGACY_RE.search(tag):
        return "legacy"
    if DATED_RE.search(tag):
        return "dated"
    return "root"


def plan(versions, children_many, now, keep_dated=KEEP_DATED, min_age_hours=MIN_AGE_HOURS):
    """Pure function: decide what to keep. Returns (live_digests, sweep_versions, info).

    versions: [{id, digest, tags, created(datetime)}]
    children_many(digests) -> {digest: [child digests]} (one level, may fetch in parallel)
    """
    by_digest = {v["digest"]: v for v in versions}
    roots, dated = [], []
    for v in versions:
        kinds = {classify(t) for t in v["tags"]}
        if "root" in kinds:
            roots.append(v)
        elif "dated" in kinds:
            dated.append(v)
    # KEEP_DATED per variant: prod and -dev builds each keep their own history,
    # otherwise dev rebuilds would halve the prod history.
    for is_dev in (False, True):
        group = [v for v in dated if any(t.endswith("-dev") for t in v["tags"]) == is_dev]
        group.sort(key=lambda v: v["created"], reverse=True)
        roots += group[:keep_dated]

    # Subject digest -> artifact versions attached to it.
    artifacts = {}
    for v in versions:
        for t in v["tags"]:
            m = ARTIFACT_RE.match(t)
            if m:
                artifacts.setdefault("sha256:" + m.group(1), []).append(v)

    # Breadth-first so each level's manifests can be fetched in parallel.
    live, frontier = set(), {v["digest"] for v in roots}
    while frontier:
        live |= frontier
        kids = children_many(sorted(frontier))
        nxt = set()
        for d in frontier:
            nxt.update(kids.get(d, []))
            nxt.update(a["digest"] for a in artifacts.get(d, []))
        frontier = nxt - live

    cutoff = min_age_hours * 3600
    sweep = [v for v in versions
             if v["digest"] not in live and (now - v["created"]).total_seconds() > cutoff]
    info = {
        "versions": len(versions),
        "roots": len(roots),
        "dated_total": len(dated),
        "live": len(live & set(by_digest)),
        "sweep": len(sweep),
        "has_latest": any("latest" in v["tags"] for v in roots),
    }
    return live, sweep, info


# --- I/O -----------------------------------------------------------------------

rate_remaining = None


def rest(method, path):
    global rate_remaining
    req = urllib.request.Request(
        "https://api.github.com" + path, method=method,
        headers={"Authorization": f"Bearer {TOKEN}", "Accept": "application/vnd.github+json",
                 "X-GitHub-Api-Version": "2022-11-28"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                rate_remaining = int(r.headers.get("X-RateLimit-Remaining", rate_remaining or 0))
                body = r.read()
                return r.status, (json.loads(body) if body else None)
        except urllib.error.HTTPError as e:
            rate_remaining = int(e.headers.get("X-RateLimit-Remaining", rate_remaining or 0))
            if e.code in (500, 502, 503, 504) and attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            try:
                msg = json.loads(e.read() or b"{}").get("message", "")
            except ValueError:
                msg = ""
            return e.code, {"message": msg}
        except (urllib.error.URLError, TimeoutError):
            if attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            raise
    return 599, None


def list_versions(pkg):
    out, page = [], 1
    while True:
        status, body = rest("GET", f"/users/{OWNER}/packages/container/{pkg}/versions?per_page=100&page={page}")
        if status != 200:
            raise RuntimeError(f"list versions HTTP {status}: {(body or {}).get('message', '')}")
        for v in body:
            out.append({
                "id": v["id"],
                "digest": v["name"],
                "tags": (v.get("metadata", {}).get("container", {}) or {}).get("tags") or [],
                "created": datetime.fromisoformat(v["created_at"].replace("Z", "+00:00")),
            })
        if len(body) < 100:
            return out
        page += 1


class Registry:
    """Anonymous pull access to ghcr.io/v2 for one repo (packages are public)."""

    def __init__(self, repo):
        self.repo = repo
        q = urllib.parse.urlencode({"scope": f"repository:{repo}:pull", "service": "ghcr.io"})
        with urllib.request.urlopen(f"https://ghcr.io/token?{q}", timeout=30) as r:
            self.token = json.load(r)["token"]
        self.cache = {}
        self.missing = set()  # digests the registry 404'd while walking

    def manifest(self, ref):
        req = urllib.request.Request(
            f"https://ghcr.io/v2/{self.repo}/manifests/{ref}",
            headers={"Authorization": f"Bearer {self.token}", "Accept": ACCEPT})
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=30) as r:
                    return r.headers.get("Content-Type", ""), json.load(r)
            except urllib.error.HTTPError as e:
                if e.code == 404:
                    return None, None
                if attempt == 3:
                    raise
            except (urllib.error.URLError, TimeoutError):
                if attempt == 3:
                    raise
            time.sleep(3 * (attempt + 1))

    def children(self, digest):
        if digest not in self.cache:
            ctype, body = self.manifest(digest)
            if body is None:
                self.missing.add(digest)
            kids = []
            if body and (ctype in INDEX_TYPES or body.get("mediaType") in INDEX_TYPES):
                kids = [m["digest"] for m in body.get("manifests", [])]
            self.cache[digest] = kids
        return self.cache[digest]

    def children_many(self, digests, workers=16):
        todo = [d for d in digests if d not in self.cache]
        with ThreadPoolExecutor(max_workers=workers) as ex:
            list(ex.map(self.children, todo))
        return {d: self.cache[d] for d in digests}

    def pullable(self, ref):
        """Tag resolves and every child manifest it lists resolves too."""
        ctype, body = self.manifest(ref)
        if not body:
            return False
        if ctype in INDEX_TYPES or body.get("mediaType") in INDEX_TYPES:
            return all(self.manifest(m["digest"])[1] for m in body.get("manifests", []))
        return True


def main(names):
    if MODE not in ("report", "apply"):
        sys.exit(f"MODE must be report or apply, got {MODE!r}")
    if not TOKEN:
        sys.exit("GH_TOKEN is required")
    now = datetime.now(timezone.utc)
    # Rotate the start so a budget-limited run doesn't always spend it on the
    # same images: the backlog drains evenly across runs.
    offset = int(os.environ.get("ROTATE", "0")) % max(len(names), 1)
    names = names[offset:] + names[:offset]
    print(f"MODE={MODE} KEEP_DATED={KEEP_DATED} MIN_AGE_HOURS={MIN_AGE_HOURS} "
          f"MAX_DELETES={MAX_DELETES} RATE_FLOOR={RATE_FLOOR} start={names[0] if names else '-'}")

    deleted = failed = pending = 0
    problems = []
    budget_hit = False
    for name in names:
        pkg = PREFIX + name
        if rate_remaining is not None and rate_remaining < RATE_FLOOR:
            budget_hit = True
            print(f"── stop: REST rate limit remaining {rate_remaining} < {RATE_FLOOR}; next run resumes")
            break
        try:
            versions = list_versions(pkg)
        except Exception as e:  # noqa: BLE001 — one package must not stop the sweep
            if rate_remaining == 0:
                budget_hit = True
                print(f"── stop: REST rate limit exhausted at {pkg} ({e}); next run resumes")
                break
            print(f"── {pkg}: skipped ({e})")
            continue
        if not versions:
            continue
        try:
            reg = Registry(f"{OWNER}/{pkg}")
            live, sweep, info = plan(versions, reg.children_many, now)
        except Exception as e:  # noqa: BLE001 — a failed walk must delete nothing
            problems.append(f"{pkg}: graph walk failed ({e}) — skipped, nothing deleted")
            print(f"── {pkg}: SKIP (walk failed: {e})")
            continue
        # An under-marked graph would sweep live per-arch manifests, so any
        # live digest the registry couldn't serve aborts this image.
        unreadable = reg.missing & live
        if unreadable:
            problems.append(f"{pkg}: {len(unreadable)} live manifest(s) unreadable — skipped, nothing deleted")
            print(f"── {pkg}: SKIP ({len(unreadable)} live manifests unreadable)")
            continue

        # Safety: never sweep an image whose roots don't include :latest, and
        # never sweep anything if the plan would leave :latest unpullable.
        if not info["has_latest"]:
            problems.append(f"{pkg}: no :latest among roots — skipped, nothing deleted")
            print(f"── {pkg}: SKIP (no :latest root) {info}")
            continue
        print(f"── {pkg}: {info['versions']} versions, keep {info['live']}, "
              f"sweep {info['sweep']} (dated builds {info['dated_total']} → keep {min(KEEP_DATED, info['dated_total'])})")
        for v in sweep:
            label = ",".join(v["tags"]) or "untagged"
            if MODE == "report" or budget_hit:
                pending += 1
                continue
            if deleted >= MAX_DELETES or (rate_remaining is not None and rate_remaining < RATE_FLOOR):
                budget_hit = True
                pending += 1
                continue
            status, body = rest("DELETE", f"/users/{OWNER}/packages/container/{pkg}/versions/{v['id']}")
            if status in (200, 204):
                deleted += 1
            else:
                failed += 1
                print(f"   ! delete {v['digest'][:19]} ({label}) HTTP {status}: {(body or {}).get('message', '')}")
        if MODE == "apply" and sweep and not reg.pullable("latest"):
            problems.append(f"{pkg}: :latest NOT pullable after sweep")

    print(f"\nDone. MODE={MODE} deleted={deleted} failed={failed} pending={pending} "
          f"rate_remaining={rate_remaining} budget_hit={budget_hit}")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write(f"### GHCR sweep ({MODE})\n\n| deleted | failed | pending | rate left |\n|---|---|---|---|\n"
                    f"| {deleted} | {failed} | {pending} | {rate_remaining} |\n")
            for p in problems:
                f.write(f"\n- ⚠️ {p}")
    for p in problems:
        print(f"::error::{p}")
    if problems or (failed and failed >= max(deleted, 1)):
        sys.exit(1)


if __name__ == "__main__":
    main(sys.argv[1:])
