/**
 * The browser tab's title, one pure computation shared by the client (Layout and the full-screen
 * pages) and the server (`entry-server`): « Libellé · Contexte — Site » (plan 2026-11-25 D2).
 * No import and no browser global: it is reachable from SSR.
 */
export const TITLE_PART_SEPARATOR = ' · '
export const TITLE_SITE_SEPARATOR = ' — '

export interface PageTitleParts {
  label?: string
  context?: string
}

/** The non-empty parts, trimmed, joined by « · » (« Modifier · Sortie du samedi »). */
export function joinTitle(...parts: (string | undefined | null)[]): string {
  return parts
    .map((part) => part?.trim() ?? '')
    .filter(Boolean)
    .join(TITLE_PART_SEPARATOR)
}

/** « Libellé · Contexte — Site ». Never truncated, so the tab equals what the server wrote. */
export function formatPageTitle(label?: string, context?: string, siteName?: string): string {
  const site = siteName?.trim() ?? ''
  let main = label?.trim() ?? ''
  let ctx = context?.trim() ?? ''
  if (!main) {
    main = ctx
    ctx = ''
  }
  if (ctx === main || ctx === site) ctx = ''
  const head = joinTitle(main, ctx)
  if (!head) return site
  if (!site || site === head) return head
  return `${head}${TITLE_SITE_SEPARATOR}${site}`
}
