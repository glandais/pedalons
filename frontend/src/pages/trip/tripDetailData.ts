import { LIST_REQUEST } from '@/lib/listQuery'
import type { QueryClient } from '@tanstack/react-query'
import { prefetchEntityTeam, useEntityTeam } from '@/lib/entityTeam'
import {
  useGetTrip,
  prefetchGetTripQuery,
  getGetTripQueryKey,
  useGetTripWeather,
  prefetchGetTripWeatherQuery,
  getGetTripWeatherQueryKey,
  prefetchGetTripParticipantsQuery,
} from '@/api/endpoints/trips/trips'
import {
  listTripComments,
  getListTripCommentsQueryKey,
} from '@/api/endpoints/trip-comments/trip-comments'
import { prefetchMemberComments, prefetchRoutesBulkChunked } from '@/config/prefetchHelpers'
import { readUrlFilters } from '@/hooks/useUrlFilters'
import {
  groupParticipantFiltersAlias,
  groupParticipantFiltersSchema,
  participantsPageParams,
} from '@/hooks/filters/groupParticipantFilters'
import type { TripDto } from '@/api/dto'
import { prefetchGetAvailableServicesQuery } from '@/api/endpoints/gps-services/gps-services'
import { useAuthStore } from '@/store/authStore'

/**
 * The one description of what the trip detail screen reads, consumed two ways: `TripDetailPage`
 * calls {@link useTripDetailData} for the query results, the `trip-detail` route in
 * `routes.config.ts` calls {@link prefetchTripDetail} for the same data server-side. Describing it
 * twice is what this file exists to prevent: a divergence doesn't break anything visibly, it just
 * yields a different query key, so the client refetches after hydration and only
 * the prefetch audit of
 * `e2e/routes-render.e2e.ts` notices.
 *
 * Its own module rather than exports of `TripDetailPage.tsx`: `routes.config.ts` is imported
 * eagerly and must not pull the page (or the lazily-loaded `RoutesMapView`) out of its own chunk
 * (same contract as `pages/ride/rideDetailData.ts`).
 */

/**
 * The route slug(s) `RoutesMapView` fetches for this trip: the trip's own `routeSlug` for a
 * single-stage trip, otherwise every stage's route slug. Unlike `rideRouteSlugs`, this isn't
 * deduped/sorted here — `prefetchRoutesBulkChunked` does that itself, and so does `RoutesMapView`
 * client-side (it derives its own `dedupedSlugs` from the same `routeSlug`-bearing items before
 * calling `useRoutesBulk`) — both land on the same final slug set.
 */
export function tripRouteSlugs(trip: TripDto | undefined): string[] {
  if (!trip) return []
  return trip.routeSlug
    ? [trip.routeSlug]
    : (trip.stages ?? []).flatMap((stage) => (stage.route?.slug ? [stage.route.slug] : []))
}

/**
 * The weather's request options, one object for the hooks and the prefetches of the trip and the
 * stage pages. No toast: the blocks say « unavailable, retry » in place, as for a ride.
 */
export const TRIP_WEATHER_REQUEST = { skipErrorToast: true } as const

/**
 * After the trip changes (stages, their times, speeds or routes, status), its forecast reads
 * different passages: the weather is its own query key (`…/weather` is not a prefix match of the
 * trip's), so it is invalidated explicitly, next to the trip.
 */
export function invalidateTripWeather(
  queryClient: QueryClient,
  teamSlug: string,
  tripSlug: string
): Promise<void> {
  return queryClient.invalidateQueries({ queryKey: getGetTripWeatherQueryKey(teamSlug, tripSlug) })
}

/**
 * Every query `TripDetailPage` itself owns, returned as the raw query results so the page keeps
 * using `.data` / `.isLoading` / `.error` / `.refetch` directly in its `QueryStateBoundary`.
 *
 * The routes-bulk fetch for the map is deliberately not here: `TripDetailPage` only builds the
 * `MapRouteItem[]` list (id/name/routeSlug) it hands to `RoutesMapView`, which owns the
 * `useRoutesBulk` call itself — same split as the prefetch, which covers it as data fetched by a
 * mounted child, not by the page.
 *
 * Auth deliberately stays out: the page reads it through `useAuth()`, the prefetch through
 * `useAuthStore.getState()` (the server can't use the hook), so no shared hook can hold it.
 */
export function useTripDetailData(teamSlug?: string, tripSlug?: string) {
  const trip = useGetTrip(teamSlug!, tripSlug!, {
    query: { enabled: !!teamSlug && !!tripSlug },
  })
  // Behind the trip, only when it says the team answers the reader (docs/LEDGER_*.md WEB-166).
  const team = useEntityTeam(teamSlug, trip.data?.team)
  // Each stage card's weather line (docs/LEDGER_*.md API-76).
  const weather = useGetTripWeather(teamSlug!, tripSlug!, {
    query: { enabled: !!teamSlug && !!tripSlug },
    request: TRIP_WEATHER_REQUEST,
  })

  return { team, trip, weather }
}

/**
 * Server-side counterpart of {@link useTripDetailData}, in two phases: the routes bulk needs the
 * trip's own `routeSlug`/stages, which only exist once the trip query has resolved into the cache.
 *
 * It covers more than the hook does, on purpose: comments are fetched by `CommentSection`, and the
 * map's routes by `RoutesMapView` — both children `TripDetailPage` mounts, not the page itself.
 * Comments are additionally conditional on the trip's `permissions.canComment`, and the
 * participants on its `canSeeParticipants`, as are the participants `ParticipantsSection` lists, at the search and
 * page the URL asks for (`?q=`/`?p=`) — the ride page's rule (docs/LEDGER_*.md WEB-155).
 */
export async function prefetchTripDetail(
  queryClient: QueryClient,
  teamSlug: string,
  tripSlug: string,
  url: URL
): Promise<void> {
  await Promise.all([
    prefetchGetTripQuery(queryClient, teamSlug, tripSlug),
    // Read from the server's cache only, never the provider: safe to prefetch.
    prefetchGetTripWeatherQuery(queryClient, teamSlug, tripSlug, { request: TRIP_WEATHER_REQUEST }),
  ])

  const trip = queryClient.getQueryData<TripDto>(getGetTripQueryKey(teamSlug, tripSlug))
  const filters = readUrlFilters(url.searchParams, {
    schema: groupParticipantFiltersSchema,
    alias: groupParticipantFiltersAlias,
  })
  await Promise.all([
    // Only when the trip says the team answers the reader (docs/LEDGER_*.md WEB-166).
    prefetchEntityTeam(queryClient, teamSlug, trip?.team),
    prefetchMemberComments(
      queryClient,
      teamSlug,
      tripSlug,
      listTripComments,
      getListTripCommentsQueryKey,
      trip?.permissions.canComment
    ),
    prefetchRoutesBulkChunked(queryClient, teamSlug, tripRouteSlugs(trip)),
    // The stage cards' route actions (« Envoyer vers… ») read the services for a signed-in reader,
    // as a ride's group cards do (docs/LEDGER_*.md WEB-155).
    useAuthStore.getState().isAuthenticated
      ? prefetchGetAvailableServicesQuery(queryClient)
      : Promise.resolve(queryClient),
    (trip?.participantCount ?? 0) > 0 && trip?.permissions.canSeeParticipants
      ? prefetchGetTripParticipantsQuery(
          queryClient,
          teamSlug,
          tripSlug,
          participantsPageParams(filters.search, filters.page),
          { request: LIST_REQUEST }
        )
      : Promise.resolve(queryClient),
  ])
}
