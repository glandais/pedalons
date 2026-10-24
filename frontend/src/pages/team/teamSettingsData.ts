import type { QueryClient } from '@tanstack/react-query'
import { getGetTeamQueryKey, prefetchGetTeamQuery, useGetTeam } from '@/api/endpoints/teams/teams'
import { prefetchGetTeamWebhookQuery } from '@/api/endpoints/team-webhook/team-webhook'
import type { TeamDetailDto } from '@/api/dto'
import { teamAccess } from '@/lib/teamAccess'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'

/**
 * `TeamSettingsPage` reads the team — the form, the slug change and the delete confirmation all
 * work off `team` from this one query, mutations included (mutations don't need a companion, they
 * aren't part of SSR) — and `TeamWebhookSettings` reads the team's webhook, on the first paint.
 * The team is covered server-side by the `teamScopedPrefetch` wrapper on the `team-settings` route
 * in `routes.config.ts`; {@link prefetchTeamSettings} adds the webhook.
 */
export function useTeamSettingsData(teamSlug: string | undefined) {
  return useGetTeam(teamSlug!, {
    query: { enabled: !!teamSlug },
  })
}

/**
 * The webhook `TeamWebhookSettings` reads, for a team admin only: the page sends anyone else back
 * to the team, and the endpoint refuses them. The team read is the wrapper's own, running
 * concurrently — React Query hands this call the same in-flight fetch, so it is not sent twice.
 */
export async function prefetchTeamSettings(queryClient: QueryClient, teamSlug: string) {
  await prefetchGetTeamQuery(queryClient, teamSlug)
  const team = queryClient.getQueryData<TeamDetailDto>(getGetTeamQueryKey(teamSlug))
  // A platform admin administers every team, member or not (docs/LEDGER_*.md API-137).
  if (!teamAccess(team, selectIsPlatformAdmin(useAuthStore.getState())).isAdmin) return
  await prefetchGetTeamWebhookQuery(queryClient, teamSlug)
}
