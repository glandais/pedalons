import type { QueryClient } from '@tanstack/react-query'
import {
  useListTeams,
  prefetchListTeamsQuery,
  getListTeamsQueryKey,
} from '@/api/endpoints/teams/teams'
import { isSingleTeam } from '@/config/appConfig'
import { useAuth } from '@/hooks/useAuth'
import { MY_TEAMS_PARAMS } from '@/pages/home/homeFeedData'
import { useAuthStore } from '@/store/authStore'

/**
 * What the team header's switcher reads (docs/LEDGER_*.md WEB-111): the home's « my teams »
 * listing, the same query key, for a signed-in reader on a site with teams to switch between.
 * Read by `TeamSwitcher`, prefetched by every route that mounts `TeamLayout` — the team header
 * renders on the server with its menu, and the prefetch audit finds no gap.
 */
export function useTeamSwitcherTeams() {
  const { isAuthenticated } = useAuth()
  return useListTeams(MY_TEAMS_PARAMS, { query: { enabled: isAuthenticated && !isSingleTeam() } })
}

export async function prefetchTeamSwitcher(queryClient: QueryClient): Promise<void> {
  if (!useAuthStore.getState().isAuthenticated || isSingleTeam()) return
  await prefetchListTeamsQuery(queryClient, MY_TEAMS_PARAMS)
}

/** After joining or leaving a team: the switcher's (and the home's) memberships. */
export function invalidateTeamSwitcher(queryClient: QueryClient): Promise<void> {
  return queryClient.invalidateQueries({ queryKey: getListTeamsQueryKey(MY_TEAMS_PARAMS) })
}
