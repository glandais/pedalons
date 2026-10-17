import type { QueryClient } from '@tanstack/react-query'
import { useGetTeam, prefetchGetTeamQuery } from '@/api/endpoints/teams/teams'
import {
  useGetTrip,
  prefetchGetTripQuery,
  getGetTripQueryKey,
  useGetTripWeather,
  prefetchGetTripWeatherQuery,
} from '@/api/endpoints/trips/trips'
import { useElevationRefetchInterval } from '@/hooks/useElevationRefetchInterval'
import { TRIP_WEATHER_REQUEST } from './tripDetailData'
import { useGetRoute, prefetchGetRouteQuery } from '@/api/endpoints/routes/routes'
import { prefetchGetAvailableServicesQuery } from '@/api/endpoints/gps-services/gps-services'
import {
  listTripStageComments,
  getListTripStageCommentsQueryKey,
} from '@/api/endpoints/trip-stage-comments/trip-stage-comments'
import { prefetchMemberComments } from '@/config/prefetchHelpers'
import { useAuthStore } from '@/store/authStore'
import type { TripDto } from '@/api/dto'

/**
 * The one description of what the stage detail screen reads, consumed two ways:
 * `StageDetailPage` calls {@link useStageDetailData} for the query results, the `stage-detail`
 * route in `routes.config.ts` calls {@link prefetchStageDetail} for the same data server-side.
 * Same contract as `pages/ride/rideDetailData.ts` — its own module so `routes.config.ts`, which
 * imports it eagerly, doesn't pull the page out of its lazy chunk.
 *
 * The interesting derivation is the stage's route slug: it only exists inside the parent trip's
 * `stages` array, so both the page and the prefetch have to look it up the *same* way — one
 * `.find(s => s.slug === stageSlug)` away from `trip.stages`. Divergence here would server-render
 * the wrong route, or none.
 */

/**
 * The route slug for a given stage, looked up inside its parent trip's own stages. Undefined when
 * the trip hasn't resolved yet, the stage doesn't exist, or the stage has no route.
 */
export function stageRouteSlug(
  trip: TripDto | undefined,
  stageSlug: string | undefined
): string | undefined {
  return trip?.stages?.find((s) => s.slug === stageSlug)?.route?.slug
}

/**
 * Every query `StageDetailPage` itself owns, returned as the raw query results so the page keeps
 * using `.data` / `.isLoading` / `.error` / `.refetch` directly.
 *
 * Auth deliberately stays out: the page reads it through `useAuth()`, the prefetch through
 * `useAuthStore.getState()` (the server can't use the hook), so no shared hook can hold it.
 */
export function useStageDetailData(teamSlug?: string, tripSlug?: string, stageSlug?: string) {
  const team = useGetTeam(teamSlug!, { query: { enabled: !!teamSlug } })
  const trip = useGetTrip(teamSlug!, tripSlug!, {
    query: { enabled: !!teamSlug && !!tripSlug },
  })

  const routeSlug = stageRouteSlug(trip.data, stageSlug)

  // `routeSlug ?? ''` keeps the hook call unconditional (consistent hook order); `enabled` is what
  // actually gates the fetch.
  const refetchInterval = useElevationRefetchInterval()
  const route = useGetRoute(teamSlug!, routeSlug ?? '', {
    query: { enabled: !!teamSlug && !!routeSlug, refetchInterval },
  })

  // The trip's weather, of which the page shows this stage's leg (docs/LEDGER_*.md API-76).
  const weather = useGetTripWeather(teamSlug!, tripSlug!, {
    query: { enabled: !!teamSlug && !!tripSlug },
    request: TRIP_WEATHER_REQUEST,
  })

  return { team, trip, route, routeSlug, weather }
}

/**
 * Server-side counterpart of {@link useStageDetailData}, in two phases: the route slug only exists
 * once the trip query has resolved into the cache.
 *
 * It covers more than the hook does, on purpose: GPS export options are fetched by a child the
 * page mounts (the route's export menu), authenticated-only, resolved the same way as
 * route-detail's own prefetch; the stage's comments by `CommentSection`, members only, as on the
 * trip.
 */
export async function prefetchStageDetail(
  queryClient: QueryClient,
  teamSlug: string,
  tripSlug: string,
  stageSlug: string
): Promise<void> {
  await Promise.all([
    prefetchGetTeamQuery(queryClient, teamSlug),
    prefetchGetTripQuery(queryClient, teamSlug, tripSlug),
    prefetchGetTripWeatherQuery(queryClient, teamSlug, tripSlug, { request: TRIP_WEATHER_REQUEST }),
  ])
  const trip = queryClient.getQueryData<TripDto>(getGetTripQueryKey(teamSlug, tripSlug))
  const routeSlug = stageRouteSlug(trip, stageSlug)
  await Promise.all([
    routeSlug
      ? prefetchGetRouteQuery(queryClient, teamSlug, routeSlug)
      : Promise.resolve(queryClient),
    useAuthStore.getState().isAuthenticated
      ? prefetchGetAvailableServicesQuery(queryClient)
      : Promise.resolve(queryClient),
    prefetchMemberComments(
      queryClient,
      teamSlug,
      stageSlug,
      listTripStageComments,
      getListTripStageCommentsQueryKey
    ),
  ])
}
