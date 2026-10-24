import type { QueryClient } from '@tanstack/react-query'
import { prefetchGetTeamQuery } from '@/api/endpoints/teams/teams'
import {
  prefetchGetRideQuery,
  getGetRideQueryKey,
  prefetchGetRideWeatherQuery,
  prefetchGetRideParticipantsQuery,
} from '@/api/endpoints/rides/rides'
import { prefetchGetAvailableServicesQuery } from '@/api/endpoints/gps-services/gps-services'
import { prefetchRoutesBulkChunked } from '@/config/prefetchHelpers'
import { readUrlFilters } from '@/hooks/useUrlFilters'
import {
  groupParticipantFiltersAlias,
  groupParticipantFiltersSchema,
  groupParticipantsParams,
} from '@/hooks/filters/groupParticipantFilters'
import { useAuthStore } from '@/store/authStore'
import type { RideDto, RideGroupDto, WeatherLegDto } from '@/api/dto'
import { Status } from '@/api/dto'
import type { RouteParams } from '@/config/routes.types'
import { paths } from '@/config/paths'
import { hasWindForecast } from '@/lib/weatherOnRoute'
import {
  leavesGroupPage,
  prefetchRideMap,
  rideRouteSlugs,
  soloGroup,
  useRideDetailData,
  WEATHER_REQUEST,
} from './rideDetailData'

/**
 * The one description of what a ride group's page reads (`RideGroupPage`, route `ride-group`),
 * same contract as `rideDetailData.ts`, whose reads it *is*: the ride, its weather and the ride's
 * routes bulk, under the ride page's own query keys, so going from the ride to one of its groups
 * and back reads nothing twice. Only the group's participants are its own, their search and page
 * in the query string (`groupParticipantFilters.ts`).
 *
 * It also serves the group's fullscreen map (`RideGroupFullscreenMapPage`, route `ride-group-map`,
 * ledger WEB-117): same hook, and a prefetch of the same keys minus what only the page's children
 * read (participants, GPS services) — the solo ride's map's (`prefetchRideMap`) — one module, two
 * routes (docs/SSR-data-loading.md).
 */

/**
 * The group's page data: the ride page's reads, plus the group itself and its leg of the forecast
 * — both looked up by id, undefined for a group the ride no longer has (an old link after an edit).
 */
export function useRideGroupData(teamSlug?: string, rideSlug?: string, groupId?: string) {
  const data = useRideDetailData(teamSlug, rideSlug)
  const group = data.ride.data?.groups?.find((g) => g.id === groupId)
  const leg = data.weather.data?.legs.find((l) => !!groupId && l.groupId === groupId)
  return { ...data, group, leg }
}

/**
 * Server-side counterpart of {@link useRideGroupData}, in two phases like the ride's: the routes
 * bulk needs the ride's groups. The participants only need the URL, so they ride in the first.
 * No comments: they stay on the ride's page.
 */
export async function prefetchRideGroup(
  queryClient: QueryClient,
  teamSlug: string,
  rideSlug: string,
  groupId: string,
  url: URL
): Promise<void> {
  const filters = readUrlFilters(url.searchParams, {
    schema: groupParticipantFiltersSchema,
    alias: groupParticipantFiltersAlias,
  })
  await Promise.all([
    prefetchGetTeamQuery(queryClient, teamSlug),
    prefetchGetRideQuery(queryClient, teamSlug, rideSlug),
    prefetchGetRideWeatherQuery(queryClient, teamSlug, rideSlug, { request: WEATHER_REQUEST }),
    prefetchGetRideParticipantsQuery(
      queryClient,
      teamSlug,
      rideSlug,
      groupParticipantsParams(groupId, filters)
    ),
  ])

  const ride = queryClient.getQueryData<RideDto>(getGetRideQueryKey(teamSlug, rideSlug))
  await Promise.all([
    prefetchRoutesBulkChunked(queryClient, teamSlug, rideRouteSlugs(ride)),
    useAuthStore.getState().isAuthenticated
      ? prefetchGetAvailableServicesQuery(queryClient)
      : Promise.resolve(queryClient),
  ])
}

/**
 * Server-side counterpart of {@link useRideGroupData} for the group's fullscreen map: the ride
 * page's reads under their own keys, exactly those of the solo ride's map (`prefetchRideMap`) — a
 * group's map reads nothing of its own.
 */
export function prefetchRideGroupMap(
  queryClient: QueryClient,
  teamSlug: string,
  rideSlug: string
): Promise<void> {
  return prefetchRideMap(queryClient, teamSlug, rideSlug)
}

/**
 * The group's leg when its map offers the Météo mode (WEB-115): a forecast with at least one
 * point's weather, on a ride neither finished nor cancelled. One rule for the group's page and its
 * fullscreen map, which must agree: a link to the map in the Météo mode falls back on the grade
 * exactly when the page would.
 */
export function groupWindLeg(
  ride: RideDto,
  leg: WeatherLegDto | undefined
): WeatherLegDto | undefined {
  return !ride.finished && ride.status !== Status.CANCELLED && hasWindForecast(leg)
    ? leg
    : undefined
}

/**
 * The `ride-group` route's `dataRedirect` (ledger WEB-79): a ride with at most one group has no
 * group page — a solo ride's own page is its group's, and a group link to a ride without groups can
 * only be stale —, so the group's URL is replaced by the ride's, query string kept (`?q=`/`?p=` are
 * the same participants filters there). Reads only the ride `prefetchRideGroup` cached; without it
 * (a private team rendered anonymously), `undefined`, and `RideGroupPage` leaves on the client.
 */
export function rideGroupDataRedirect(
  queryClient: QueryClient,
  params: RouteParams,
  url: URL
): string | undefined {
  if (!params.teamSlug || !params.rideSlug) return undefined
  const ride = queryClient.getQueryData<RideDto>(
    getGetRideQueryKey(params.teamSlug, params.rideSlug)
  )
  if (!ride || !leavesGroupPage(ride)) return undefined
  return paths.ride(params.teamSlug, ride.slug) + url.search
}

/**
 * Where a group's map leaves to when its ride has no group page (WEB-79), `undefined` when it has
 * one: a solo ride's map is now its own (`ride-map`, WEB-118) — the same map, the same group, and the
 * mode the link asked for (`?color=`, kept) —, so a group map link shared before the group became
 * the only one still opens a map rather than the ride's page; a ride without groups has no group to
 * draw, so its page. One rule for the route's loader and the page's own `<Navigate>`.
 */
export function rideGroupMapLeavesTo(
  ride: RideDto,
  teamSlug: string,
  search: string
): string | undefined {
  if (!leavesGroupPage(ride)) return undefined
  return soloGroup(ride)
    ? paths.rideMap(teamSlug, ride.slug) + search
    : paths.ride(teamSlug, ride.slug)
}

/**
 * The `ride-group-map` route's `dataRedirect`: {@link rideGroupMapLeavesTo}, from the ride
 * `prefetchRideGroupMap` cached; without it, `undefined`, and the page leaves on the client.
 */
export function rideGroupMapDataRedirect(
  queryClient: QueryClient,
  params: RouteParams,
  url: URL
): string | undefined {
  if (!params.teamSlug || !params.rideSlug) return undefined
  const ride = queryClient.getQueryData<RideDto>(
    getGetRideQueryKey(params.teamSlug, params.rideSlug)
  )
  return ride ? rideGroupMapLeavesTo(ride, params.teamSlug, url.search) : undefined
}

/**
 * What a rider can do on this group, from what the server enforces at join (`RideService.joinGroup`):
 * one group per ride, a second join is refused (409 `ALREADY_REGISTERED`) and nobody is moved — so
 * a reader registered in another group is told so, never offered « Rejoindre ». « Quitter » stays
 * on a past ride, as on the ride's cards; a full group offers nothing but its badge.
 */
export type GroupAction = 'join' | 'leave' | 'registeredElsewhere' | 'none'

export function groupAction(ride: RideDto, group: RideGroupDto, isMember: boolean): GroupAction {
  if (group.registered) return 'leave'
  if (ride.registeredGroupId && ride.registeredGroupId !== group.id) return 'registeredElsewhere'
  if (group.full) return 'none'
  const canJoin = isMember && ride.status === Status.PUBLISHED && !ride.registered && !ride.finished
  return canJoin ? 'join' : 'none'
}

/** The ride's groups, the one the member is registered in first; the others keep their order. */
export function groupsRegisteredFirst(
  groups: RideGroupDto[],
  registeredGroupId: string | undefined | null
): RideGroupDto[] {
  const registered = groups.find((g) => g.id === registeredGroupId)
  return registered ? [registered, ...groups.filter((g) => g !== registered)] : groups
}
