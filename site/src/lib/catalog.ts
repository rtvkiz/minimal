// Typed accessors over the generated dataset (src/data/images.json).
// The JSON is produced by scripts/build-data.mjs before every build.
import data from '../data/images.json';

export interface Specs {
  entrypoint: string | null;
  cmd: string | null;
  env: Record<string, string>;
  user: string | null;
  uid: number | null;
  workdir: string | null;
  archs: string[];
  labels: Record<string, string>;
  packagesRequested: string[];
  exposedPorts?: string[];
  volumes?: string[];
  layers?: number | null;
  created?: string | null;
  configEnriched?: boolean;
}

export interface Variant {
  tagSuffix: string;
  pullRef: string;
  specs: Specs | null;
}

export interface Tag {
  name: string;
  created: string | null;
  digest: string | null;
}

export interface Cve {
  id: string;
  severity: string;
  package: string;
  installed: string;
  fixedIn: string | null;
  url: string | null;
  description: string | null;
}

export interface NeedsReview {
  id: string;
  package: string;
  installed: string;
  fixedIn?: string | null;
  fixed_in?: string | null;
}

export interface Vulnerabilities {
  counts: Record<string, number>;
  effective: Record<string, number> | null;
  fixable: number;
  total: number;
  /** Findings withheld as distro name-collision artefacts (see reconcile-apk-provenance.sh). */
  excluded?: number;
  /** Our own package, uncorroborated, but the fix needs a newer upstream version. */
  needsReview?: NeedsReview[];
  vex: { statements: number; suppressed: string[] };
  list: Cve[];
}

export interface Pkg { name: string; version: string | null; license: string | null; }

export interface ImageRecord {
  /** Registry identity: builds the pull ref, and never changes once published. */
  name: string;
  /** Page identity: the /images/<slug>/ URL. Defaults to `name`. */
  slug: string;
  /** Heading and title text, e.g. "Redis" for the image named redis-slim. */
  displayName: string;
  /** Per-image override for the category noun used in the <title>. */
  seoNoun: string | null;
  category: string;
  summary: string;
  /** 140-160 char per-image description from catalog.json (meta description, directory rows). */
  description?: string;
  upstreamUrl: string | null;
  primaryPackage: string | null;
  repo: string;
  variants: Record<string, Variant>;
  tags: Tag[];
  tagsStatus: string;
  size: { bytes: number; human: string } | null;
  digest: string | null;
  builtAt: string | null;
  updatedAgo: string | null;
  vulnerabilities: Vulnerabilities | null;
  packages: Pkg[] | null;
  dataStatus: {
    apko: boolean; grype: boolean; meta: boolean; sbom: boolean; config: boolean; tags: string;
  };
  degraded: boolean;
  notes: string[];
}

export interface Dataset {
  generatedAt: string;
  buildDate: string;
  commitSha: string;
  runUrl: string;
  stars?: number | null;
  registry: string;
  org: string;
  prefix: string;
  categories: string[];
  hasScanData: boolean;
  counts: { images: number; full: number; degraded: number };
  images: ImageRecord[];
}

export const dataset = data as unknown as Dataset;

/**
 * `slug`, `displayName` and `seoNoun` are newer than the committed
 * src/data/images.json seed, and that seed is what a fresh clone renders from
 * before `npm run predev` regenerates it. Defaulting them here — once — keeps a
 * stale seed rendering correctly instead of emitting /images/undefined/.
 */
export const images: ImageRecord[] = dataset.images.map((i) => ({
  ...i,
  slug: i.slug || i.name,
  displayName: i.displayName || i.name,
  seoNoun: i.seoNoun ?? null,
}));
export const categories = dataset.categories;

export function getImage(name: string): ImageRecord | undefined {
  return images.find((i) => i.name === name);
}

/**
 * The page URL for an image, given its registry `name`.
 *
 * Datasets that key on the registry name (comparison.json, bitnami-map.json)
 * must go through this rather than interpolating the name into a path, or they
 * link to /images/redis-slim/ which is now a redirect.
 */
export function imageHref(name: string): string {
  return `/images/${images.find((i) => i.name === name)?.slug || name}/`;
}

/** Images whose page URL differs from their registry name, for the redirect map. */
export function renamedImages(): { from: string; to: string }[] {
  return images
    .filter((i) => i.slug !== i.name)
    .map((i) => ({ from: `/images/${i.name}/`, to: `/images/${i.slug}/` }));
}

export function byCategory(): Record<string, ImageRecord[]> {
  const out: Record<string, ImageRecord[]> = {};
  for (const c of categories) out[c] = [];
  for (const img of images) (out[img.category] ??= []).push(img);
  return out;
}

/**
 * The first clause of an image's description — what the software is.
 *
 * catalog.json descriptions are written as meta descriptions: "<what it is>.
 * <how it is built>, signed, rebuilt daily." In a list of 158 rows the second
 * half is the same sentence 158 times, so directory rows show only the first.
 */
export function shortDescription(img: ImageRecord): string {
  const d = (img.description || img.summary || '').trim();
  const sentence = /^(.+?\S)\.\s+[A-Z]/.exec(d);
  if (sentence) return `${sentence[1]}.`;
  const clause = /^(.+?),\s*(?:built|cosign|signed|shell-less|compiled|rebuilt)\b/i.exec(d);
  if (clause) return `${clause[1]}.`;
  return d;
}

/**
 * The upstream version of an image's primary package, from its SBOM, without
 * the Wolfi epoch (-r3) or a post-release snapshot suffix (_git20261106) —
 * 3.15.2, not 3.15.2_git20261106-r0. Null when the SBOM does not name it.
 */
export function appVersion(img: ImageRecord): string | null {
  const pk = img.primaryPackage;
  const pkgs = img.packages ?? [];
  if (!pk || !pkgs.length) return null;
  const esc = pk.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const hit = pkgs.find((p) => p.name === pk)
    ?? pkgs.find((p) => new RegExp(`^${esc}[-.]?\\d`).test(p.name));
  if (!hit?.version) return null;
  return hit.version.replace(/-r\d+$/, '').replace(/_(git|p|svn|cvs|hg)\d*$/, '');
}

export function totalCves(img: ImageRecord): number {
  return img.vulnerabilities ? img.vulnerabilities.total : 0;
}

/** Aggregate a few site-wide numbers for the landing hero. */
export function siteStats() {
  const clean = images.filter((i) => dataset.hasScanData && totalCves(i) === 0).length;
  return {
    images: images.length,
    categories: categories.length,
    clean,
    hasScanData: dataset.hasScanData,
  };
}

// URL-safe slug for a category, e.g. "Kubernetes, CI & IaC" -> "kubernetes-ci-iac".
// Used for the /images/category/<slug> landing pages, which give each category a
// real indexable URL instead of a client-side filter on /images.
export function categorySlug(category: string): string {
  return category
    .toLowerCase()
    .replace(/&/g, ' ')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

export function categoryFromSlug(slug: string): string | undefined {
  return categories.find((c) => categorySlug(c) === slug);
}

/**
 * A short singular noun per category, used to vary the <title> of the 126 image
 * pages.
 *
 * All 126 titles were one template ("<name> — free hardened container image"),
 * and Google responded by rewriting them: /images/prometheus/ ships that title
 * and the SERP displays "prometheus — hardened, minimal container image", i.e.
 * it drops "free", the one word that differentiates us from Chainguard and
 * Minimus. Near-duplicate titles across a large set are a documented rewrite
 * trigger, so the noun below buys each page a distinct string.
 *
 * Unmapped categories fall back to no noun rather than a wrong one.
 */
const CATEGORY_NOUN: Record<string, string> = {
  'Languages & Runtimes': 'runtime',
  'Databases': 'database',
  'Caches, Queues & Messaging': 'messaging',
  'Web Servers & Proxies': 'web server',
  'Observability': 'observability',
  'Infrastructure': 'infrastructure',
  'Kubernetes, CI & IaC': 'Kubernetes',
  'Apps': 'app',
};

export function categoryNoun(category: string): string | undefined {
  return CATEGORY_NOUN[category];
}

/** `<display> — free hardened <noun> container image`, the per-image <title>. */
export function imageTitle(img: ImageRecord): string {
  // Per-image override first: "Caches, Queues & Messaging" holds both redis and
  // kafka, and one noun cannot be right for both.
  const noun = img.seoNoun || categoryNoun(img.category);
  return `${img.displayName} — free hardened ${noun ? `${noun} ` : ''}container image`;
}

//--- tag grouping for the Tags tab ---------------------------------------------

export interface TagRow {
  /** prod tag, e.g. "3.15"; dev is the same tag + "-dev" when published */
  tag: string;
  dev: string | null;
  kind: 'major' | 'minor' | 'latest' | 'exact';
  recommended: boolean;
}

export interface GroupedTags {
  /** Moving tags users should pick from, plus the current exact version. */
  primary: TagRow[];
  /** Dated build-history tags (<version>-YYYYMMDD), newest first. */
  history: Tag[];
  /** Superseded exact-version tags (frozen: no further security fixes). */
  older: Tag[];
}

const DATED = /-[0-9]{8}(-dev)?$/;
// Single-arch / bare-date tags the build no longer produces (swept by
// cleanup-packages.yml); never offered to users.
const LEGACY = /^[0-9]{8}(-dev)?$|-(amd64|arm64)(-dev)?$/;
const LINE = /^[0-9]+(\.[0-9]+)?$/;

function versionKey(v: string): number[] {
  return v.replace(/-dev$/, '').split(/[^0-9]+/).filter(Boolean).map(Number);
}
function cmpVersion(a: string, b: string): number {
  const x = versionKey(a), y = versionKey(b);
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    const d = (x[i] ?? -1) - (y[i] ?? -1);
    if (d) return d;
  }
  return 0;
}

/**
 * Split a flat tag list into what a user should pull vs history. The
 * recommended tag is the major line (:3) — patches without crossing a major
 * bump — or the minor line for 0.x images, where a :0 line would promise a
 * compatibility semver doesn't give (same rule as /docs/tags/).
 */
export function groupTags(tags: Tag[]): GroupedTags {
  const names = new Set(tags.map((t) => t.name));
  const usable = tags.filter((t) => !LEGACY.test(t.name));
  const prod = usable.filter((t) => !t.name.endsWith('-dev') && t.name !== 'latest-dev');
  const devOf = (n: string) => (names.has(n === 'latest' ? 'latest-dev' : `${n}-dev`) ? (n === 'latest' ? 'latest-dev' : `${n}-dev`) : null);

  const lines = prod.filter((t) => LINE.test(t.name)).map((t) => t.name);
  const majors = lines.filter((n) => !n.includes('.')).sort(cmpVersion).reverse();
  const minors = lines.filter((n) => n.includes('.')).sort(cmpVersion).reverse();
  const exact = prod.filter((t) => t.name !== 'latest' && !LINE.test(t.name) && !DATED.test(t.name));

  // Current exact version = the one sharing :latest's digest when the REST
  // API gave digests, else the highest version.
  const latestDigest = tags.find((t) => t.name === 'latest')?.digest;
  const byDigest = latestDigest ? exact.find((t) => t.digest === latestDigest) : undefined;
  const current = byDigest?.name ?? exact.map((t) => t.name).sort(cmpVersion).pop() ?? null;

  const rec = majors.find((m) => m !== '0') ?? minors[0] ?? 'latest';
  const row = (tag: string, kind: TagRow['kind']): TagRow => ({ tag, dev: devOf(tag), kind, recommended: tag === rec });
  const primary: TagRow[] = [
    ...majors.filter((m) => m !== '0').map((m) => row(m, 'major')),
    ...minors.map((m) => row(m, 'minor')),
    ...(names.has('latest') ? [row('latest', 'latest')] : []),
    ...(current ? [row(current, 'exact')] : []),
  ];

  const byNewest = (a: Tag, b: Tag) =>
    (Date.parse(b.created || '') || 0) - (Date.parse(a.created || '') || 0) || cmpVersion(b.name, a.name);
  return {
    primary,
    history: usable.filter((t) => DATED.test(t.name) && !t.name.endsWith('-dev')).sort(byNewest),
    older: exact.filter((t) => t.name !== current).sort((a, b) => cmpVersion(b.name, a.name)),
  };
}
