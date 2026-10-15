#!/usr/bin/env node
/**
 * Proves that session-aware SSR does not leak one visitor's session into another's page.
 *
 * The render path reads auth from an AsyncLocalStorage store, never from the module-level Zustand
 * singleton — but that singleton is one object shared by every concurrent render in the Node
 * process, so a single stray `setState` (or a new module-level cache) silently turns every
 * concurrent request into a data leak. Static checks cannot see that; only concurrency can.
 *
 * Usage:
 *   node scripts/ssr-session-isolation.mjs \
 *     --url http://localhost:8090 \
 *     --session <refresh_token_of_user_a> \
 *     --session <refresh_token_of_user_b> \
 *     [--path /] [--rounds 25]
 *
 * Get a refresh token from a logged-in browser: DevTools → Application → Cookies → refresh_token.
 * Exits non-zero on the first leak, or if a session cannot be resolved at all.
 */

const args = process.argv.slice(2)
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`)
  return i === -1 ? fallback : args[i + 1]
}
const all = (name) =>
  args.reduce((acc, a, i) => (a === `--${name}` ? [...acc, args[i + 1]] : acc), [])

const baseUrl = (opt('url', 'http://localhost:8090') ?? '').replace(/\/$/, '')
const path = opt('path', '/')
const rounds = Number(opt('rounds', '25'))
const tokens = all('session')

if (tokens.length < 2) {
  console.error('Need at least two --session <refresh_token> values to detect cross-talk.')
  process.exit(2)
}

/** The `#ssr-auth-state` block the server embedded, or null for an anonymous render. */
function extractAuthState(html) {
  const match = html.match(/<script type="application\/json" id="ssr-auth-state">(.*?)<\/script>/s)
  if (!match) return null
  try {
    return JSON.parse(match[1])
  } catch {
    return null
  }
}

async function fetchPage(token) {
  const response = await fetch(`${baseUrl}${path}`, {
    headers: { Cookie: `refresh_token=${token}`, 'Accept-Language': 'fr' },
    redirect: 'manual',
  })
  const html = await response.text()
  return { status: response.status, html, auth: extractAuthState(html) }
}

const identity = (auth) => auth?.user?.id ?? auth?.user?.email ?? null
const label = (auth) => auth?.user?.displayName ?? auth?.user?.email ?? '(anonymous)'

// Phase 1 — learn who each token is, one at a time. No concurrency, so nothing can be crossed yet.
const sessions = []
for (const [index, token] of tokens.entries()) {
  const { status, auth } = await fetchPage(token)
  const id = identity(auth)
  if (!id) {
    console.error(
      `Session #${index + 1}: the server rendered anonymously (HTTP ${status}). The token may be ` +
        `expired, or still scoped to the old path=/api — call POST /api/auth/refresh from the ` +
        `browser once to migrate it, then retry.`
    )
    process.exit(2)
  }
  sessions.push({ token, id, label: label(auth) })
  console.log(`Session #${index + 1}: ${label(auth)} (${id})`)
}

if (new Set(sessions.map((s) => s.id)).size !== sessions.length) {
  console.error('All --session tokens resolve to the same user; the test would prove nothing.')
  process.exit(2)
}

// Phase 2 — interleave them. Every response must carry back exactly the session it was sent, and
// must not mention any other session's display name anywhere in the markup.
const requests = []
for (let round = 0; round < rounds; round++) {
  for (const session of sessions) {
    requests.push(fetchPage(session.token).then((result) => ({ session, ...result })))
  }
}

const results = await Promise.all(requests)
const leaks = []

for (const { session, html, auth } of results) {
  const got = identity(auth)
  if (got !== session.id) {
    leaks.push(`expected ${session.label} (${session.id}), server returned ${label(auth)} (${got})`)
    continue
  }
  for (const other of sessions) {
    if (other.id !== session.id && other.label !== session.label && html.includes(other.label)) {
      leaks.push(`page rendered for ${session.label} contains ${other.label}'s display name`)
    }
  }
}

console.log(`\n${results.length} concurrent requests across ${sessions.length} sessions.`)
if (leaks.length > 0) {
  console.error(`\nSESSION LEAK — ${leaks.length} failure(s):`)
  for (const leak of [...new Set(leaks)]) console.error(`  - ${leak}`)
  process.exit(1)
}
console.log('No cross-session contamination.')
