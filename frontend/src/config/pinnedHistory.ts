/**
 * Hidden-prefix history for pinned single-team hosts.
 *
 * On a host pinned to one team (e.g. np.localhost → team "n-peloton"), the whole app keeps
 * operating INTERNALLY on the prefixed paths it always used (`/equipes/n-peloton/...`), so the
 * route table, every `useParams().teamSlug`, and all `paths.xxx()` builders stay untouched. This
 * module inserts a custom History between React Router and the browser that maps between the two:
 *
 *   router path  /equipes/n-peloton/sorties/x   <->   browser path  /sorties/x
 *
 * Genuinely-global pages (login, profile, legal, gpx tools, platform admin at /plateforme) keep
 * their own unprefixed paths. See App.tsx for the wiring; this only runs when getPinnedTeamSlug().
 */
import {
  UNSAFE_createBrowserHistory,
  createPath,
  matchPath,
  parsePath,
  type Location,
  type To,
} from 'react-router-dom'
import { getPinnedTeamSlug } from './appConfig'
import { getCurrentLocale } from './locale-context'
import { pathVariants, type Locale } from './paths'
import { routesConfig } from './routes.config'

// `History`/`Update` aren't re-exported from react-router-dom's type surface, so derive them from
// the browser-history factory (which returns a BrowserHistory extending History).
type RRHistory = ReturnType<typeof UNSAFE_createBrowserHistory>
type RRListener = Parameters<RRHistory['listen']>[0]
type RRUpdate = Parameters<RRListener>[0]

/** First path segment (`/sorties/x` → `sorties`, `/` → `''`). */
function firstSeg(pathname: string): string {
  return pathname.split('/')[1] ?? ''
}

/**
 * Segments that must NOT be prefixed on a pinned host — i.e. genuinely-global routes with no team
 * equivalent. Derived from routesConfig (not hardcoded): a route is "global" when no locale variant
 * carries `:teamSlug`. Segments shared by a global AND a team route (the collisions:
 * calendrier/calendar, parcours/routes) are removed so the TEAM version wins — the global aggregated
 * pages are redundant on a single-team site. The empty root segment is removed so `/` maps to the
 * team home. `teams`/`equipes` stay in the set so bare `/equipes` (team list, hidden here) is never
 * mistakenly re-prefixed.
 */
const GLOBAL_ONLY: ReadonlySet<string> = (() => {
  const globalSegs = new Set<string>()
  const teamSegs = new Set<string>()
  for (const route of routesConfig) {
    const variants = Object.values(route.paths)
    const isTeamRoute = variants.some((v) => v.includes(':teamSlug'))
    for (const v of variants) {
      if (isTeamRoute) {
        // `/equipes/:teamSlug/sorties/:rideSlug` → segment right after the prefix (index 3).
        const sub = v.split('/')[3] ?? ''
        if (sub) teamSegs.add(sub)
      } else {
        globalSegs.add(firstSeg(v))
      }
    }
  }
  const result = new Set<string>()
  for (const seg of globalSegs) {
    if (seg !== '' && !teamSegs.has(seg)) result.add(seg)
  }
  return result
})()

/**
 * The team route templates of each locale (`/equipes/:teamSlug/sorties/:rideSlug` is fr). A clean
 * path such as `/rides/x` must take the prefix of its own language: under the other one
 * (`/equipes/n-peloton/rides/x`) no route matches, and the page would 404.
 */
const TEAM_PATTERNS: Record<Locale, string[]> = (() => {
  const result: Record<Locale, string[]> = { fr: [], en: [] }
  for (const route of routesConfig) {
    for (const [locale, v] of Object.entries(route.paths) as [Locale, string][]) {
      if (v.includes(':teamSlug')) result[locale].push(v)
    }
  }
  return result
})()

/** The team-detail prefix in both locales, e.g. `{ en: '/teams/n-peloton', fr: '/equipes/n-peloton' }`. */
function getPrefixes(): Record<Locale, string> {
  return pathVariants.team(getPinnedTeamSlug()!)
}

/** router → browser: strip the pinned-team prefix from a pathname. Exported for tests. */
export function toBrowser(pathname: string): string {
  const prefixes = getPrefixes()
  for (const prefix of [prefixes.fr, prefixes.en]) {
    if (pathname === prefix) return '/'
    if (pathname.startsWith(prefix + '/')) return pathname.slice(prefix.length)
  }
  return pathname
}

/**
 * browser → router: prefix team pathnames; leave global ones (and already-prefixed ones) as-is.
 * The prefix is the current locale's when that makes a team route, else the other locale's when
 * that one does — so a link in either language resolves whatever the visitor's.
 * Exported for tests.
 */
export function toRouter(pathname: string): string {
  const prefixes = getPrefixes()
  for (const prefix of [prefixes.fr, prefixes.en]) {
    if (pathname === prefix || pathname.startsWith(prefix + '/')) return pathname
  }
  if (GLOBAL_ONLY.has(firstSeg(pathname))) return pathname
  const current = getCurrentLocale()
  const prefixed = (locale: Locale) =>
    pathname === '/' ? prefixes[locale] : prefixes[locale] + pathname
  // The current locale first, so a path both languages share (`/`, `/admin`) keeps it.
  for (const locale of [current, current === 'fr' ? 'en' : 'fr'] as Locale[]) {
    const candidate = prefixed(locale)
    if (TEAM_PATTERNS[locale].some((pattern) => matchPath(pattern, candidate))) return candidate
  }
  return prefixed(current)
}

/** Apply a pathname mapping to a `To` (string or Path object), preserving search/hash. */
function mapTo(to: To, mapPathname: (p: string) => string): To {
  if (typeof to === 'string') {
    const parsed = parsePath(to)
    return createPath({ ...parsed, pathname: mapPathname(parsed.pathname ?? '/') })
  }
  return { ...to, pathname: to.pathname != null ? mapPathname(to.pathname) : to.pathname }
}

/** Map a browser-space Location to the router-space Location the app expects. */
function toRouterLocation(location: Location): Location {
  return { ...location, pathname: toRouter(location.pathname) }
}

let historyInstance: RRHistory | null | undefined

/**
 * The pinned-team hidden-prefix history, created lazily ONCE on first access and memoized. Returns
 * null on a normal (non-pinned) host. Must be called during/after the first render, never at module
 * load: /api/config (and thus getPinnedTeamSlug()) is only resolved right before ReactDOM renders.
 */
export function getPinnedHistory(): RRHistory | null {
  if (historyInstance === undefined) {
    historyInstance = getPinnedTeamSlug() ? createPinnedHistory() : null
  }
  return historyInstance
}

/**
 * Build the hidden-prefix history. Must be called once, after /api/config is resolved
 * (getPinnedTeamSlug() non-null) and before the first render.
 */
function createPinnedHistory(): RRHistory {
  // Redirect legacy prefixed deep links (bookmarks, emails) to the clean form once at boot, with no
  // flicker — before React Router reads the location.
  const current = window.location.pathname
  const clean = toBrowser(current)
  if (clean !== current) {
    window.history.replaceState(null, '', clean + window.location.search + window.location.hash)
  }

  // No v5Compat, exactly like createBrowserRouter's own history. This history feeds a data router
  // (UNSAFE_createRouter in App.tsx), which calls push/replace itself once a navigation completes
  // and only listens for POP (back/forward). With v5Compat, every push/replace also notified the
  // router's listener, which started the same navigation again: a redirect (an anonymous visit to a
  // members-only page) replaced, got notified, redirected, replaced… until the stack overflowed.
  const base = UNSAFE_createBrowserHistory()
  const toBrowserTo = (to: To): To => mapTo(to, toBrowser)

  return {
    get action() {
      return base.action
    },
    get location() {
      return toRouterLocation(base.location)
    },
    createHref(to: To) {
      return base.createHref(toBrowserTo(to))
    },
    createURL(to: To) {
      return base.createURL(toBrowserTo(to))
    },
    encodeLocation(to: To) {
      const encoded = base.encodeLocation(toBrowserTo(to))
      return { ...encoded, pathname: toRouter(encoded.pathname) }
    },
    push(to: To, state?: unknown) {
      base.push(toBrowserTo(to), state)
    },
    replace(to: To, state?: unknown) {
      base.replace(toBrowserTo(to), state)
    },
    go(delta: number) {
      base.go(delta)
    },
    listen(listener: RRListener) {
      return base.listen((update: RRUpdate) =>
        listener({ ...update, location: toRouterLocation(update.location) })
      )
    },
  }
}
