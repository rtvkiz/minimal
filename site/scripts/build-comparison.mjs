// Turn the raw Grype comparison CSV into the shape the /compare pages render.
//
// The CSV is the primary artifact and ships verbatim at
// /data/cve-comparison-2026-07-24.csv so a reader can recompute every number on
// these pages. This script only reshapes it — it must never introduce a figure
// that is not derivable from that file.
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

// Use the newest dated scan, and derive the date from the filename rather than
// hard-coding it. Runs are archived rather than overwritten, so the benchmark
// is a citable series; picking the latest automatically is what stops the site
// silently continuing to render a stale one after a refresh lands.
const dataDir = join(root, 'public/data');
const scans = readdirSync(dataDir)
  .map((f) => /^cve-comparison-(\d{4}-\d{2}-\d{2})\.csv$/.exec(f))
  .filter(Boolean)
  .sort((a, b) => a[1].localeCompare(b[1]));
if (scans.length === 0) throw new Error('no cve-comparison-<date>.csv in public/data');
const [csvFile, SCAN_DATE] = [scans.at(-1)[0], scans.at(-1)[1]];
console.log(`  using ${csvFile} (${scans.length} archived run(s))`);

const csv = readFileSync(join(dataDir, csvFile), 'utf8').trim();
const [head, ...lines] = csv.split('\n');
const cols = head.split(',');
const rows = lines.map((l) => Object.fromEntries(l.split(',').map((v, i) => [cols[i], v])));

const byImage = new Map();
for (const r of rows) {
  if (!byImage.has(r.image)) byImage.set(r.image, {});
  byImage.get(r.image)[r.provider] = r;
}

// A pair only counts when BOTH providers produced a real scan. A missing
// competitor image is "not available", never "zero vulnerabilities" — treating
// an absent image as a win is the single easiest way to make a comparison
// dishonest.
function compare(rival) {
  const pairs = [];
  for (const [image, p] of byImage) {
    const a = p.minimal, b = p[rival];
    if (!a || !b || a.status !== 'scanned' || b.status !== 'scanned') continue;
    const ours = Number(a.unique_cves), theirs = Number(b.unique_cves);
    pairs.push({
      image,
      ours,
      theirs,
      delta: ours - theirs,
      oursCritical: Number(a.critical), oursHigh: Number(a.high),
      theirsCritical: Number(b.critical), theirsHigh: Number(b.high),
      oursRef: a.reference, theirsRef: b.reference,
    });
  }
  pairs.sort((x, y) => x.delta - y.delta || x.image.localeCompare(y.image));
  const lower = pairs.filter((p) => p.delta < 0).length;
  const tie = pairs.filter((p) => p.delta === 0).length;
  const higher = pairs.filter((p) => p.delta > 0).length;
  return {
    rival,
    pairs,
    compared: pairs.length,
    lower, tie, higher,
    oursTotal: pairs.reduce((s, p) => s + p.ours, 0),
    theirsTotal: pairs.reduce((s, p) => s + p.theirs, 0),
    // Images we ship that the rival had no equivalent public image for.
    rivalUnavailable: [...byImage.values()]
      .filter((p) => p.minimal?.status === 'scanned' && (!p[rival] || p[rival].status !== 'scanned')).length,
  };
}

// method-<date>.json is written by tools/cve-compare/run.sh. Fall back to the
// figures for the original hand-run scan only when it is absent, so the values
// are never silently invented for a run we cannot describe.
let method = {
  scanner: 'Grype 0.109.1',
  dbSchema: 'v6.1.9',
  dbBuilt: '2026-07-23 07:03:49 UTC',
  dbChecksum: '4089fed48894694510d7e5e2f7b9c261bc636eae459ae881f479a2e61c946046',
};
try {
  const m = JSON.parse(readFileSync(join(dataDir, `method-${SCAN_DATE}.json`), 'utf8'));
  method = {
    scanner: `Grype ${m.version}`,
    dbSchema: m.db_schema ?? method.dbSchema,
    dbBuilt: m.db_built ?? method.dbBuilt,
    dbChecksum: m.db_checksum ?? method.dbChecksum,
  };
} catch {
  if (SCAN_DATE !== '2026-07-24') {
    throw new Error(`method-${SCAN_DATE}.json missing — refusing to describe a scan we cannot verify`);
  }
}

const out = {
  scanDate: SCAN_DATE,
  ...method,
  platform: 'linux/amd64',
  csvPath: `/data/${csvFile}`,
  archivedRuns: scans.map((s) => s[1]),
  csvRows: rows.length,
  minimus: compare('minimus'),
  chainguard: compare('chainguard'),
};

writeFileSync(join(root, 'src/data/comparison.json'), JSON.stringify(out, null, 2));
console.log(
  `comparison.json — minimus ${out.minimus.compared} pairs (${out.minimus.lower}/${out.minimus.tie}/${out.minimus.higher}), ` +
  `chainguard ${out.chainguard.compared} pairs (${out.chainguard.lower}/${out.chainguard.tie}/${out.chainguard.higher})`
);
