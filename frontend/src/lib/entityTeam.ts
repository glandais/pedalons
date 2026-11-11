import type { QueryClient } from '@tanstack/react-query'
import { prefetchGetTeamQuery, useGetTeam } from '@/api/endpoints/teams/teams'
import type { TeamPublicationDto } from '@/api/dto'

/**
 * The team of an entity's page, read only when the entity says it may be (docs/LEDGER_*.md
 * WEB-166, plan §4.5): its embedded summary's `accessible` is true when `GET team` would answer the
 * reader. The public content of a private team is read by link with it false — the page then
 * renders from the summary and never asks for the team, which would only answer 404.
 *
 * So the team query waits for the entity: disabled until it is read, and for good when the team is
 * closed. A team already in the cache costs nothing; the route's prefetch reads it the same way
 * ({@link prefetchEntityTeam}), so the server render has it.
 */
export function useEntityTeam(
  teamSlug: string | undefined,
  summary: Pick<TeamPublicationDto, 'accessible'> | undefined
) {
  return useGetTeam(teamSlug!, { query: { enabled: !!teamSlug && !!summary?.accessible } })
}

/** Server-side counterpart of {@link useEntityTeam}: the team, only when the entity allows it. */
export async function prefetchEntityTeam(
  queryClient: QueryClient,
  teamSlug: string,
  summary: Pick<TeamPublicationDto, 'accessible'> | undefined
): Promise<void> {
  if (summary?.accessible) await prefetchGetTeamQuery(queryClient, teamSlug)
}
