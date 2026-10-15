/**
 * Sends a page view to the self-hosted counter, on the site's own origin
 * (docs/plans/2026-10-15-web-analytics.md §4.3, docs/LEDGER_*.md WEB-90).
 *
 * A plain `fetch`, without GoatCounter's `count.js`: no global, no script, no automatic counter, and
 * the tests see exactly what leaves. **Never `navigator.sendBeacon`**: it always POSTs, always
 * carries the cookies (the `refresh_token`, `Path=/`) and a `Referer`, which on the same origin is
 * the page's whole URL — query string included. The Traefik middleware strips `Cookie` and
 * `Referer` too, as defence in depth.
 *
 * Neither `q` (the page's query string: GoatCounter turns it into campaigns), `b` (bot flag: a
 * driven browser sends nothing at all) nor `e` (events are out of scope) is ever sent.
 *
 * Touches no browser global at import: the SSR bundle imports it.
 */
import { getAppConfig } from '@/config/appConfig'
import type { CountHit } from './countHit'
import { isAnalyticsOptedOut } from './optOut'

/** `fetch` options of every hit: no cookie, no `Referer`, nothing cached, survives a page exit. */
export const COUNT_FETCH_OPTIONS: RequestInit = {
  keepalive: true,
  credentials: 'omit',
  referrerPolicy: 'no-referrer',
  cache: 'no-store',
}

/** The browser privacy signals, honoured without asking: the only opposition valid on every site. */
export function browserSignalsOptOut(): boolean {
  const nav = navigator as Navigator & { globalPrivacyControl?: boolean }
  return nav.doNotTrack === '1' || nav.globalPrivacyControl === true
}

function isLoopback(hostname: string): boolean {
  const name = hostname.toLowerCase()
  return (
    name === 'localhost' ||
    name.endsWith('.localhost') ||
    /^127(\.\d{1,3}){3}$/.test(name) ||
    name === '[::1]' ||
    name === '::1'
  )
}

/**
 * The counter path when a page view may be sent now, or null: measurement not configured (e2e,
 * workstation, staging), Do Not Track or Global Privacy Control, the local opposition, a driven
 * browser, a prerendered page, a loopback host. Every condition is read again at each send.
 */
export function countPathIfAllowed(): string | null {
  const countPath = getAppConfig()?.analytics?.countPath
  if (!countPath) return null
  if (browserSignalsOptOut()) return null
  if (isAnalyticsOptedOut()) return null
  if (navigator.webdriver) return null
  if ((document as Document & { prerendering?: boolean }).prerendering) return null
  if (isLoopback(window.location.hostname)) return null
  return countPath
}

/** Five random characters, against caches that ignore `Cache-Control` (as `count.js` does). */
function cacheBuster(): string {
  return Math.random().toString(36).slice(2, 7).padEnd(5, '0')
}

/**
 * The screen width as the category GoatCounter's dashboard shows, never the exact width: the upper
 * bound of its bucket (`HitStats.ListSizes` of v2.7.0: phone ≤ 600, tablet ≤ 1000, desktop ≤ 1920,
 * larger beyond). The dashboard reads the same, and no pixel count is stored that could set one
 * device apart (docs/plans/2026-10-15-web-analytics.md §5.1, row 2). Undefined when unknown.
 */
export function screenSizeCategory(screenWidth: number): number | undefined {
  if (!Number.isFinite(screenWidth) || screenWidth <= 0) return undefined
  if (screenWidth <= 600) return 600
  if (screenWidth <= 1000) return 1000
  if (screenWidth <= 1920) return 1920
  return 2560
}

/** The counter URL of a hit. `s` is a size category (`screenSizeCategory`), not the width. */
export function buildCountUrl(
  countPath: string,
  hit: CountHit,
  screenWidth: number,
  rnd: string
): string {
  const params = new URLSearchParams()
  params.set('p', hit.p)
  params.set('t', hit.t)
  if (hit.r) params.set('r', hit.r)
  const size = screenSizeCategory(screenWidth)
  if (size) params.set('s', String(size))
  params.set('rnd', rnd)
  return `${countPath}?${params.toString()}`
}

/** Send one page view, unless one of the guards says no. Failures are silent. */
export function sendPageView(hit: CountHit): void {
  const countPath = countPathIfAllowed()
  if (!countPath) return
  const url = buildCountUrl(countPath, hit, screen.width, cacheBuster())
  try {
    fetch(url, COUNT_FETCH_OPTIONS).catch(() => {
      // A blocker, the counter down: a page view lost, nothing to tell the visitor.
    })
  } catch {
    // Same: a synchronous refusal (a blocked keepalive quota) is not the page's concern.
  }
}
