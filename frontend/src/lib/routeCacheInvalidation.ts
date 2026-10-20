import type { QueryClient } from '@tanstack/react-query'
import {
  getCountAllRoutesQueryKey,
  getCountRoutesQueryKey,
  getGetAllRoutesBoundsQueryKey,
  getGetRouteQueryKey,
  getGetRoutesBoundsQueryKey,
  getListAllRoutesQueryKey,
  getListRoutesQueryKey,
  getGetRoutesBulkQueryKey,
} from '@/api/endpoints/routes/routes'
import { invalidateTeamDashboard } from '@/lib/teamDashboardCache'

/**
 * Invalidates every cached view of a team's routes that a route mutation (create, update, delete,
 * undelete, slug change, GPX upload) can have changed: the team's routes list, count and map bounds,
 * the cross-team ones (`/api/routes`, which lists every team's routes), the team dashboard, the
 * single-route detail (when the mutation targets one route — pass its *previous* slug on a slug
 * change), and every `/routes/bulk` query for the team.
 *
 * Each path is its own first key element (`/api/teams/x/routes` does not prefix
 * `/api/teams/x/routes/count`), so every list-like key is named here; invalidating one without
 * params reaches all its filter variants.
 *
 * `/routes/bulk` (`getGetRoutesBulkQueryKey`) is keyed on its own params (slug set, geometry) —
 * a query key disjoint from the single-route key's prefix, so react-query's partial
 * matching never reaches it by invalidating the single-route key alone. A bulk query result can
 * hold any slug set (a ride's groups, a trip's stages, a map view), so there's no cheaper correct
 * granularity than invalidating every bulk query of the team — done here by invalidating the key
 * without params, which react-query partial-matches against every params variant.
 *
 * Call this from every route mutation's `onSuccess` instead of invalidating
 * `getGetRouteQueryKey`/`getListRoutesQueryKey` by hand, so a future mutation can't forget the
 * bulk key.
 */
export function invalidateRouteQueries(
  queryClient: QueryClient,
  teamSlug: string,
  routeSlug?: string
): void {
  if (routeSlug) {
    queryClient.invalidateQueries({ queryKey: getGetRouteQueryKey(teamSlug, routeSlug) })
  }
  queryClient.invalidateQueries({ queryKey: getListRoutesQueryKey(teamSlug) })
  queryClient.invalidateQueries({ queryKey: getCountRoutesQueryKey(teamSlug) })
  queryClient.invalidateQueries({ queryKey: getGetRoutesBoundsQueryKey(teamSlug) })
  queryClient.invalidateQueries({ queryKey: getListAllRoutesQueryKey() })
  queryClient.invalidateQueries({ queryKey: getCountAllRoutesQueryKey() })
  queryClient.invalidateQueries({ queryKey: getGetAllRoutesBoundsQueryKey() })
  queryClient.invalidateQueries({ queryKey: getGetRoutesBulkQueryKey(teamSlug) })
  // « Nouveaux parcours » and the rides-without-a-route tile.
  invalidateTeamDashboard(queryClient, teamSlug)
}
