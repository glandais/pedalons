// The site's Content-Security-Policy (docs/LEDGER_*.md SEC-31), built here rather than in a Traefik
// label because it carries a fresh nonce per document and the map hosts of the request's config.
//
// Two policies:
//
// - BASE_POLICY, on every response server.js sends (pages, assets, /sw.js, errors): the four
//   directives SEC-30 posed in Traefik, which constrain no script. It was a Traefik label; it moved
//   here because Traefik's headers middleware *overwrites* an upstream Content-Security-Policy, so
//   the label would have replaced the full policy the day it is enforced.
// - the document policy, on SSR HTML only: scripts by nonce, origins from the config. Sent as
//   Content-Security-Policy-Report-Only beside the enforced BASE_POLICY unless CSP_MODE=enforce,
//   where it replaces it.
//
// Never on the API: /api is routed to the backend by Traefik, and a policy there would override the
// sandbox CSP of downloads (UploadedContentHeaders, SEC-1) and stop the browser's PDF viewer.

import crypto from 'node:crypto'

/** SEC-30's directives: nothing embeds the site, no plugin, no foreign <base>, no form posts away. */
export const BASE_DIRECTIVES = [
  "frame-ancestors 'none'",
  "base-uri 'self'",
  "object-src 'none'",
  "form-action 'self'",
]

export const BASE_POLICY = BASE_DIRECTIVES.join('; ')

/** Where browsers post violations: a server.js route, so no API contract is involved. */
export const REPORT_PATH = '/csp-report'
export const REPORT_GROUP = 'csp'

/**
 * The Firebase hosts the web push token registration calls (firebase/messaging getToken, found in
 * the firebase-vendor chunk). Only allowed when the config offers web push at all.
 */
export const FCM_ORIGINS = [
  'https://firebaseinstallations.googleapis.com',
  'https://fcmregistrations.googleapis.com',
]

/** 128 bits from the CSPRNG, base64: unguessable, and safe inside a double-quoted attribute. */
export function generateNonce() {
  return crypto.randomBytes(16).toString('base64')
}

/** `report-only` unless the variable says `enforce`; anything else is reported, not guessed at. */
export function parseCspMode(value) {
  const mode = String(value ?? '')
    .trim()
    .toLowerCase()
  if (mode === 'enforce') return { mode: 'enforce' }
  if (mode === '' || mode === 'report-only') return { mode: 'report-only' }
  return { mode: 'report-only', invalid: String(value) }
}

// A scheme and a host (a leading `*.` allowed for the extras), an optional port: nothing that could
// close a directive (`;`, `,`, a quote, a space) can reach the header from a config value.
const ORIGIN = /^https?:\/\/[a-z0-9-]+(\.[a-z0-9-]+)*(:\d{1,5})?$/
const EXTRA_SOURCE = /^(https?|wss?):\/\/(\*\.)?[a-z0-9-]+(\.[a-z0-9-]+)*(:\d{1,5})?$/

/** The origin of an absolute http(s) URL (a tile template with `{z}` in its path parses fine), or null. */
export function originOf(url) {
  if (typeof url !== 'string' || url === '') return null
  try {
    const parsed = new URL(url)
    if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') return null
    return ORIGIN.test(parsed.origin) ? parsed.origin : null
  } catch {
    return null
  }
}

/**
 * CSP_CONNECT_SRC_EXTRA: hosts a third-party style document or TileJSON points at beyond its own
 * (its sprite, glyphs or tiles elsewhere), which the config cannot name. Space- or comma-separated
 * origins; a token that is not one is dropped and returned in `rejected`.
 */
export function parseExtraSources(value) {
  const accepted = []
  const rejected = []
  for (const token of String(value ?? '').split(/[\s,]+/)) {
    if (!token) continue
    const source = token.toLowerCase().replace(/\/$/, '')
    if (EXTRA_SOURCE.test(source)) accepted.push(source)
    else rejected.push(token)
  }
  return { accepted, rejected }
}

/** The style URL a raster basemap is served at by MapStyleService (`/api/map/styles/{id}.json`). */
const GENERATED_STYLE_PATH = /^\/api\/map\/styles\/[A-Za-z0-9._-]+\.json$/

/** Path of a style URL the web client loads same-origin (mapStyles.ts sameOriginIfApi), or null. */
function apiPathOf(url) {
  try {
    const parsed = new URL(url, 'http://localhost')
    return parsed.pathname.startsWith('/api/') ? parsed.pathname : null
  } catch {
    return null
  }
}

/** Every origin a MapLibre style document makes the browser fetch from: tiles, TileJSON, sprite, glyphs. */
export function styleDocumentOrigins(style) {
  const urls = []
  if (style && typeof style === 'object') {
    for (const source of Object.values(style.sources ?? {})) {
      if (!source || typeof source !== 'object') continue
      if (Array.isArray(source.tiles)) urls.push(...source.tiles)
      urls.push(source.url)
    }
    if (Array.isArray(style.sprite)) urls.push(...style.sprite.map((entry) => entry?.url))
    else urls.push(style.sprite)
    urls.push(style.glyphs)
  }
  return urls.map(originOf).filter(Boolean)
}

/**
 * The origins the browser reaches for the given config (GET /api/config, ConfigDto):
 *
 * - each basemap's style document and dark variant — a third-party style is assumed to keep its
 *   sprite, glyphs and tiles on its own host (true of VersaTiles and IGN today; CSP_CONNECT_SRC_EXTRA
 *   covers one that does not, and Report-Only shows it);
 * - the raster basemaps the backend wraps itself (`/api/map/styles/{id}.json`, loaded same-origin):
 *   their tile hosts are only in that document, so it is fetched, through `fetchStyle`, and kept
 *   for `ttlMs` — the styles are deployment configuration, the same for every tenant;
 * - the terrain TileJSON (its tiles assumed on the same host, as Mapterhorn's are);
 * - Firebase, when the config offers web push.
 *
 * Never throws, and never trades known hosts for none: a style that cannot be fetched keeps the hosts
 * of its last successful read (retried after `failureTtlMs`), and is only left out when it was never
 * read — which Report-Only reports rather than breaks. Without a config (the SSR config fetch failed)
 * the result is the last one computed from a config, process-wide (the hosts are deployment
 * configuration), or `null` when there has been none yet: the caller must then not enforce a policy
 * whose connect-src would be 'self' alone for the whole SPA session.
 */
export function createConfigOriginResolver({
  fetchStyle,
  ttlMs = 10 * 60_000,
  failureTtlMs = 60_000,
  now = Date.now,
  onError = () => {},
}) {
  const cache = new Map()
  // The origins of each generated style's last successful read: served again when a refetch fails,
  // so a backend restart (a start-first deploy) does not blank the raster basemaps.
  const lastGood = new Map()
  let lastKnownOrigins = null

  function generatedStyleOrigins(path) {
    const hit = cache.get(path)
    if (hit && hit.expiresAt > now()) return hit.promise
    const promise = Promise.resolve()
      .then(() => fetchStyle(path))
      .then(
        (style) => {
          const origins = styleDocumentOrigins(style)
          lastGood.set(path, origins)
          cache.set(path, { promise, expiresAt: now() + ttlMs })
          return origins
        },
        (err) => {
          onError(path, err)
          cache.set(path, { promise, expiresAt: now() + failureTtlMs })
          return lastGood.get(path) ?? []
        }
      )
    // Concurrent requests share the fetch in flight.
    cache.set(path, { promise, expiresAt: Number.POSITIVE_INFINITY })
    return promise
  }

  return async function configOrigins(config) {
    if (!config || typeof config !== 'object') return lastKnownOrigins
    const origins = []
    const pending = []
    for (const style of Array.isArray(config.mapStyles) ? config.mapStyles : []) {
      for (const url of [style?.url, style?.darkVariant]) {
        if (typeof url !== 'string' || url === '') continue
        const apiPath = apiPathOf(url)
        if (apiPath === null) {
          const origin = originOf(url)
          if (origin) origins.push(origin)
        } else if (GENERATED_STYLE_PATH.test(apiPath)) {
          pending.push(generatedStyleOrigins(apiPath))
        }
      }
    }
    const terrain = originOf(config.terrain?.url)
    if (terrain) origins.push(terrain)
    if (config.webPush) origins.push(...FCM_ORIGINS)
    for (const list of await Promise.all(pending)) origins.push(...list)
    lastKnownOrigins = origins
    return origins
  }
}

/**
 * The policy of one SSR document. `nonce` is the request's; `connectOrigins` what
 * createConfigOriginResolver found plus the extras.
 *
 * - script-src: `'self'` for Vite's module entry, its modulepreload links and lazy chunks (all
 *   /assets on this origin), the nonce for the inline scripts (the theme script of index.html,
 *   React Router's hydration data). No 'strict-dynamic': it would make browsers ignore 'self', so
 *   the parser-inserted entry and every modulepreload link would need the nonce too, for nothing —
 *   every script is same-origin and no uploaded file can be one (nosniff, scripts refused at upload).
 *   No 'unsafe-eval': nothing needs it once Zod runs jitless (src/lib/zodConfig.ts).
 * - style-src keeps 'unsafe-inline' and no nonce: Mantine writes <style> tags and hundreds of style
 *   attributes, and a nonce in style-src would make browsers ignore 'unsafe-inline'.
 * - img-src https: — markdown images come from any host.
 */
export function buildDocumentPolicy({ nonce, connectOrigins = [] }) {
  if (!nonce) throw new Error('A document policy needs a nonce')
  const connect = ["'self'", ...new Set(connectOrigins)]
  return [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}'`,
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob: https:",
    "font-src 'self' data:",
    `connect-src ${connect.join(' ')}`,
    "worker-src 'self'",
    "manifest-src 'self'",
    "frame-src 'none'",
    ...BASE_DIRECTIVES,
    `report-uri ${REPORT_PATH}`,
    `report-to ${REPORT_GROUP}`,
  ].join('; ')
}

/** The headers of an SSR document for the mode: the full policy enforced, or reported beside SEC-30's. */
export function documentCspHeaders(mode, policy) {
  const reporting = { 'Reporting-Endpoints': `${REPORT_GROUP}="${REPORT_PATH}"` }
  return mode === 'enforce'
    ? { 'Content-Security-Policy': policy, ...reporting }
    : {
        'Content-Security-Policy': BASE_POLICY,
        'Content-Security-Policy-Report-Only': policy,
        ...reporting,
      }
}

/** Stamps the nonce on the template's bare inline `<script>` tags (index.html's theme script). */
export function nonceInlineScripts(template, nonce) {
  return template.replaceAll('<script>', `<script nonce="${nonce}">`)
}
