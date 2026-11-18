import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';
import { BLOG_TAG_SLUGS } from './lib/blog-tags';

// Blog posts. `description` is the meta description as well as the card text,
// so it is required and length-checked here rather than left to drift — thin,
// near-duplicate descriptions are what made the image pages unrankable.
const blog = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/blog' }),
  schema: z.object({
    title: z.string(),
    description: z.string().min(80).max(200),
    published: z.string(),
    updated: z.string().optional(),
    draft: z.boolean().default(false),
    // Topics from src/lib/blog-tags.ts only; every post needs at least one.
    tags: z.array(z.enum(BLOG_TAG_SLUGS)).min(1),
  }),
});

export const collections = { blog };
