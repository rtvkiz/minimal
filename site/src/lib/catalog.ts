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

export interface Vulnerabilities {
  counts: Record<string, number>;
  effective: Record<string, number> | null;
  fixable: number;
  total: number;
  vex: { statements: number; suppressed: string[] };
  list: Cve[];
}

export interface Pkg { name: string; version: string | null; license: string | null; }

export interface ImageRecord {
  name: string;
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
export const images = dataset.images;
export const categories = dataset.categories;

export function getImage(name: string): ImageRecord | undefined {
  return images.find((i) => i.name === name);
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
