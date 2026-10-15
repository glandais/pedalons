/**
 * Counts the page views of the client data router (docs/plans/2026-10-15-web-analytics.md §4.1,
 * docs/LEDGER_*.md WEB-90). Installed by `getRouter()` (App.tsx): the one place that sees every
 * route, `layout: 'bare'` ones included, runs on the client only, and sits outside React — so
 * StrictMode never doubles it.
 *
 * - **The first page view** is the router's state at install: with SSR `hydrationData` the router is
 *   born initialized and `subscribe` never fires for it; without, it fires once `initialized`.
 * - **A navigation** counts once it is idle on a new `location.key`: a PUSH or a POP always, a
 *   REPLACE only when the route changes — a filter edit (`useUrlFilters`) replaces on the same route.
 * - **A loader redirect** lands as a single state, recorded as a REPLACE (`throw replace(…)`), even
 *   on the route the visitor came from (ride A's `ride-detail` → ride B's `ride-group` → back on
 *   `ride-detail`). It is told apart from a filter edit by where it lands: elsewhere than the
 *   pathname the navigation aimed at when it left `idle`. A filter edit or a `useCanonicalPath`
 *   rewrite lands where it aimed. The arrival counts, once, as the PUSH it really is.
 * - **The send waits `SEND_DELAY_MS`**: a component redirect (`<Navigate replace>` of a gated route
 *   or of a members-only page visited anonymously) commits a first navigation, then replaces it. The
 *   REPLACE arriving meanwhile takes the pending hit's place instead of adding one. Any other page
 *   view arriving meanwhile sends the pending hit at once: one per PUSH, each with its full delay.
 * - **A match without `routeId`** (a gated route) is not counted.
 */
import { NavigationType } from 'react-router-dom'
import { getAppConfig } from '@/config/appConfig'
import { leafRouteId, toCountHit, type CountableState } from './countHit'
import { sendPageView } from './sender'

/** Long enough for a component redirect to replace the navigation it follows. */
export const SEND_DELAY_MS = 100

export interface CountedRouterState extends CountableState {
  initialized: boolean
  historyAction: NavigationType | `${NavigationType}`
  location: { key: string; pathname: string }
  navigation: { state: string; location?: { pathname: string } }
}

export interface CountedRouter {
  state: CountedRouterState
  subscribe(listener: (state: CountedRouterState) => void): () => void
}

/**
 * Subscribe the counter to the router. Does nothing when the deployment configures no counter
 * (`/api/config` `analytics: null`); every other guard is the sender's, read at each send.
 * Returns the unsubscribe function.
 */
export function installPageViewCounter(router: CountedRouter): () => void {
  if (!getAppConfig()?.analytics) return () => {}

  let lastKey: string | undefined
  let lastRouteId: string | undefined
  let sentOne = false
  let pending: { state: CountedRouterState; timer: ReturnType<typeof setTimeout> } | undefined
  // The pathname the navigation in flight aimed at when it left `idle`. A loader redirect keeps the
  // navigation busy up to its arrival, so this stays the visitor's target, not the redirect's.
  let aimedAt: string | undefined

  const flush = () => {
    if (!pending) return
    const { state } = pending
    pending = undefined
    // The referrer belongs to the first page view of the load — computed at send time, so a
    // REPLACE that took the first hit's place keeps it.
    const hit = toCountHit(state, window.location.host, document.referrer, !sentOne)
    if (!hit) return
    sentOne = true
    sendPageView(hit)
  }

  const consider = (state: CountedRouterState) => {
    if (state.navigation.state !== 'idle') {
      aimedAt ??= state.navigation.location?.pathname
      return
    }
    const target = aimedAt
    aimedAt = undefined
    if (!state.initialized) return
    const key = state.location.key
    if (key === lastKey) return
    lastKey = key

    const routeId = leafRouteId(state)
    const previousRouteId = lastRouteId
    lastRouteId = routeId

    // A REPLACE landing elsewhere than its navigation aimed is a loader redirect: a page view.
    const redirected = target !== undefined && state.location.pathname !== target
    const isReplace = state.historyAction === NavigationType.Replace && !redirected

    if (isReplace && pending) {
      // A redirect right after a navigation: the arrival replaces the hit still waiting.
      clearTimeout(pending.timer)
      pending = undefined
    } else if (isReplace && routeId === previousRouteId) {
      // Same route, new query string: a filter edit, not a page view.
      return
    } else if (pending) {
      // Another page view within the delay: the waiting one is sent now, not overwritten.
      clearTimeout(pending.timer)
      flush()
    }
    if (!routeId) return
    pending = { state, timer: setTimeout(flush, SEND_DELAY_MS) }
  }

  const unsubscribe = router.subscribe(consider)
  consider(router.state)
  return () => {
    unsubscribe()
    if (pending) clearTimeout(pending.timer)
    pending = undefined
  }
}
