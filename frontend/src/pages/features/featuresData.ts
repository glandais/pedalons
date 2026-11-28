import type { QueryClient } from '@tanstack/react-query'
import { useLocalStorage } from '@mantine/hooks'
import type { TeamDetailDto } from '@/api/dto'
import { useListTeams, prefetchListTeamsQuery } from '@/api/endpoints/teams/teams'
import { CREATE_TEAM_STORAGE_KEY } from '@/components/home/memberHomeHelpers'
import { useAuth } from '@/hooks/useAuth'
import { teamAccess } from '@/lib/teamAccess'
import { MY_TEAMS_PARAMS } from '@/pages/home/homeFeedData'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'

/**
 * The team whose generator the features page's hero opens (docs/LEDGER_*.md WEB-221): among the
 * reader's teams, those where they may generate (routes and planner on, organizer or platform admin);
 * the one last picked on the member home when it is one of them, else the first. Undefined for a
 * visitor, while the listing loads, or when no team qualifies.
 */
export function useGeneratorTeam(): { team: TeamDetailDto | undefined; isPending: boolean } {
  const { isAuthenticated } = useAuth()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const [storedSlug] = useLocalStorage<string | null>({
    key: CREATE_TEAM_STORAGE_KEY,
    defaultValue: null,
  })
  const { data, isPending } = useListTeams(MY_TEAMS_PARAMS, {
    query: { enabled: isAuthenticated },
  })
  const eligible = (data?.teams ?? []).filter(
    (team) =>
      team.enableRoutes && team.enableRoutePlanner && teamAccess(team, isPlatformAdmin).isOrganizer
  )
  return {
    team: eligible.find((team) => team.slug === storedSlug) ?? eligible[0],
    isPending: isAuthenticated && isPending,
  }
}

/** The route's prefetch: the listing, for a signed-in reader only (anonymous SSR fetches nothing). */
export async function prefetchFeatures(queryClient: QueryClient): Promise<void> {
  if (!useAuthStore.getState().isAuthenticated) return
  await prefetchListTeamsQuery(queryClient, MY_TEAMS_PARAMS)
}
