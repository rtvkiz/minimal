import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';

// A feed is also a freshness signal: the catalogue rebuilds every 6h but
// nothing external could see that the site was alive.
export async function GET(context) {
  const posts = (await getCollection('blog', ({ data }) => !data.draft))
    .sort((a, b) => b.data.published.localeCompare(a.data.published));

  return rss({
    title: 'Minimal Containers',
    description: 'Migration guides and published scan data for free, hardened container images.',
    site: context.site,
    items: posts.map((p) => ({
      title: p.data.title,
      description: p.data.description,
      pubDate: new Date(p.data.published + 'T00:00:00Z'),
      link: `/blog/${p.id}/`,
    })),
  });
}
