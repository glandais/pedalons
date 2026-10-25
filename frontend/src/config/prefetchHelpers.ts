import type { QueryClient } from '@tanstack/react-query'
import {
  getGetTeamQueryKey,
  getListTeamsQueryKey,
  prefetchListTeamsQuery,
} from '@/api/endpoints/teams/teams'
import { prefetchGetRoutesBulkQuery } from '@/api/endpoints/routes/routes'
import { prefetchListTeamTagsQuery } from '@/api/endpoints/tags/tags'
import { ROUTES_BULK_MAX_SLUGS } from '@/hooks/useRoutesBulk'
import { COMMENT_LIST_OPTIONS } from '@/hooks/useComments'
import type { MembershipFilterValue } from '@/hooks/filters/membership'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { MinRole } from '@/api/dto'
import type {
  SortDirection,
  TagTarget,
  TeamDetailDto,
  TeamListResponse,
  GetRoutesBulkParams,
} from '@/api/dto'

/**
 * The prefetch primitives shared by `routes.config.ts` and the pages' own data companions (e.g.
 * `pages/ride/rideDetailData.ts`). Their own module rather than exports of `routes.config.ts`,
 * which imports those companions — the other direction would be a cycle.
 */

/**
 * Whether the reader sees a team's member-only content (comments, the team calendar): a member, or
 * a platform admin — whose `team.role` is their real membership, null outside it (docs/LEDGER_*.md
 * API-137). Reads the team query prefetched just before, like the pages' `isMember || isPlatformAdmin`.
 */
export function readsMemberContent(queryClient: QueryClient, teamSlug: string): boolean {
  const team = queryClient.getQueryData<TeamDetailDto>(getGetTeamQueryKey(teamSlug))
  return !!team?.role || selectIsPlatformAdmin(useAuthStore.getState())
}

/**
 * Comments are member-only on rides/trips/posts/routes (each detail page's own `isMember`, from
 * the team's `role`) — resolved from the team query prefetched just before calling this, same
 * shape `useComments` builds. Skipped entirely for a non-member, matching what the page renders.
 */
export async function prefetchMemberComments(
  queryClient: QueryClient,
  teamSlug: string,
  entitySlug: string,
  listComments: (
    teamSlug: string,
    entitySlug: string,
    params: { page: number; size: number; sort: SortDirection }
  ) => Promise<unknown>,
  getQueryKey: (teamSlug: string, entitySlug: string) => readonly unknown[]
) {
  if (!readsMemberContent(queryClient, teamSlug)) return

  await queryClient.prefetchInfiniteQuery({
    queryKey: [...getQueryKey(teamSlug, entitySlug), COMMENT_LIST_OPTIONS],
    queryFn: ({ pageParam }: { pageParam: number }) =>
      listComments(teamSlug, entitySlug, { page: pageParam, ...COMMENT_LIST_OPTIONS }),
    initialPageParam: 0,
  })
}

/**
 * Mirrors `useMembershipDefault` exactly, probe included: signed in with at least one team, the
 * cross-team listings default to `member`; anonymous, or signed in with no team, to `all`.
 *
 * Returns the page's own filter value rather than a `MinRole`, because that is what feeds the
 * filter schema — the default only applies when the URL doesn't spell `membership` out, and a
 * shared link generally does (`MEMBERSHIP_ALWAYS_SERIALIZE`).
 */
export async function resolveMembershipDefault(
  queryClient: QueryClient
): Promise<MembershipFilterValue> {
  if (!useAuthStore.getState().isAuthenticated) return 'all'
  const membershipParams = { minRole: MinRole.MEMBER, page: 0, size: 1 }
  await prefetchListTeamsQuery(queryClient, membershipParams)
  const teams = queryClient.getQueryData<TeamListResponse>(getListTeamsQueryKey(membershipParams))
  return teams && teams.total > 0 ? 'member' : 'all'
}

/**
 * A list route prefetches the window `usePaginatedQuery` reads: the page the URL asks for, plus
 * the neighbours it fetches ahead on the client (next, and previous when there is one). Leaving
 * one out doesn't lose the data, it just moves the round trip back after hydration — which is
 * exactly what the prefetch audit (`e2e/routes-render.e2e.ts`) reports as a gap.
 */
export async function prefetchPageWindow<P extends { page: number }>(
  params: P,
  run: (pageParams: P) => Promise<unknown>
) {
  const pages = [params.page, params.page + 1, ...(params.page > 0 ? [params.page - 1] : [])]
  await Promise.all(pages.map((page) => run({ ...params, page })))
}

/** Mirrors `useRoutesBulk`'s own chunking against `ROUTES_BULK_MAX_SLUGS` so the query keys match. */
export async function prefetchRoutesBulkChunked(
  queryClient: QueryClient,
  teamSlug: string,
  slugs: string[],
  params?: Omit<GetRoutesBulkParams, 'slug'>
) {
  const dedupedSlugs = Array.from(new Set(slugs)).sort()
  if (dedupedSlugs.length === 0) return

  await Promise.all(
    Array.from({ length: Math.ceil(dedupedSlugs.length / ROUTES_BULK_MAX_SLUGS) }, (_, i) =>
      dedupedSlugs.slice(i * ROUTES_BULK_MAX_SLUGS, (i + 1) * ROUTES_BULK_MAX_SLUGS)
    ).map((slugChunk) =>
      prefetchGetRoutesBulkQuery(queryClient, teamSlug, { ...params, slug: slugChunk })
    )
  )
}

/**
 * A team's tags of one kind, on the key `TagFilter` reads (`useListTeamTags(teamSlug, { type })`),
 * so a dedicated list's tag filter is in the server render rather than popping in after hydration.
 */
export async function prefetchTeamTags(
  queryClient: QueryClient,
  teamSlug: string,
  type: TagTarget
): Promise<void> {
  await prefetchListTeamTagsQuery(queryClient, teamSlug, { type })
}
