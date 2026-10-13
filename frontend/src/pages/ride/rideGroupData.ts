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
import type { RideDto, RideGroupDto } from '@/api/dto'
import { Status } from '@/api/dto'
import { rideRouteSlugs, useRideDetailData, WEATHER_REQUEST } from './rideDetailData'

/**
 * The one description of what a ride group's page reads (`RideGroupPage`, route `ride-group`),
 * same contract as `rideDetailData.ts`, whose reads it *is*: the ride, its weather and the ride's
 * routes bulk, under the ride page's own query keys, so going from the ride to one of its groups
 * and back reads nothing twice. Only the group's participants are its own, their search and page
 * in the query string (`groupParticipantFilters.ts`).
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
