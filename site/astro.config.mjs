// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

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
      // The whole catalogue is rebuilt and redeployed every 6 hours, but nothing
      // external could see that. lastmod is the signal that earns a faster
      // recrawl; without it a crawler has to guess the site is worth revisiting.
      lastmod: new Date(),
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
        return item;
      },
    }),
  ],
});
