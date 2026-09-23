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
