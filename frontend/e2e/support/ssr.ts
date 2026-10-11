import { request } from '@playwright/test'
import { stack } from './stack'

/**
 * The server-rendered document as a crawler or a link unfurler gets it: one GET, no JavaScript, no
 * browser. `server.js` assembles it from three sources, each of which can carry data on its own —
 * the React markup at `<!--ssr-outlet-->`, the dehydrated query cache in
 * `window.__REACT_QUERY_STATE__`, and the link-preview `<head>` block at `<!--ssr-head-->` — so a
 * privacy check reads all three, not just what a user would see.
 */

export interface RawDocument {
  status: number
  headers: Record<string, string>
  /** The whole document, byte for byte. */
  html: string
}

/**
 * GETs `path` as a document request, anonymously or with `cookie` (e.g. `refresh_token=…`), without
 * following redirects — a redirect is an answer the caller may want to see. A fresh request
 * context each time: no cookie jar carries one visitor's session into another's fetch.
 */
export async function rawDocument(
  path: string,
  { cookie }: { cookie?: string } = {}
): Promise<RawDocument> {
  const api = await request.newContext({
    baseURL: stack.baseURL,
    extraHTTPHeaders: {
      Accept: 'text/html',
      'Accept-Language': 'fr-FR',
      ...(cookie ? { Cookie: cookie } : {}),
    },
  })
  try {
    const response = await api.get(path, { maxRedirects: 0 })
    keepRotatedSession(cookie, response.headersArray())
    return { status: response.status(), headers: response.headers(), html: await response.text() }
  } finally {
    await api.dispose()
  }
}

/** The session each Cookie header built by sessionCookie() stands for. */
const cookieHolders = new Map<string, { refreshToken: string }>()

/**
 * The server render refreshes the session a document is fetched with, and the refresh rotates its
 * token (docs/LEDGER_*.md SEC-27): the new one comes back in the document's `Set-Cookie`. Kept in
 * the AuthResponse the cookie was built from, so that the test's next document or refresh presents
 * the current token — the old one, presented after a minute, takes the chain over and drops the
 * successor (docs/LEDGER_*.md API-94).
 */
export function keepRotatedSession(
  cookie: string | undefined,
  headers: { name: string; value: string }[]
) {
  const holder = cookie === undefined ? undefined : cookieHolders.get(cookie)
  if (!holder) return
  for (const { name, value } of headers) {
    if (name.toLowerCase() !== 'set-cookie') continue
    const token = value.match(/^refresh_token=([^;]+)/)?.[1]
    if (token) holder.refreshToken = token
  }
}

/** The Cookie header of a signed-in visitor: the refresh_token the SSR server turns into a session. */
export const sessionCookie = (auth: { refreshToken: string }) => {
  const cookie = `refresh_token=${auth.refreshToken}`
  cookieHolders.set(cookie, auth)
  return cookie
}

/**
 * The server-rendered markup only: from `#root` to the first script (StaticRouterProvider's
 * hydration data, then the dehydrated state and `__AUTH_STATE__`, none of which is markup).
 */
export function ssrOutlet(html: string): string {
  const start = html.indexOf('<div id="root">')
  if (start < 0) throw new Error('no #root in the document')
  const end = html.indexOf('<script', start)
  return html.slice(start, end < 0 ? undefined : end)
}

/** The text of the inline `<script>window.<name>=…</script>`, or undefined when there is none. */
function inlineGlobal(html: string, name: string): string | undefined {
  const marker = `window.${name}=`
  const start = html.indexOf(marker)
  if (start < 0) return undefined
  const end = html.indexOf('</script>', start)
  return html.slice(start + marker.length, end < 0 ? undefined : end)
}

export interface DehydratedQuery {
  queryKey: unknown[]
  state: { status: string; data?: unknown }
}

/**
 * The query cache the server handed over (`window.__REACT_QUERY_STATE__`), parsed — server.js
 * escapes `<` as `<`, which JSON.parse reads back. An empty cache when the document has none.
 */
export function reactQueryState(html: string): { queries: DehydratedQuery[] } {
  const json = inlineGlobal(html, '__REACT_QUERY_STATE__')
  if (!json) return { queries: [] }
  return JSON.parse(json) as { queries: DehydratedQuery[] }
}

/** The dehydrated query whose key starts with `endpoint` (e.g. `/api/teams/x`), if any. */
export const dehydratedQuery = (html: string, endpoint: string) =>
  reactQueryState(html).queries.find((query) => query.queryKey[0] === endpoint)

const decodeEntities = (text: string) =>
  text
    .replace(/&quot;/g, '"')
    .replace(/&#x27;|&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')

/**
 * The link-preview tags of the document's `<head>`: every `og:*`, `article:*` and `twitter:*`
 * `<meta>` (by `property` or `name`), and the `<title>` under `title` — values entity-decoded, as a
 * crawler reads them. A property that repeats (`og:locale:alternate`) keeps every value.
 */
export function ogTags(html: string): Record<string, string[]> {
  const headEnd = html.indexOf('</head>')
  const head = headEnd < 0 ? html : html.slice(0, headEnd)
  const tags: Record<string, string[]> = {}
  const add = (key: string, value: string) => (tags[key] ??= []).push(decodeEntities(value))
  for (const [tag] of head.matchAll(/<meta\b[^>]*>/g)) {
    const key = /\b(?:property|name)="((?:og|article|twitter):[^"]+)"/.exec(tag)?.[1]
    const content = /\bcontent="([^"]*)"/.exec(tag)?.[1]
    if (key && content !== undefined) add(key, content)
  }
  for (const [, title] of head.matchAll(/<title>([^<]*)<\/title>/g)) add('title', title)
  return tags
}

/** The session the server rendered the page for (`window.__AUTH_STATE__`): its user, or null. */
export function authState(html: string): { user: { id: string } | null } | undefined {
  const json = inlineGlobal(html, '__AUTH_STATE__')
  return json ? (JSON.parse(json) as { user: { id: string } | null }) : undefined
}
