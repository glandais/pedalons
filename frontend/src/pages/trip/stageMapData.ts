import type { QueryClient } from '@tanstack/react-query'
import { useGetTeam, prefetchGetTeamQuery } from '@/api/endpoints/teams/teams'
import {
  useGetTrip,
  prefetchGetTripQuery,
  getGetTripQueryKey,
  useGetTripWeather,
  prefetchGetTripWeatherQuery,
} from '@/api/endpoints/trips/trips'
import { useGetRoute, prefetchGetRouteQuery } from '@/api/endpoints/routes/routes'
import { stageRouteSlug } from './stageDetailData'
import { TRIP_WEATHER_REQUEST } from './tripDetailData'
import type { TripDto } from '@/api/dto'

/**
 * The one description of what the stage fullscreen map screen reads, consumed two ways:
 * `StageFullscreenMapPage` calls {@link useStageMapData} for the query results, the `stage-map`
 * route in `routes.config.ts` calls {@link prefetchStageMap} for the same data server-side. Same
 * contract as `pages/route/routeDetailData.ts`'s `route-map` — a strict subset of `stage-detail`
 * (team + trip + the trip's weather + the stage's route, no GPS export options, no comments), so it
 * reuses {@link stageRouteSlug} from `stageDetailData.ts` instead of re-deriving the lookup, and the
 * weather's request options of `tripDetailData.ts` (same key as the stage's page). The weather
 * feeds the stage's Météo mode (ledger WEB-118). Public route: no team-scoped auth gate,
 * unconditional prefetch.
 */

/**
 * Every query `StageFullscreenMapPage` itself owns, returned as the raw query results so the page
 * keeps using `.data` / `.isLoading` directly.
 */
export function useStageMapData(teamSlug?: string, tripSlug?: string, stageSlug?: string) {
  const team = useGetTeam(teamSlug!, { query: { enabled: !!teamSlug } })
  const trip = useGetTrip(teamSlug!, tripSlug!, {
    query: { enabled: !!teamSlug && !!tripSlug },
  })

  const routeSlug = stageRouteSlug(trip.data, stageSlug)

  // `routeSlug ?? ''` keeps the hook call unconditional (consistent hook order); `enabled` is what
  // actually gates the fetch.
  const route = useGetRoute(teamSlug!, routeSlug ?? '', {
    query: { enabled: !!teamSlug && !!routeSlug },
  })

  // The trip's weather, of which the map shows this stage's leg in the Météo mode (WEB-118).
  const weather = useGetTripWeather(teamSlug!, tripSlug!, {
    query: { enabled: !!teamSlug && !!tripSlug },
    request: TRIP_WEATHER_REQUEST,
  })

  return { team, trip, route, routeSlug, weather }
}

/**
 * Server-side counterpart of {@link useStageMapData}, in two phases like `stageDetailData.ts`'s
 * `prefetchStageDetail`: the route slug only exists once the trip query has resolved into the
 * cache; the weather only needs the slugs, so it rides in the first. No GPS export options here —
 * this screen mounts no export menu, unlike stage detail. The colour mode (`?color=`) reads nothing.
 */
export async function prefetchStageMap(
  queryClient: QueryClient,
  teamSlug: string,
  tripSlug: string,
  stageSlug: string
): Promise<void> {
  await Promise.all([
    prefetchGetTeamQuery(queryClient, teamSlug),
    prefetchGetTripQuery(queryClient, teamSlug, tripSlug),
    // Read from the server's cache only, never the provider: safe to prefetch.
    prefetchGetTripWeatherQuery(queryClient, teamSlug, tripSlug, { request: TRIP_WEATHER_REQUEST }),
  ])
  const trip = queryClient.getQueryData<TripDto>(getGetTripQueryKey(teamSlug, tripSlug))
  const routeSlug = stageRouteSlug(trip, stageSlug)
  if (routeSlug) {
    await prefetchGetRouteQuery(queryClient, teamSlug, routeSlug)
  }
}
