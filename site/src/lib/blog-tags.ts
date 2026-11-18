// Blog topics. A closed set on purpose: the content schema only accepts these
// slugs, so a typo or a one-off tag fails the build instead of minting a thin
// /blog/tag/<x>/ page with one post on it. Add a topic only when at least two
// posts belong to it.
//
// `description` is the tag page's meta description and intro, so it is held to
// the same 80-200 character range as post descriptions.
export const BLOG_TAGS = {
  'vulnerability-scanning': {
    label: 'Vulnerability scanning',
    description:
      'What a CVE scanner actually matches against, why two tools disagree about the same image, and how we tell a real finding from a scanner artefact.',
  },
  'ci-and-automation': {
    label: 'CI and automation',
    description:
      'Failures from rebuilding the whole catalog every day on automation: what broke, how we classified it, and the guardrail each incident left behind.',
  },
  'non-root-and-shell-less': {
    label: 'Non-root and shell-less containers',
    description:
      'Running images with no shell and a non-root UID: permission errors, debugging without exec, and what changes when you migrate onto them.',
  },
  'upgrades-and-migrations': {
    label: 'Upgrades and migrations',
    description:
      'Major-version upgrades and registry moves, written up from the builds where they bit us: what changed, the error it surfaced as, and the fix.',
  },
  'packaging-and-licensing': {
    label: 'Packaging and licensing',
    description:
      'How package names, dependency metadata and license fields decide what an image claims to contain, and what happens when they drift from reality.',
  },
} as const;

export type BlogTag = keyof typeof BLOG_TAGS;
export const BLOG_TAG_SLUGS = Object.keys(BLOG_TAGS) as [BlogTag, ...BlogTag[]];
