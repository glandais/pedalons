// The state the SSR render hands to the client (docs/LEDGER_*.md SEC-31): data blocks, not
// scripts. A <script type="application/json"> never runs, so it needs no nonce and no CSP
// exception; the client reads it with JSON.parse (src/lib/ssrState.ts, which repeats these ids).

/** The dehydrated React Query cache. */
export const SSR_QUERY_STATE_ID = 'ssr-query-state'
/** The session the page was rendered with — it carries a 15-minute access token. */
export const SSR_AUTH_STATE_ID = 'ssr-auth-state'

/**
 * JSON safe inside a <script> element. In a data block the HTML parser still ends the element at
 * `</script` and changes state at `<!--`, and both start with `<`: escaping every `<` as `\u003c`
 * — which can only occur inside a JSON string, where JSON.parse reads it back — leaves no way out.
 * `>` and `&` are escaped too, so no text the page shows can be read as markup either.
 */
export function serializeForScript(value) {
  const json = JSON.stringify(value)
  if (json === undefined) return undefined
  return json.replace(/</g, '\\u003c').replace(/>/g, '\\u003e').replace(/&/g, '\\u0026')
}

/** `<script type="application/json" id=…>`, or '' for a value that has no JSON form (undefined). */
export function jsonScript(id, value) {
  const json = serializeForScript(value)
  return json === undefined ? '' : `<script type="application/json" id="${id}">${json}</script>`
}
