#!/usr/bin/env node
// build-data.mjs — assemble the catalog dataset the Astro site renders.
//
// Usage:
//   node scripts/build-data.mjs [reportsDir]
//
// Reads (all optional except catalog.json):
//   ../catalog.json                 source of truth: image list + metadata
//   ../<name>/apko/*.yaml           specifications (env, entrypoint, user, ...)
//   <reportsDir>/grype-<name>.json  CVE scan       (from CI artifacts)
//   <reportsDir>/meta-<name>.json   size/digest/VEX (from CI artifacts)
//   <reportsDir>/sbom-<name>.spdx.json  package closure (from CI artifacts)
//   <reportsDir>/config-<name>.json OCI image config (optional enrichment)
//   GHCR Packages/registry API      all published tags
//
// Writes:
//   src/data/images.json            one rich record per image
//
// Design: each image is assembled in its own try/catch. A missing or corrupt
// source degrades that image (recorded in `dataStatus`) but never fails the
// build. The ONLY fatal conditions are: unreadable catalog.json, or a reports
// dir that was given but yielded zero images with data (guards against
// publishing an empty catalog).

import { readFileSync, existsSync, readdirSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { parse as parseYaml } from 'yaml';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SITE_DIR = resolve(__dirname, '..');
const REPO_DIR = resolve(SITE_DIR, '..');
const REPORTS_DIR = process.argv[2] ? resolve(process.cwd(), process.argv[2]) : null;
const OUT_FILE = join(SITE_DIR, 'src', 'data', 'images.json');

const REGISTRY = 'ghcr.io';
const ORG = 'rtvkiz';
const PREFIX = 'minimal-';
const GH_TOKEN = process.env.GITHUB_TOKEN || process.env.GH_TOKEN || '';
const SKIP_TAGS = process.env.SKIP_TAGS === '1' || process.env.SKIP_TAGS === 'true';
const FETCH_TIMEOUT_MS = 8000;

const warnings = [];
function warn(msg) { warnings.push(msg); console.warn(`  ! ${msg}`); }

//--- small helpers -----------------------------------------------------------

function readJson(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

function humanBytes(b) {
  if (!b || b < 0) return null;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let i = 0, n = Number(b);
  while (n >= 1024 && i < units.length - 1) { n /= 1024; i++; }
  return `${n.toFixed(n < 10 && i > 0 ? 1 : 0)} ${units[i]}`;
}

function agoFrom(iso) {
  if (!iso) return null;
  const then = Date.parse(iso);
  if (Number.isNaN(then)) return null;
  const days = Math.floor((Date.now() - then) / 86400000);
  if (days <= 0) return 'today';
  if (days === 1) return '1 day ago';
  if (days < 30) return `${days} days ago`;
  const months = Math.floor(days / 30);
  if (months === 1) return '1 month ago';
  if (months < 12) return `${months} months ago`;
  const years = Math.floor(days / 365);
  return years === 1 ? '1 year ago' : `${years} years ago`;
}

async function fetchWithTimeout(url, opts = {}) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), FETCH_TIMEOUT_MS);
  try {
    return await fetch(url, { ...opts, signal: ctrl.signal });
  } finally {
    clearTimeout(t);
  }
}

//--- apko config -> specifications -------------------------------------------

// Locate prod/dev apko YAML for an image dir. prod = the yaml NOT ending in
// -dev.yaml; dev = the one ending in -dev.yaml. Robust to non-standard names
// (redis-slim/apko/redis.yaml, node-slim/apko/node.yaml, ...).
function findApkoConfigs(name) {
  // images/<name>/apko — #551 moved the image directories under images/ and this
  // lookup kept the old top-level path. existsSync then failed for every image,
  // so the function returned empty, every record was flagged "no apko config
  // found" and marked degraded, and all 100 image pages rendered the
  // Specifications section with no entrypoint/user/ports plus a banner saying
  // data was unavailable. It failed silently because returning empty is the
  // legitimate result for an image that genuinely has no apko config, so the
  // generator "succeeded" every run and only the deploy log hinted at it
  // ("100 images · 0 full · 100 degraded").
  const dir = join(REPO_DIR, 'images', name, 'apko');
  const out = { prod: null, dev: null };
  if (!existsSync(dir)) return out;
  for (const f of readdirSync(dir)) {
    if (!f.endsWith('.yaml')) continue;
    if (f.endsWith('-dev.yaml')) out.dev = join(dir, f);
    else if (!out.prod) out.prod = join(dir, f);
  }
  return out;
}

function specsFromApko(path) {
  const cfg = parseYaml(readFileSync(path, 'utf8')) || {};
  const contents = cfg.contents || {};
  const accounts = cfg.accounts || {};
  const users = Array.isArray(accounts.users) ? accounts.users : [];

  // entrypoint may be { command } or { services } or { type }
  let entrypoint = null;
  if (cfg.entrypoint) {
    if (typeof cfg.entrypoint === 'string') entrypoint = cfg.entrypoint;
    else if (cfg.entrypoint.command) entrypoint = cfg.entrypoint.command;
    else if (cfg.entrypoint.services) entrypoint = `services: ${Object.keys(cfg.entrypoint.services).join(', ')}`;
    else if (cfg.entrypoint.type) entrypoint = `(${cfg.entrypoint.type})`;
  }

  const uid = accounts['run-as'] ?? (users[0] && (users[0].uid ?? users[0]['uid']));
  const username = users[0] && users[0].username;

  return {
    entrypoint,
    cmd: cfg.cmd ?? null,
    env: cfg.environment && typeof cfg.environment === 'object' ? cfg.environment : {},
    user: username ? `${username}${uid != null ? ` (${uid})` : ''}` : (uid != null ? String(uid) : null),
    uid: uid != null ? Number(uid) : null,
    workdir: cfg['work-dir'] ?? null,
    archs: Array.isArray(cfg.archs) ? cfg.archs : [],
    labels: cfg.annotations && typeof cfg.annotations === 'object' ? cfg.annotations : {},
    packagesRequested: Array.isArray(contents.packages) ? contents.packages : [],
  };
}

// Optional OCI image-config enrichment: exposed ports, volumes, layers, created.
function enrichFromConfig(specs, name) {
  if (!REPORTS_DIR) return specs;
  const p = join(REPORTS_DIR, `config-${name}.json`);
  if (!existsSync(p)) return specs;
  try {
    const cfg = readJson(p);
    const c = cfg.config || {};
    return {
      ...specs,
      exposedPorts: c.ExposedPorts ? Object.keys(c.ExposedPorts) : [],
      volumes: c.Volumes ? Object.keys(c.Volumes) : [],
      layers: Array.isArray(cfg.history) ? cfg.history.length : null,
      created: cfg.created || null,
      configEnriched: true,
    };
  } catch (e) {
    warn(`config-${name}.json unreadable: ${e.message}`);
    return specs;
  }
}

//--- reports: grype / meta / sbom --------------------------------------------

const SEV = ['Critical', 'High', 'Medium', 'Low', 'Negligible', 'Unknown'];

// `excluded` is the (package, id) set the provenance reconciliation decided is
// not present in the image — our own package name matched against Wolfi's
// advisory feed, where their -rN rebuild counter is compared against our -r0.
// The pairs come from meta-<name>.json rather than being re-derived here, so
// the rule lives in exactly one place (.github/scripts/reconcile-apk-provenance.sh)
// and the site cannot drift from what the dashboard and job summary report.
function readGrype(name, excludedPairs) {
  if (!REPORTS_DIR) return null;
  const p = join(REPORTS_DIR, `grype-${name}.json`);
  if (!existsSync(p)) return null;
  const doc = readJson(p);
  const matches = Array.isArray(doc.matches) ? doc.matches : [];
  const excluded = new Set((excludedPairs || []).map((e) => `${e.package}\u0000${e.id}`));
  const counts = { critical: 0, high: 0, medium: 0, low: 0, negligible: 0, unknown: 0 };
  let fixable = 0;
  let excludedCount = 0;
  const list = [];
  for (const m of matches) {
    const v = m.vulnerability || {};
    const a = m.artifact || {};
    // Not shown and not counted, but tallied so the exclusion stays auditable.
    if (excluded.has(`${a.name || ''}\u0000${v.id || ''}`)) { excludedCount++; continue; }
    const sev = String(v.severity || 'Unknown');
    const key = sev.toLowerCase();
    if (key in counts) counts[key]++;
    const fixVersions = (v.fix && Array.isArray(v.fix.versions)) ? v.fix.versions : [];
    if (fixVersions.length > 0) fixable++;
    list.push({
      id: v.id || 'UNKNOWN',
      severity: SEV.find((s) => s.toLowerCase() === key) || 'Unknown',
      package: a.name || '',
      installed: a.version || '',
      fixedIn: fixVersions[0] || null,
      url: v.dataSource || null,
      description: (v.description || '').slice(0, 300) || null,
    });
  }
  const order = { Critical: 0, High: 1, Medium: 2, Low: 3, Negligible: 4, Unknown: 5 };
  list.sort((x, y) => (order[x.severity] - order[y.severity]) || x.id.localeCompare(y.id));
  return { counts, fixable, total: list.length, excluded: excludedCount, list };
}

function readMeta(name) {
  if (!REPORTS_DIR) return null;
  const p = join(REPORTS_DIR, `meta-${name}.json`);
  if (!existsSync(p)) return null;
  const m = readJson(p);
  return {
    sizeBytes: m.size_bytes ?? null,
    sizeHuman: humanBytes(m.size_bytes),
    digest: m.digest || null,
    builtAt: m.built_at || null,
    raw: m.raw || null,
    effective: m.effective || null,
    provenance: m.provenance || null,
    vex: m.vex || { statements: 0, suppressed: [] },
  };
}

function readSbom(name) {
  if (!REPORTS_DIR) return null;
  const p = join(REPORTS_DIR, `sbom-${name}.spdx.json`);
  if (!existsSync(p)) return null;
  const doc = readJson(p);
  const pkgs = Array.isArray(doc.packages) ? doc.packages : [];
  const out = [];
  for (const pk of pkgs) {
    const name = pk.name;
    if (!name || name === doc.name) continue; // skip the root document package
    const lic = pk.licenseDeclared && pk.licenseDeclared !== 'NOASSERTION'
      ? pk.licenseDeclared
      : (pk.licenseConcluded && pk.licenseConcluded !== 'NOASSERTION' ? pk.licenseConcluded : null);
    out.push({ name, version: pk.versionInfo || null, license: lic });
  }
  out.sort((a, b) => a.name.localeCompare(b.name));
  return out;
}

//--- GHCR tags ---------------------------------------------------------------

// cosign publishes signature/attestation/sbom artifacts as sibling tags
// (`sha256-<hex>.sig`, `.att`, `.sbom`, or bare `sha256-<hex>`). Those are not
// pullable image tags, so exclude them from the catalog's tag list.
function isMeaningfulTag(tag) {
  if (!tag) return false;
  if (/^sha256[-:]/.test(tag)) return false;
  if (/\.(sig|att|sbom)$/.test(tag)) return false;
  return true;
}

// Best-effort list of all published tags. Prefers the GitHub Packages REST API
// (tags + created timestamps) when a token is available; otherwise falls back
// to the anonymous registry v2 tags/list (names only). Any failure returns a
// synthesized ["latest"] with status 'partial'.
async function fetchTags(imageName, fallbacks) {
  const pkg = `${PREFIX}${imageName}`;
  const synth = () => ({
    status: 'partial',
    tags: [...new Set(['latest', ...fallbacks].filter(Boolean))].map((t) => ({ name: t, created: null, digest: null })),
  });
  if (SKIP_TAGS) return { status: 'none', tags: synth().tags };

  // 1) GitHub Packages REST API (needs read:packages)
  if (GH_TOKEN) {
    try {
      const all = [];
      for (let page = 1; page <= 10; page++) {
        const res = await fetchWithTimeout(
          `https://api.github.com/users/${ORG}/packages/container/${encodeURIComponent(pkg)}/versions?per_page=100&page=${page}`,
          { headers: { Authorization: `Bearer ${GH_TOKEN}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' } }
        );
        if (!res.ok) throw new Error(`REST ${res.status}`);
        const versions = await res.json();
        if (!Array.isArray(versions) || versions.length === 0) break;
        for (const v of versions) {
          const meta = v.metadata && v.metadata.container;
          const tags = (meta && Array.isArray(meta.tags)) ? meta.tags : [];
          for (const t of tags) {
            if (!isMeaningfulTag(t)) continue;
            all.push({ name: t, created: v.updated_at || v.created_at || null, digest: v.name || null });
          }
        }
        if (versions.length < 100) break;
      }
      if (all.length) {
        all.sort((a, b) => (Date.parse(b.created || 0) - Date.parse(a.created || 0)) || a.name.localeCompare(b.name));
        return { status: 'full', tags: all };
      }
    } catch (e) {
      warn(`tags(${pkg}) REST API failed: ${e.message}; trying anonymous registry`);
    }
  }

  // 2) Anonymous registry v2 tags/list (names only)
  try {
    const tokRes = await fetchWithTimeout(
      `https://${REGISTRY}/token?scope=repository:${ORG}/${pkg}:pull&service=${REGISTRY}`
    );
    if (!tokRes.ok) throw new Error(`token ${tokRes.status}`);
    const { token } = await tokRes.json();
    const res = await fetchWithTimeout(`https://${REGISTRY}/v2/${ORG}/${pkg}/tags/list`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) throw new Error(`tags/list ${res.status}`);
    const body = await res.json();
    const names = (Array.isArray(body.tags) ? body.tags : []).filter(isMeaningfulTag);
    if (names.length) {
      // tags/list is paginated & alphabetical; page 1 may miss tags when cosign
      // artifacts crowd the list, so flag as partial unless clearly small.
      const status = names.length < 100 ? 'full' : 'partial';
      return { status, tags: names.sort().map((t) => ({ name: t, created: null, digest: null })) };
    }
  } catch (e) {
    warn(`tags(${pkg}) registry fallback failed: ${e.message}`);
  }

  return synth();
}

//--- assemble ----------------------------------------------------------------

async function buildImage(entry) {
  const { name } = entry;
  const record = {
    name,
    category: entry.category,
    summary: entry.summary || '',
    // Distinct 140-160 char meta description. `summary` is the short card line
    // and is near-identical in shape across the catalogue, so it cannot carry
    // the meta description on its own without reading as duplicate boilerplate.
    // Enforced by scripts/check-catalog-descriptions.sh.
    description: entry.description || '',
    upstreamUrl: entry.upstream_url || null,
    primaryPackage: entry.primary_package || null,
    repo: `${REGISTRY}/${ORG}/${PREFIX}${name}`,
    variants: {},
    tags: [],
    tagsStatus: 'none',
    size: null,
    digest: null,
    builtAt: null,
    updatedAgo: null,
    vulnerabilities: null,
    packages: null,
    dataStatus: { apko: false, grype: false, meta: false, sbom: false, config: false, tags: 'none' },
    degraded: false,
    notes: [],
  };

  // Specifications from apko (prod + dev)
  const apko = findApkoConfigs(name);
  for (const variant of entry.variants || ['prod']) {
    const path = variant === 'dev' ? apko.dev : apko.prod;
    const tagSuffix = variant === 'dev' ? '-dev' : '';
    let specs = null;
    if (path) {
      try {
        specs = enrichFromConfig(specsFromApko(path), name);
        record.dataStatus.apko = true;
        if (specs.configEnriched) record.dataStatus.config = true;
      } catch (e) {
        record.notes.push(`apko ${variant} parse failed: ${e.message}`);
      }
    }
    record.variants[variant] = {
      tagSuffix,
      pullRef: `${record.repo}:latest${tagSuffix}`,
      specs,
    };
  }
  if (!record.dataStatus.apko) record.notes.push('no apko config found');

  // Reports (prod scan drives the headline numbers)
  const meta = tryOr(() => readMeta(name), (e) => record.notes.push(`meta: ${e.message}`));
  const excludedPairs = (meta && meta.provenance && meta.provenance.excluded_pairs) || [];
  const grype = tryOr(() => readGrype(name, excludedPairs), (e) => record.notes.push(`grype: ${e.message}`));
  const sbom = tryOr(() => readSbom(name), (e) => record.notes.push(`sbom: ${e.message}`));

  if (meta) {
    record.dataStatus.meta = true;
    record.size = meta.sizeBytes != null ? { bytes: meta.sizeBytes, human: meta.sizeHuman } : null;
    record.digest = meta.digest;
    record.builtAt = meta.builtAt;
    record.updatedAgo = agoFrom(meta.builtAt);
  }
  if (grype) {
    record.dataStatus.grype = true;
    record.vulnerabilities = {
      counts: grype.counts,
      effective: meta && meta.effective ? meta.effective : null,
      fixable: grype.fixable,
      total: grype.total,
      excluded: grype.excluded,
      needsReview: (meta && meta.provenance && meta.provenance.needs_review) || [],
      vex: meta ? meta.vex : { statements: 0, suppressed: [] },
      list: grype.list,
    };
  }
  if (sbom) {
    record.dataStatus.sbom = true;
    record.packages = sbom;
  }

  // Tags (fallbacks: version tag if we can guess, plus latest/-dev)
  const fallbacks = ['latest', ...(record.variants.dev ? ['latest-dev'] : [])];
  const tagInfo = await fetchTags(name, fallbacks);
  record.tags = tagInfo.tags;
  record.tagsStatus = tagInfo.status;
  record.dataStatus.tags = tagInfo.status;

  record.degraded = !record.dataStatus.apko || (REPORTS_DIR && (!record.dataStatus.grype || !record.dataStatus.meta));
  return record;
}

function tryOr(fn, onErr) {
  try { return fn(); } catch (e) { onErr(e); return null; }
}

//--- main --------------------------------------------------------------------

async function main() {
  let catalog;
  try {
    catalog = readJson(join(REPO_DIR, 'catalog.json'));
  } catch (e) {
    console.error(`FATAL: cannot read catalog.json: ${e.message}`);
    process.exit(1);
  }
  const images = Array.isArray(catalog.images) ? catalog.images : [];
  if (images.length === 0) {
    console.error('FATAL: catalog.json has no images');
    process.exit(1);
  }

  console.log(`Building catalog: ${images.length} images${REPORTS_DIR ? ` (reports: ${REPORTS_DIR})` : ' (no reports — metadata + specs + tags only)'}`);

  const records = [];
  for (const entry of images) {
    try {
      records.push(await buildImage(entry));
    } catch (e) {
      // Last-resort isolation: never let one image kill the whole build.
      warn(`image "${entry.name}" failed hard: ${e.message}`);
      records.push({
        name: entry.name, category: entry.category, summary: entry.summary || '',
        description: entry.description || '',
        repo: `${REGISTRY}/${ORG}/${PREFIX}${entry.name}`, variants: {}, tags: [],
        dataStatus: { apko: false, grype: false, meta: false, sbom: false, config: false, tags: 'none' },
        degraded: true, notes: [`assembly failed: ${e.message}`],
      });
    }
  }

  // Fatal guard: reports dir given but nothing landed -> refuse to publish empty.
  if (REPORTS_DIR) {
    const withScan = records.filter((r) => r.dataStatus.grype).length;
    if (withScan === 0) {
      console.error('FATAL: reports dir was provided but zero images have scan data — refusing to publish an empty catalog');
      process.exit(1);
    }
  }

  const full = records.filter((r) => !r.degraded).length;
  const degraded = records.filter((r) => r.degraded);
  const out = {
    generatedAt: new Date().toISOString(),
    buildDate: process.env.BUILD_DATE || new Date().toISOString().replace('T', ' ').slice(0, 16) + ' UTC',
    commitSha: process.env.COMMIT_SHA || '',
    runUrl: process.env.RUN_URL || '',
    registry: REGISTRY,
    org: ORG,
    prefix: PREFIX,
    categories: catalog.categories || [],
    hasScanData: records.some((r) => r.dataStatus.grype),
    counts: {
      images: records.length,
      full,
      degraded: degraded.length,
    },
    images: records,
  };

  mkdirSync(dirname(OUT_FILE), { recursive: true });
  writeFileSync(OUT_FILE, JSON.stringify(out, null, 2));

  console.log(`\nWrote ${OUT_FILE}`);
  console.log(`  ${records.length} images · ${full} full · ${degraded.length} degraded`);
  if (degraded.length) {
    console.log('  degraded: ' + degraded.map((r) => `${r.name} (${r.notes.join('; ') || 'partial'})`).join(', '));
  }

  // GitHub Actions job summary (if running in CI)
  if (process.env.GITHUB_STEP_SUMMARY) {
    const lines = [
      '### Catalog data build',
      '',
      `- Images: **${records.length}**`,
      `- Full data: **${full}**`,
      `- Degraded: **${degraded.length}**`,
    ];
    if (degraded.length) {
      lines.push('', '| Image | Missing |', '|---|---|');
      for (const r of degraded) lines.push(`| ${r.name} | ${r.notes.join('; ') || 'partial'} |`);
    }
    if (warnings.length) {
      lines.push('', `<details><summary>${warnings.length} warnings</summary>`, '', ...warnings.map((w) => `- ${w}`), '', '</details>');
    }
    try { writeFileSync(process.env.GITHUB_STEP_SUMMARY, lines.join('\n') + '\n', { flag: 'a' }); } catch { /* noop */ }
  }
}

main().catch((e) => {
  console.error(`FATAL: ${e.stack || e.message}`);
  process.exit(1);
});
