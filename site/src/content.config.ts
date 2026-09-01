import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

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
  }),
});

export const collections = { blog };
