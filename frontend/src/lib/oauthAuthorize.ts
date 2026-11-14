/**
 * The request an external application puts on `/oauth/authorize` (OAuth 2.0 authorization code
 * flow with PKCE, docs/LEDGER_*.md API-199), read from the query string before anything is shown.
 *
 * Applications are not registered: `client_id` is a name the application gives itself and
 * `redirect_uri` is checked against nothing — any URL or deep link. What is checked here is only
 * what makes the request usable (and mirrored by `OAuthService` on the backend, which decides).
 */
export interface OAuthAuthorizeParams {
  clientId: string
  redirectUri: string
  codeChallenge: string
  state?: string
}

/**
 * Schemes a browser runs or reads locally instead of navigating to. The page assigns the redirect
 * to `window.location`: a `javascript:` URI there would run in the site's own origin.
 */
const FORBIDDEN_SCHEMES = new Set(['javascript', 'data', 'vbscript', 'blob', 'file', 'about'])

const SCHEME = /^([a-z][a-z0-9+.-]*):/i
// Control and format characters (line breaks, bidi overrides, zero-width): what the member reads
// must be what was sent.
const INVISIBLE = /[\p{Cc}\p{Cf}]/u
// `https://pedalons.fr@elsewhere.example/` goes elsewhere.
const USERINFO = /^[a-z][a-z0-9+.-]*:\/\/[^/?]*@/i
const CODE_CHALLENGE = /^[A-Za-z0-9_-]{43}$/

/** An absolute URI without a fragment, whose scheme a browser navigates to. */
export function isUsableRedirectUri(redirectUri: string): boolean {
  const scheme = SCHEME.exec(redirectUri)?.[1]
  return (
    scheme !== undefined &&
    !FORBIDDEN_SCHEMES.has(scheme.toLowerCase()) &&
    !redirectUri.includes('#') &&
    !/\s/.test(redirectUri) &&
    !INVISIBLE.test(redirectUri) &&
    !USERINFO.test(redirectUri) &&
    redirectUri.length <= 2000
  )
}

/** The request of the query string, or null when it is incomplete or not one this flow serves. */
export function parseAuthorizeParams(search: URLSearchParams): OAuthAuthorizeParams | null {
  const clientId = search.get('client_id')?.trim()
  const redirectUri = search.get('redirect_uri')?.trim()
  const codeChallenge = search.get('code_challenge')
  const state = search.get('state') ?? undefined

  if (
    search.get('response_type') !== 'code' ||
    search.get('code_challenge_method') !== 'S256' ||
    !clientId ||
    clientId.length > 40 ||
    INVISIBLE.test(clientId) ||
    !redirectUri ||
    !isUsableRedirectUri(redirectUri) ||
    !codeChallenge ||
    !CODE_CHALLENGE.test(codeChallenge) ||
    (state !== undefined && state.length > 500)
  ) {
    return null
  }
  return { clientId, redirectUri, codeChallenge, state }
}

/**
 * Where a refusal sends the browser: the application's `redirect_uri` with `error=access_denied`
 * (RFC 6749 §4.1.2.1). Appended as text — a deep link is not always a URL that `URL` can rebuild.
 */
export function deniedRedirect(params: OAuthAuthorizeParams): string {
  const query = new URLSearchParams({ error: 'access_denied' })
  if (params.state !== undefined) query.set('state', params.state)
  return `${params.redirectUri}${params.redirectUri.includes('?') ? '&' : '?'}${query.toString()}`
}
