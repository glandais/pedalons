/**
 * `srcSet` helpers for the server's `{size}` URL templates. The size is imgproxy's bounding box
 * (`rs:fit:size:size`), so a landscape picture comes back exactly `size` pixels wide — close
 * enough for the browser to pick a candidate from its `w` descriptor. docs/LEDGER_*.md WEB-97.
 */

/** Fill a `{size}` template. */
export function sizedUrl(template: string, size: number): string {
  return template.replace('{size}', String(size))
}

/** One candidate per width, described in `w`: pair it with a `sizes` attribute. */
export function widthSrcSet(template: string, widths: readonly number[]): string {
  return widths.map((w) => `${sizedUrl(template, w)} ${w}w`).join(', ')
}

/** 1x and 2x candidates of an image rendered `size` CSS pixels on its longer side. */
export function densitySrcSet(template: string, size: number): string {
  return `${sizedUrl(template, size)} 1x, ${sizedUrl(template, size * 2)} 2x`
}

/**
 * Rendered width of a card in the lists' `SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }}`, inside the
 * layout's `Container size="lg"` (1140 px): a third of it, gaps taken, from `lg` (75em), half the
 * viewport from `sm`.
 */
export const CARD_GRID_SIZES = '(min-width: 75em) 370px, (min-width: 48em) 50vw, 100vw'

/** Candidate widths for a card header: one column on a phone, up to a 3x screen. */
export const CARD_WIDTHS = [320, 480, 800, 1200] as const
