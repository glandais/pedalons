import type { QueryClient } from '@tanstack/react-query'
import { prefetchEntityTeam, useEntityTeam } from '@/lib/entityTeam'
import {
  useGetRoute,
  getGetRouteQueryKey,
  prefetchGetRouteQuery,
  prefetchGetRouteUsagesQuery,
} from '@/api/endpoints/routes/routes'
import {
  listRouteComments,
  getListRouteCommentsQueryKey,
} from '@/api/endpoints/route-comments/route-comments'
import { prefetchGetAvailableServicesQuery } from '@/api/endpoints/gps-services/gps-services'
import { prefetchMemberComments } from '@/config/prefetchHelpers'
import { useElevationRefetchInterval } from '@/hooks/useElevationRefetchInterval'
import { useAuthStore } from '@/store/authStore'
import type { RouteDetailDto } from '@/api/dto'

/**
 * The one description of what the route detail screen reads, consumed two ways: `RouteDetailPage`
 * calls {@link useRouteDetailData} for the query results, the `route-detail` route in
 * `routes.config.ts` calls {@link prefetchRouteDetail} for the same data server-side. Same contract
 * as `pages/ride/rideDetailData.ts` — its own module so `routes.config.ts`, which imports it
 * eagerly, doesn't pull the page (or its lazy chunk) out of its bundle.
 *
 * `route-map` (`RouteFullscreenMapPage`) is a strict subset of this screen — team + route, no
 * usages, no comments, no GPS services — so it reuses the same two calls via
 * {@link useRouteMapData} / {@link prefetchRouteMap} instead of duplicating them.
 */

/**
 * Team + route only. Shared between `RouteDetailPage` (which layers usages and comments on top)
 * and `RouteFullscreenMapPage` (which needs nothing else).
 */
export function useRouteTeamAndRoute(teamSlug?: string, routeSlug?: string) {
  const refetchInterval = useElevationRefetchInterval()
  const route = useGetRoute(teamSlug!, routeSlug!, {
    // Re-read while the HD elevation is still being computed (WEB-102).
    query: { enabled: !!teamSlug && !!routeSlug, refetchInterval },
  })
  // Behind the route, and only when it says the team answers the reader (docs/LEDGER_*.md
  // WEB-166): the pages render from its embedded summary.
  const team = useEntityTeam(teamSlug, route.data?.team)
  return { team, route }
}

/**
 * Every query `RouteDetailPage` itself owns, returned as the raw query results so the page keeps
 * using `.data` / `.isLoading` / `.error` / `.refetch` directly in its `QueryStateBoundary`.
 *
 * Route usages are deliberately absent: `RouteUsages` (rendered by the page) owns that query
 * itself, the same way comments and GPS export options are owned by the children that mount them.
 * All three are still covered by {@link prefetchRouteDetail}, on purpose — see its docblock.
 *
 * Auth also stays out: the page reads the route's `permissions`, not `useAuth()`, but the
 * prefetch's GPS-services gate still goes through `useAuthStore.getState()`, matching the split
 * documented in docs/SSR-data-loading.md.
 */
export function useRouteDetailData(teamSlug?: string, routeSlug?: string) {
  return useRouteTeamAndRoute(teamSlug, routeSlug)
}

/** Everything `RouteFullscreenMapPage` reads — team + route, nothing else. */
export function useRouteMapData(teamSlug?: string, routeSlug?: string) {
  return useRouteTeamAndRoute(teamSlug, routeSlug)
}

/**
 * Server-side counterpart of {@link useRouteDetailData}.
 *
 * It covers more than the hook does, on purpose: usages (`RouteUsages`), comments
 * (`CommentSection`) and GPS export options are fetched by children the page mounts, not by the
 * page itself — comments gated on membership, GPS services on being signed in, exactly as those
 * children gate themselves. Comments and the team run after the first wave for the same reason as
 * `rideDetailData.ts`'s: both are decided by the route just read (`permissions.canComment`,
 * `team.accessible`).
 */
export async function prefetchRouteDetail(
  queryClient: QueryClient,
  teamSlug: string,
  routeSlug: string
): Promise<void> {
  await Promise.all([
    prefetchGetRouteQuery(queryClient, teamSlug, routeSlug),
    prefetchGetRouteUsagesQuery(queryClient, teamSlug, routeSlug),
    useAuthStore.getState().isAuthenticated
      ? prefetchGetAvailableServicesQuery(queryClient)
      : Promise.resolve(queryClient),
  ])
  const route = queryClient.getQueryData<RouteDetailDto>(getGetRouteQueryKey(teamSlug, routeSlug))
  await Promise.all([
    prefetchEntityTeam(queryClient, teamSlug, route?.team),
    prefetchMemberComments(
      queryClient,
      teamSlug,
      routeSlug,
      listRouteComments,
      getListRouteCommentsQueryKey,
      route?.permissions.canComment
    ),
  ])
}

/** Server-side counterpart of {@link useRouteMapData} — team + route, no more. */
export async function prefetchRouteMap(
  queryClient: QueryClient,
  teamSlug: string,
  routeSlug: string
): Promise<void> {
  await prefetchGetRouteQuery(queryClient, teamSlug, routeSlug)
  const route = queryClient.getQueryData<RouteDetailDto>(getGetRouteQueryKey(teamSlug, routeSlug))
  await prefetchEntityTeam(queryClient, teamSlug, route?.team)
}
