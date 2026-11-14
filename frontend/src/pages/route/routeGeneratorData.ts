import type { QueryClient } from '@tanstack/react-query'
import { useGetTeam } from '@/api/endpoints/teams/teams'
import { useCountRoutes, prefetchCountRoutesQuery } from '@/api/endpoints/routes/routes'
import { useListPlaces, prefetchListPlacesQuery } from '@/api/endpoints/places/places'
import { SurfaceType } from '@/api/dto'
import type { GeoPoint, ListPlacesParams, PlaceDetailDto } from '@/api/dto'

/**
 * The one description of what `RouteGeneratorPage` reads, consumed two ways: the page calls
 * {@link useRouteGeneratorData}, the `route-generate` route in `routes.config.ts` calls
 * {@link prefetchRouteGenerator} (ledger `WEB-179`). The team itself is covered by the
 * `teamScopedPrefetch` wrapper there.
 *
 * <p>The three counts decide the default type of the proposals (the team's most numerous kind of
 * route). The team's places offer the starts and ends to pick from a list, besides the team's own
 * location and a click on the map. The generation itself is a POST under a rate limit: it is client-only, never prefetched
 * (`useRouteGenerator`).
 */

/** The kinds counted, in the order that breaks a tie. `MIXED` is not a kind to generate. */
export const GENERATOR_COUNT_TYPES = [
  SurfaceType.ROAD,
  SurfaceType.GRAVEL,
  SurfaceType.MTB,
] as const

export function useGeneratorTypeCounts(teamSlug?: string) {
  const enabled = { query: { enabled: !!teamSlug } }
  const road = useCountRoutes(teamSlug!, { surfaceType: SurfaceType.ROAD }, enabled)
  const gravel = useCountRoutes(teamSlug!, { surfaceType: SurfaceType.GRAVEL }, enabled)
  const mtb = useCountRoutes(teamSlug!, { surfaceType: SurfaceType.MTB }, enabled)
  return {
    counts: { ROAD: road.data?.total, GRAVEL: gravel.data?.total, MTB: mtb.data?.total },
    // Settled, one way or the other: a failed count leaves ROAD as the default
    isPending: road.isPending || gravel.isPending || mtb.isPending,
  }
}

/**
 * One page of the team's places, filtered on the client: a team has a handful of them, and one
 * query serves both lists. Listing places is an organiser's right, like the generator itself.
 */
export const GENERATOR_PLACES_PARAMS: ListPlacesParams = { size: 100 }

/** A place that can be offered as a start or an end: it has a position. */
export interface GeneratorPlace {
  id: string
  name: string
  point: GeoPoint
}

function located(place: PlaceDetailDto): GeneratorPlace | null {
  const coordinates = place.geometry?.coordinates
  if (!coordinates || coordinates.length < 2) return null
  return { id: place.id, name: place.name, point: { lng: coordinates[0], lat: coordinates[1] } }
}

/** The team's places with a position, those marked as a start and those marked as an end. */
export function useGeneratorPlaces(teamSlug?: string) {
  const { data } = useListPlaces(teamSlug!, GENERATOR_PLACES_PARAMS, {
    query: { enabled: !!teamSlug },
  })
  const places = data?.places ?? []
  const pick = (keep: (place: PlaceDetailDto) => boolean) =>
    places.filter(keep).flatMap((place) => located(place) ?? [])
  return {
    startPlaces: pick((place) => place.startPlace),
    endPlaces: pick((place) => place.endPlace),
  }
}

export function useRouteGeneratorData(teamSlug?: string) {
  const team = useGetTeam(teamSlug!, { query: { enabled: !!teamSlug } })
  const typeCounts = useGeneratorTypeCounts(teamSlug)
  return { team, typeCounts }
}

export async function prefetchRouteGenerator(queryClient: QueryClient, teamSlug: string) {
  await Promise.all([
    ...GENERATOR_COUNT_TYPES.map((surfaceType) =>
      prefetchCountRoutesQuery(queryClient, teamSlug, { surfaceType })
    ),
    prefetchListPlacesQuery(queryClient, teamSlug, GENERATOR_PLACES_PARAMS),
  ])
}
