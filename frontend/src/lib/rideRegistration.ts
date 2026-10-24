import type { QueryClient } from '@tanstack/react-query'
import {
  getListAllPublicationsQueryKey,
  getListPublicationsQueryKey,
} from '@/api/endpoints/publications/publications'
import { getListMyParticipationsQueryKey } from '@/api/endpoints/users/users'
import { getGetEventsQueryKey, getGetTeamEventsQueryKey } from '@/api/endpoints/calendar/calendar'
import { getGetTeamDashboardQueryKey } from '@/api/endpoints/teams/teams'

/**
 * Everything that shows whether the user rides, after they joined or left a ride — wherever they
 * did it from. The feeds carry the « J'y vais » badge and the « Je participe » filter, the home page
 * « Ma prochaine sortie », the team dashboard « Vos prochaines sorties » and the fill of each group,
 * the calendars their registration. Left out, each stayed stale until a
 * reload: leaving from the home card kept the badge on the feed right below it.
 */
export function invalidateRideRegistration(queryClient: QueryClient, teamSlug: string): void {
  void queryClient.invalidateQueries({ queryKey: getListAllPublicationsQueryKey() })
  void queryClient.invalidateQueries({ queryKey: getListPublicationsQueryKey(teamSlug) })
  void queryClient.invalidateQueries({ queryKey: getListMyParticipationsQueryKey() })
  void queryClient.invalidateQueries({ queryKey: getGetEventsQueryKey() })
  void queryClient.invalidateQueries({ queryKey: getGetTeamEventsQueryKey(teamSlug) })
  void queryClient.invalidateQueries({ queryKey: getGetTeamDashboardQueryKey(teamSlug) })
}
