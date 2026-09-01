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
  integrations: [sitemap()],
});
