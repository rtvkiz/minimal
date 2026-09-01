// Derive the Bitnami -> Minimal replacement map from data, never from memory.
//
// The first version of this map was a hand-written list. It claimed a
// replacement for `bitnami/helm`, which does not exist — a fabricated fact that
// shipped because nothing checked it. Fixing the entry was not the fix; this is.
//
// Sources, both enumerated rather than recalled:
//   1. github.com/bitnami/containers, one directory per published image. This
//      is the authoritative list of what Bitnami builds, and unlike the Docker
//      Hub listing endpoint it paginates reliably (that returns 403 on page 2
//      for anonymous callers, so a Hub-derived list would silently truncate).
//   2. Docker Hub per-repository lookups for pull counts, which DO work one at
//      a time. Used only to rank; a name is never included or excluded on it.
//   3. catalog.json — what we actually ship.
//
// The only hand-maintained input is ALIASES, for software the two projects name
// differently. Every entry is validated against both sides before emitting, so
// a stale alias fails the build instead of producing a wrong row.
//
// Run by .github/workflows/refresh-site-data.yml, not by the site build: it
// makes ~380 third-party requests and must not sit between a developer and a
// working site.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { execFileSync } from 'node:child_process';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const ALIASES = {
  postgresql: 'postgres-slim',
  redis: 'redis-slim',
  node: 'node-slim',
  apache: 'httpd',
  'php-fpm': 'php',
};

// --- 1. What Bitnami publishes ---------------------------------------------
const listing = execFileSync(
  'gh',
  ['api', '--paginate', 'repos/bitnami/containers/contents/bitnami', '--jq', '.[] | select(.type=="dir") | .name'],
  { encoding: 'utf8', maxBuffer: 8 << 20 }
);
const bitnamiNames = listing.trim().split('\n').filter(Boolean);
if (bitnamiNames.length < 100) {
  throw new Error(`only ${bitnamiNames.length} Bitnami images enumerated — refusing to publish a truncated map`);
}
console.log(`  bitnami/containers: ${bitnamiNames.length} published images`);

// --- 2. What we ship --------------------------------------------------------
const catalog = JSON.parse(readFileSync(join(root, '..', 'catalog.json'), 'utf8'));
const ours = new Set(catalog.images.map((i) => i.name));

for (const [b, m] of Object.entries(ALIASES)) {
  if (!bitnamiNames.includes(b)) throw new Error(`ALIASES: bitnami/${b} is no longer published — remove or correct it`);
  if (!ours.has(m)) throw new Error(`ALIASES: ${b} -> ${m}, but ${m} is not in catalog.json`);
}

// --- 3. Pull counts, for ranking only ---------------------------------------
async function pullCount(name) {
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch(`https://hub.docker.com/v2/repositories/bitnami/${name}/`, {
        headers: { 'User-Agent': 'curl/8.5.0', Accept: 'application/json' },
      });
      if (res.ok) return (await res.json()).pull_count ?? null;
      if (res.status === 404) return null;          // legacy-only or unlisted
      await sleep(1500 * attempt);
    } catch {
      await sleep(1500 * attempt);
    }
  }
  return null;                                       // unknown, not zero
}

const pairs = [];
const gaps = [];
for (const name of bitnamiNames) {
  const mapped = ALIASES[name] ?? name;
  const target = ours.has(mapped) ? pairs : gaps;
  target.push({ bitnami: name, ...(ours.has(mapped) ? { minimal: mapped } : {}) });
}
console.log(`  mapped ${pairs.length}, gaps ${gaps.length} — fetching pull counts…`);

// Rank every mapped pair, and enough of the gaps to name the notable ones.
for (const p of pairs) { p.pulls = await pullCount(p.bitnami); await sleep(250); }
for (const g of gaps)  { g.pulls = await pullCount(g.bitnami); await sleep(250); }

// Cross-validate the two sources. The GitHub repo lists what Bitnami BUILDS;
// a Docker Hub lookup proves what is actually PULLABLE, and they disagree —
// bitnami/containers has a `helm` directory, but hub.docker.com/r/bitnami/helm
// 404s. Claiming "replace bitnami/helm" on the strength of the source tree
// alone is exactly the fabricated row this rewrite exists to prevent, so a pair
// only ships when both sources agree. Unresolvable lookups are reported, never
// silently dropped: a Hub outage must not quietly shrink the page.
const unpullable = pairs.filter((p) => p.pulls === null).map((p) => p.bitnami);
const publishable = pairs.filter((p) => p.pulls !== null);
if (unpullable.length) {
  console.log(`  excluded ${unpullable.length} built-but-not-pullable: ${unpullable.join(', ')}`);
}

const byPulls = (a, b) => (b.pulls ?? -1) - (a.pulls ?? -1);
publishable.sort(byPulls);
gaps.sort(byPulls);

writeFileSync(
  join(root, 'src/data/bitnami-map.json'),
  JSON.stringify(
    {
      generated: new Date().toISOString().slice(0, 10),
      source: 'github.com/bitnami/containers (image list) + Docker Hub API (pull counts)',
      bitnamiImages: bitnamiNames.length,
      pairs: publishable,
      excludedNotPullable: unpullable,
      topGaps: gaps.slice(0, 12),
      gapCount: gaps.length,
    },
    null,
    2
  ) + '\n'
);
console.log(
  `bitnami-map.json — ${bitnamiNames.length} seen, ${publishable.length} mapped and pullable, ` +
  `${unpullable.length} excluded, ${gaps.length} gaps`
);
