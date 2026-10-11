// SSR-only module: reads process.env and talks to the backend directly. Imported from
// entry-server.tsx only — never from code that ends up in the client bundle.
import type { SsrAuthSnapshot } from './requestContext'

const REFRESH_TOKEN_COOKIE = 'refresh_token'

/** Cap on the extra round-trip: a slow or wedged backend must not hold the whole document. */
const TIMEOUT_MS = 3_000

/**
 * Exchange the incoming `refresh_token` cookie for an access token, so the rest of the render can
 * call the API as the visitor rather than anonymously.
 *
 * One call per document request, and only when a cookie is actually present. The result is a bearer
 * token used for every prefetch — the raw cookie is never relayed, because the backend's cookie
 * fallback only authenticates `@PermitAll` endpoints while a bearer token behaves exactly like the
 * browser's, which is what keeps server-rendered DTOs identical to the client's.
 *
 * Two ways of rendering without a session, which must not be confused (docs/LEDGER_*.md WEB-39):
 *
 * - **no session** — no cookie, or the backend refused it (401/403): {@link ANONYMOUS}. The page
 *   is rendered anonymously and says so to the client, which then skips its own refresh. A revoked
 *   or expired token is the normal case here, not an incident.
 * - **session unknown** — the refresh timed out, the network failed, the backend answered anything
 *   else: undefined. The page is still rendered anonymously, but the client is told nothing and
 *   makes its own refresh after hydration; a member must not be shown signed out, nor their private
 *   team as missing, because the backend was slow.
 *
 * A refresh abandoned at the timeout may still rotate the token on the backend, its `Set-Cookie`
 * lost: the browser then presents the old token again, which the rotation's grace, then a new
 * rotation from it, still honour (docs/LEDGER_*.md API-94). Nothing is lost by giving up on it.
 *
 * The refresh rotates the session's token (docs/LEDGER_*.md SEC-27): the backend's `Set-Cookie`
 * is handed to `onSetCookie` as soon as the answer arrives, whatever becomes of the render, and the
 * document response must carry it. Lost, the browser would keep the old token: past the rotation's
 * grace it rotates again from it (docs/LEDGER_*.md API-94), and whoever held the lost successor —
 * another tab that did get it — is refused at its next refresh.
 *
 * Note on migration: sessions created before the cookie moved to `path=/` are invisible here (the
 * browser does not send them on a document request). Those renders stay anonymous until the client's
 * own `/api/auth/refresh` call re-issues the cookie on the new path — from the next navigation on,
 * SSR sees it. No reconnection required.
 */
/** The snapshot of a render without a session. */
export const ANONYMOUS: SsrAuthSnapshot = { accessToken: null, user: null, hasPasskeys: false }

export async function resolveSsrSession(
  headers: Record<string, string>,
  onSetCookie: (cookies: string[]) => void = () => {}
): Promise<SsrAuthSnapshot | undefined> {
  const cookie = headers['cookie']
  if (!cookie || !new RegExp(`(?:^|;\\s*)${REFRESH_TOKEN_COOKIE}=`).test(cookie)) {
    return ANONYMOUS
  }

  const baseUrl = process.env.API_BASE_URL || 'http://localhost:8080'
  const outbound: Record<string, string> = { Cookie: cookie }
  // The tenant must resolve server-side too, otherwise the session looks up against no domain.
  const host = headers['x-forwarded-host'] || headers['host']
  if (host) outbound['X-Forwarded-Host'] = host
  const proto = headers['x-forwarded-proto']
  if (proto) outbound['X-Forwarded-Proto'] = proto

  try {
    const response = await fetch(`${baseUrl}/api/auth/refresh`, {
      method: 'POST',
      headers: outbound,
      signal: AbortSignal.timeout(TIMEOUT_MS),
    })
    const setCookies = response.headers.getSetCookie()
    if (setCookies.length > 0) onSetCookie(setCookies)

    if (!response.ok) {
      // 401/403 just means "no usable session" — expected, not worth a log line.
      if (response.status === 401 || response.status === 403) return ANONYMOUS
      console.warn(`[SSR] Session refresh returned ${response.status}, leaving it to the client`)
      return undefined
    }

    const data = await response.json()
    if (!data?.accessToken) return ANONYMOUS

    return {
      accessToken: data.accessToken,
      user: data.user ?? null,
      hasPasskeys: data.hasPasskeys ?? false,
    }
  } catch (err) {
    console.error('[SSR] Session refresh failed, leaving it to the client:', err)
    return undefined
  }
}
