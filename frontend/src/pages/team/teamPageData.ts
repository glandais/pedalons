import {
  useGetPage,
  prefetchGetPageQuery,
  getGetPageQueryKey,
} from '@/api/endpoints/team-pages/team-pages'
import { prefetchEntityTeam, useEntityTeam } from '@/lib/entityTeam'
import type { TeamPageDto } from '@/api/dto'
import type { QueryClient } from '@tanstack/react-query'

/**
 * The one description of what the team-page screen reads, consumed two ways:
 * `TeamPageDetailPage` calls {@link useTeamPageData} for the query results, the `team-page` route
 * in `routes.config.ts` calls {@link prefetchTeamPage} for the same two calls server-side.
 * Describing it twice is what this file exists to prevent — even though there is no derivation to
 * share here, a divergence would still be silent: it just yields a different query key, so the
 * client refetches after hydration and only the prefetch audit of
 * `e2e/routes-render.e2e.ts` notices.
 *
 * Its own module rather than exports of `TeamPageDetailPage.tsx`: `routes.config.ts` is imported
 * eagerly and must not pull the page out of its lazy chunk (same contract as
 * `pages/home/nextRideParams.ts` and `components/common/placeAutocompleteParams.ts`).
 */

/** Every query `TeamPageDetailPage` itself owns, returned as the raw query results. */
export function useTeamPageData(teamSlug?: string, pageSlug?: string) {
  const page = useGetPage(teamSlug!, pageSlug!, {
    query: { enabled: !!teamSlug && !!pageSlug },
  })
  // Behind the page, only when it says the team answers the reader (docs/LEDGER_*.md WEB-166): a
  // private team's public page is read by link, its team stays closed.
  const team = useEntityTeam(teamSlug, page.data?.team)

  return { team, page }
}

/** Server-side counterpart of {@link useTeamPageData}: the page, then its team when it allows. */
export async function prefetchTeamPage(
  queryClient: QueryClient,
  teamSlug: string,
  pageSlug: string
): Promise<void> {
  await prefetchGetPageQuery(queryClient, teamSlug, pageSlug)
  const page = queryClient.getQueryData<TeamPageDto>(getGetPageQueryKey(teamSlug, pageSlug))
  await prefetchEntityTeam(queryClient, teamSlug, page?.team)
}
