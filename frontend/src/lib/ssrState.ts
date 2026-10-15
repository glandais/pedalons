import type { DehydratedState } from '@tanstack/react-query'
import type { SsrAuthSnapshot } from '@/lib/requestContext'

/**
 * The state the SSR render hands over, read from the `<script type="application/json">` blocks
 * server.js writes (server/ssrState.js, whose ids these repeat). Data blocks, not inline scripts:
 * they never run, so the site's CSP needs no exception for them (docs/LEDGER_*.md SEC-31).
 *
 * Synchronous and safe at module load: module scripts run once the document is parsed, so the
 * blocks — written after `#root` — are already there. Undefined on the server, without a block, or
 * with one that does not parse.
 */
export const SSR_QUERY_STATE_ID = 'ssr-query-state'
export const SSR_AUTH_STATE_ID = 'ssr-auth-state'

export function readSsrJson<T>(id: string): T | undefined {
  if (typeof document === 'undefined') return undefined
  const element = document.getElementById(id)
  // Only the block server.js writes, a direct child of <body>: an element of the page's own content
  // (inside #root) that happened to carry the id is not taken for it.
  if (
    !(element instanceof HTMLScriptElement) ||
    element.type !== 'application/json' ||
    element.parentElement !== document.body
  ) {
    return undefined
  }
  try {
    return JSON.parse(element.textContent ?? '') as T
  } catch (error) {
    console.error(`[SSR] Unreadable #${id} block`, error)
    return undefined
  }
}

/** The dehydrated React Query cache of the server render. */
export const ssrQueryState = () => readSsrJson<DehydratedState>(SSR_QUERY_STATE_ID)

/** The session the server rendered with, when the request carried one. */
export const ssrAuthState = () => readSsrJson<SsrAuthSnapshot>(SSR_AUTH_STATE_ID)
