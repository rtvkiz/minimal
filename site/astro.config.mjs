// @ts-check
import { defineConfig } from 'astro/config';

// minimalcontainers.com is an apex custom domain on GitHub Pages, so the site
// is served from the root — no `base` path (unlike the old project-pages URL
// https://rtvkiz.github.io/minimal/ which needed base: '/minimal/').
export default defineConfig({
  site: 'https://minimalcontainers.com',
  trailingSlash: 'ignore',
  build: {
    format: 'directory',
  },
});
