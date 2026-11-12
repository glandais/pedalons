import { useQueryClient } from '@tanstack/react-query'
import { getGetTeamQueryKey, getListTeamsQueryKey } from '@/api/endpoints/teams/teams'
import { getGetMembersQueryKey, useJoinTeam } from '@/api/endpoints/team-members/team-members'
import { invalidateTeamDashboard } from '@/lib/teamDashboardCache'
import { invalidateTeamSwitcher } from './teamSwitcherData'

/**
 * Joining a team, as the team page's button and the team card's do it (docs/LEDGER_*.md WEB-167,
 * R13): one call, then every view that shows the membership is refreshed — the team, its members,
 * the switcher, the dashboard and the team list, whose card then shows the role.
 */
export function useJoinTeamAction(teamSlug: string) {
  const queryClient = useQueryClient()
  const mutation = useJoinTeam()

  const join = () =>
    mutation.mutate(
      { teamSlug },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getGetTeamQueryKey(teamSlug) })
          queryClient.invalidateQueries({ queryKey: getGetMembersQueryKey(teamSlug) })
          queryClient.invalidateQueries({ queryKey: getListTeamsQueryKey() })
          invalidateTeamSwitcher(queryClient)
          invalidateTeamDashboard(queryClient, teamSlug)
        },
      }
    )

  return { join, isPending: mutation.isPending }
}
