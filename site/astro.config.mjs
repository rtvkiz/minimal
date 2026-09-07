// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import { execFileSync } from 'node:child_process';
import { readFileSync, readdirSync } from 'node:fs';

// --- lastmod ------------------------------------------------------------
// Every URL used to carry `lastmod: new Date()`, i.e. build time. The site
// redeploys every 6 hours, so all 139 pages claimed to change every 6 hours —
// including /about/ and blog posts published weeks earlier, which demonstrably
// had not. Google only honours lastmod while it stays accurate; a sitemap that
// marks everything fresh on every crawl teaches it the field is noise, and the
// recrawl priority that lastmod was added to earn is exactly what gets lost.
//
// So each page now reports a date it can actually justify, and any page we
// cannot date truthfully reports none at all (an absent lastmod is fine;
// a wrong one is not).
const iso = (d) => new Date(d).toISOString();

// Source-file commit date, for hand-written pages. Falls back to undefined so
// a shallow clone or a missing git just omits lastmod rather than inventing one.
const gitDate = (file) => {
  try {
    const out = execFileSync('git', ['log', '-1', '--format=%cI', '--', file], {
      encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    return out ? iso(out) : undefined;
  } catch {
    return undefined;
  }
};

// Blog posts carry their own dates in frontmatter — the most honest source there is.
const blogDates = (() => {
  const map = new Map();
  try {
    for (const f of readdirSync('./src/content/blog').filter((f) => f.endsWith('.md'))) {
      const fm = readFileSync(`./src/content/blog/${f}`, 'utf8').split('---')[1] ?? '';
      const pub = /^published:\s*"?([0-9-]+)"?/m.exec(fm)?.[1];
      const upd = /^updated:\s*"?([0-9-]+)"?/m.exec(fm)?.[1];
      if (pub) map.set(`/blog/${f.replace(/\.md$/, '')}/`, iso(`${upd ?? pub}T00:00:00Z`));
    }
  } catch { /* no posts yet */ }
  return map;
})();

// Image pages genuinely do change on a rebuild: new digest, new size, and
// often new vulnerability counts. builtAt is per-image and real, so it is a
// truthful lastmod here in a way a global build timestamp never was.
const imageDates = (() => {
  const map = new Map();
  try {
    const raw = JSON.parse(readFileSync('./src/data/images.json', 'utf8'));
    for (const img of (Array.isArray(raw) ? raw : raw.images ?? [])) {
      if (img?.name && img?.builtAt) map.set(`/images/${img.name}/`, iso(img.builtAt));
    }
  } catch { /* data not generated yet */ }
  return map;
})();

const newest = (m) => {
  const v = [...m.values()].sort();
  return v.length ? v[v.length - 1] : undefined;
};

const lastmodFor = (pathname) => {
  if (blogDates.has(pathname)) return blogDates.get(pathname);
  if (imageDates.has(pathname)) return imageDates.get(pathname);
  // Index pages are as fresh as the newest thing they list.
  if (pathname === '/blog/') return newest(blogDates);
  if (pathname === '/images/' || pathname.startsWith('/images/category/')) return newest(imageDates);
  if (pathname === '/') return newest(imageDates) ?? gitDate('src/pages/index.astro');
  // Hand-written pages: the commit that last touched their source.
  const file = pathname === '/' ? 'src/pages/index.astro'
    : `src/pages${pathname.replace(/\/$/, '')}.astro`;
  return gitDate(file) ?? gitDate(`src/pages${pathname}index.astro`);
};

// minimalcontainers.com is an apex custom domain on GitHub Pages, so the site
// is served from the root — no `base` path (unlike the old project-pages URL
// https://rtvkiz.github.io/minimal/ which needed base: '/minimal/').
export default defineConfig({
  site: 'https://minimalcontainers.com',
  trailingSlash: 'ignore',
  build: {
    format: 'directory',
  },
  // Without a sitemap the catalogue's ~110 image pages are reachable only by
  // crawling /images. `site` above is what makes the emitted URLs absolute.
  integrations: [
    sitemap({
      serialize(item) {
        // Priority ordering, highest intent first: the comparison pages exist to
        // catch "<vendor> alternative" queries, and the catalogue root is the
        // main entry point. Leaf image pages are the long tail.
        const p = new URL(item.url).pathname;
        if (p === '/') item.priority = 1.0;
        else if (p.startsWith('/compare')) item.priority = 0.9;
        else if (p === '/images/' || p.startsWith('/images/category/')) item.priority = 0.8;
        else if (p.startsWith('/blog')) item.priority = 0.7;
        else if (p.startsWith('/docs') || p === '/about/') item.priority = 0.6;
        else item.priority = 0.5;
        item.changefreq = p.startsWith('/images/') ? 'daily' : 'weekly';
        // Truthful per-page date, or none. See the lastmod note at the top.
        const lm = lastmodFor(p);
        if (lm) item.lastmod = lm; else delete item.lastmod;
        return item;
      },
    }),
  ],
});
