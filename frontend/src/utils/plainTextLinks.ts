/**
 * A comment's text cut into plain runs and full web addresses (decision of 2026-11-12, KIT §9):
 * the text stays raw — no markdown, no HTML, no bare « www. » or e-mail guessing — and only an
 * address written with its `http://` or `https://` becomes a link, shown in full. A pure function
 * of the text, so the server and the browser render the same markup.
 */
export type PlainTextPart = { kind: 'text'; text: string } | { kind: 'link'; href: string }

// Up to the next whitespace or a character that cannot end an address in running text.
const ADDRESS = /https?:\/\/[^\s<>"'«»]+/gi
// Punctuation that closes the sentence rather than the address: « voir https://x.fr/a. »
const TRAILING = /[.,;:!?…]+$/

/** Drops trailing punctuation, and a closing bracket the address did not open. */
function trimAddress(candidate: string): string {
  let address = candidate
  for (;;) {
    const before = address
    address = address.replace(TRAILING, '')
    for (const [open, close] of [
      ['(', ')'],
      ['[', ']'],
    ] as const) {
      if (address.endsWith(close)) {
        const opened = address.split(open).length - 1
        const closed = address.split(close).length - 1
        if (closed > opened) address = address.slice(0, -1)
      }
    }
    if (address === before) return address
  }
}

export function splitPlainTextLinks(text: string): PlainTextPart[] {
  const parts: PlainTextPart[] = []
  let last = 0
  for (const match of text.matchAll(ADDRESS)) {
    const href = trimAddress(match[0])
    // « https:// » alone is not an address.
    if (!/^https?:\/\/[^/?#]/i.test(href)) continue
    const start = match.index
    if (start > last) parts.push({ kind: 'text', text: text.slice(last, start) })
    parts.push({ kind: 'link', href })
    last = start + href.length
  }
  if (last < text.length) parts.push({ kind: 'text', text: text.slice(last) })
  return parts
}
