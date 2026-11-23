import type { QueryClient } from '@tanstack/react-query'
import {
  getGetTeamDashboardQueryKey,
  prefetchGetTeamQuery,
  prefetchGetTeamDashboardQuery,
  useGetTeamDashboard,
} from '@/api/endpoints/teams/teams'
import {
  prefetchListInvitationsQuery,
  useListInvitations,
} from '@/api/endpoints/team-invitations/team-invitations'
import {
  prefetchCountPublicationsQuery,
  useCountPublications,
} from '@/api/endpoints/publications/publications'
import { InvitationStatus, PublicationType, type TeamDashboardDto } from '@/api/dto'
import { prefetchGetAvailableServicesQuery } from '@/api/endpoints/gps-services/gps-services'
import { useAuthStore } from '@/store/authStore'

/**
 * The one description of what the team's home (`team-detail`) reads: the dashboard
 * (`GET /api/teams/{slug}/dashboard`), for everyone since API-86 — a visitor gets its public part
 * (upcoming rides, latest posts, new routes), a member their own blocks on top. The former feed is
 * gone (ledger WEB-68): its addresses redirect (pages/team/teamLegacyRedirects.ts).
 *
 * Same contract as the other `…Data.ts` modules: `TeamHomePage` reads it through
 * {@link useTeamDashboardData}, the route's `prefetch` through {@link prefetchTeamHome}, on the
 * same query keys. Its own module so `routes.config.ts`, which imports it eagerly, does not pull
 * the page out of its lazy chunk.
 */

/**
 * The dashboard itself, once the team is known — an unknown or members-only team answers 404/403
 * here too, and the page tells those apart from the team's own query. The GPS services are read
 * by the « Envoyer vers » menu of a member's next rides (`useGpsConnections`).
 */
export function useTeamDashboardData(teamSlug: string, enabled: boolean) {
  const dashboard = useGetTeamDashboard(teamSlug, { query: { enabled } })
  return { dashboard }
}

/**
 * Server-side (and hover) counterpart of `TeamHomePage`: the team and its dashboard side by side
 * — the dashboard no longer waits for the team's `role`, it answers everyone. The GPS services
 * only matter to a signed-in reader (« Mes prochaines » is a member's block).
 */
export async function prefetchTeamHome(queryClient: QueryClient, teamSlug: string): Promise<void> {
  const signedIn = useAuthStore.getState().isAuthenticated
  await Promise.all([
    prefetchGetTeamQuery(queryClient, teamSlug),
    prefetchGetTeamDashboardQuery(queryClient, teamSlug).then(() =>
      prefetchFirstSteps(queryClient, teamSlug)
    ),
    signedIn ? prefetchGetAvailableServicesQuery(queryClient) : undefined,
  ])
}

/**
 * « Premières étapes » (docs/LEDGER_*.md WEB-195): what the checklist of a team administrator
 * needs beyond the dashboard, read only while a step is still open and the team says nothing yet —
 * a pending invitation when the team has a single member, a ride of any date (drafts and past ones
 * included) when none is upcoming. Derived from the dashboard alone, so the page and the prefetch
 * agree on which queries exist. The route step reads `team.routeCount`, which needs nothing more.
 */
export const FIRST_STEPS_INVITATIONS_PARAMS = {
  status: InvitationStatus.PENDING,
  page: 0,
  size: 1,
} as const
export const FIRST_STEPS_RIDES_PARAMS = { type: PublicationType.RIDE } as const

export function firstStepsReads(dashboard: TeamDashboardDto | undefined) {
  const team = dashboard?.team
  const admin = !!dashboard?.admin && !!team
  return {
    admin,
    invitations: admin && team.addMemberAllowed && team.memberCount <= 1,
    rides: admin && team.enableRides && team.enableRoutes && team.upcomingRideCount === 0,
  }
}

export function useFirstStepsData(teamSlug: string, dashboard: TeamDashboardDto | undefined) {
  const reads = firstStepsReads(dashboard)
  const invitations = useListInvitations(teamSlug, FIRST_STEPS_INVITATIONS_PARAMS, {
    query: { enabled: reads.invitations },
  })
  const rides = useCountPublications(teamSlug, FIRST_STEPS_RIDES_PARAMS, {
    query: { enabled: reads.rides },
  })
  return { reads, invitations, rides }
}

/** {@link useFirstStepsData}'s queries, once the dashboard is in the cache. */
export async function prefetchFirstSteps(queryClient: QueryClient, teamSlug: string) {
  const reads = firstStepsReads(
    queryClient.getQueryData<TeamDashboardDto>(getGetTeamDashboardQueryKey(teamSlug))
  )
  await Promise.all([
    reads.invitations
      ? prefetchListInvitationsQuery(queryClient, teamSlug, FIRST_STEPS_INVITATIONS_PARAMS)
      : undefined,
    reads.rides
      ? prefetchCountPublicationsQuery(queryClient, teamSlug, FIRST_STEPS_RIDES_PARAMS)
      : undefined,
  ])
}

/**
 * Which first steps are done. A step is absent when it does not apply: `invite` when the team may
 * not invite by e-mail, `ride` without both the rides and routes modules, `route` without routes.
 */
export interface FirstStepsState {
  invite?: boolean
  ride?: boolean
  route?: boolean
}

/**
 * The checklist's state for a team administrator, or `undefined` for anyone else and until what
 * it needs has loaded — a step never shows as open only because its query is still on its way.
 * Nothing is stored: each step reads the team as it is (a second member or a pending invitation,
 * a ride, a route).
 */
export function useFirstSteps(
  teamSlug: string,
  dashboard: TeamDashboardDto | undefined
): FirstStepsState | undefined {
  const { reads, invitations, rides } = useFirstStepsData(teamSlug, dashboard)
  const team = dashboard?.team
  if (!reads.admin || !team) return undefined
  if ((reads.invitations && invitations.isLoading) || (reads.rides && rides.isLoading)) {
    return undefined
  }
  return {
    invite: team.addMemberAllowed
      ? team.memberCount > 1 || (invitations.data?.total ?? 0) > 0
      : undefined,
    // A ride is created on a route: both modules, as the header's « Créer une sortie ».
    ride:
      team.enableRides && team.enableRoutes
        ? team.upcomingRideCount > 0 || (rides.data?.total ?? 0) > 0
        : undefined,
    route: team.enableRoutes ? team.routeCount > 0 : undefined,
  }
}
