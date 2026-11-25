import type { Heading, Root } from 'mdast'
import { visit } from 'unist-util-visit'

export type HeadingDepth = Heading['depth']

/**
 * Remark plugin: the content's headings fit under the page's own (docs/LEDGER_*.md WEB-207).
 *
 * The highest level written in the content becomes `top`, the others keep their distance to it
 * (capped at h6): « ## Programme » under a post's h1 is an h2, « # Titre » too, and a page with
 * one h1 never gets a second one from its Markdown. The level each heading was written at travels
 * as `data-written`, so that the rendering keeps its size.
 */
export function remarkHeadingLevels({ top }: { top: HeadingDepth }) {
  return (tree: Root) => {
    const headings: Heading[] = []
    visit(tree, 'heading', (node: Heading) => {
      headings.push(node)
    })
    if (headings.length === 0) return
    const highest = Math.min(...headings.map((h) => h.depth))
    for (const heading of headings) {
      const written = heading.depth
      heading.depth = Math.min(written - highest + top, 6) as HeadingDepth
      heading.data = {
        ...heading.data,
        hProperties: { ...heading.data?.hProperties, 'data-written': String(written) },
      }
    }
  }
}
