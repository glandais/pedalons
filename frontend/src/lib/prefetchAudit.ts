import type { QueryClient } from '@tanstack/react-query'
import type { RouterProvider } from 'react-router-dom'

type Router = Parameters<typeof RouterProvider>[0]['router']

// RouteGenerator.tsx stamps routes.config.ts's own `id` onto `handle.routeId` — the RouteObject's
// own `id` can't be reused for this: React Router requires it unique per object, and each locale
// variant of a route is a separate object sharing one config id.
function currentRouteName(router: Router): string {
  const routeId = (router.state.matches.at(-1)?.route.handle as { routeId?: string } | undefined)
    ?.routeId
  return routeId ?? router.state.location.pathname
}

// Different components mount (and start fetching) across separate React commits/effects rather
// than all at once, so queryClient.isFetching() can dip to 0 for a moment between two waves of
// fetches on the same page — e.g. an already-covered query finishing its own background revalidation
// right before a later effect kicks off the actual missing fetch. Closing the window immediately on
// that dip would miss it, so closing is debounced: only commit to "settled" after this many ms with
// no fetch activity at all.
const SETTLE_DEBOUNCE_MS = 5000

/**
 * Logs, once per first page load, whether any queries got fetched on the client that weren't
 * already in the SSR-dehydrated cache: a console.warn listing the gaps, or a console.info that
 * everything was covered. A gap is a hole in that route's `prefetch()` declaration in
 * routes.config.ts — the data is fetched anyway, just after the first paint instead of before it.
 *
 * First load only: the watch window closes once queryClient.isFetching() has stayed at 0 for
 * SETTLE_DEBOUNCE_MS (the page has settled), and the whole thing disarms for good the moment a
 * route change starts — no re-arming on client-side navigation.
 */
let auditWindowOpen = false

/**
 * `meta` key of a query that is deliberately left to the client — not a hole in the route's
 * `prefetch()`, so the audit does not report it. For a read the server must not render into the
 * HTML (the planner's editing state, hundreds of KB on an authenticated page), never to quiet a
 * real gap: say why where the query is declared.
 */
export const CLIENT_ONLY_QUERY = 'clientOnly'

/**
 * True while the audit is still watching the first page load. `lib/prefetch.ts` suppresses link
 * prefetching during that window: a hover fetches ANOTHER route's queries, which the audit would
 * count as a gap in the current route's `prefetch()` — a false gap is worse than a missed warm-up,
 * since the whole value of the audit is that its warnings are trustworthy. The window is at most a
 * few seconds and only exists in audit builds.
 */
export function isPrefetchAuditWindowOpen(): boolean {
  return auditWindowOpen
}

export function installPrefetchAudit(queryClient: QueryClient, router: Router): void {
  auditWindowOpen = true
  const initialLocation = router.state.location
  const coveredHashes = new Set(
    queryClient
      .getQueryCache()
      .getAll()
      .map((q) => q.queryHash)
  )
  let closeTimer: ReturnType<typeof setTimeout> | undefined
  const missed: string[] = []

  function flush() {
    if (missed.length === 0) {
      console.info(
        `[prefetch-audit] route "${currentRouteName(router)}" (${router.state.location.pathname}): ` +
          `all queries were covered by route prefetch`
      )
      return
    }
    console.warn(
      `[prefetch-audit] route "${currentRouteName(router)}" (${router.state.location.pathname}): ` +
        `${missed.length} ${missed.length > 1 ? 'queries' : 'query'} fetched after page load, ` +
        `not covered by route prefetch: ${missed.join(', ')}`
    )
  }

  const unsubscribeCache = queryClient.getQueryCache().subscribe((event) => {
    if (event.type === 'updated' && event.action.type === 'fetch') {
      const hash = event.query.queryHash
      if (!coveredHashes.has(hash) && !event.query.meta?.[CLIENT_ONLY_QUERY]) {
        coveredHashes.add(hash)
        missed.push(JSON.stringify(event.query.queryKey))
      }
    }
  })

  function disarm() {
    auditWindowOpen = false
    if (closeTimer) {
      clearTimeout(closeTimer)
      closeTimer = undefined
    }
    unsubscribeCache()
    unsubscribeRouter()
  }

  const unsubscribeRouter = router.subscribe((state) => {
    if (state.location !== initialLocation) {
      console.info(
        `[prefetch-audit] route "${currentRouteName(router)}" changed before settling — discarding`
      )
      disarm()
    }
  })

  closeTimer = setTimeout(() => {
    disarm()
    flush()
  }, SETTLE_DEBOUNCE_MS)
}
