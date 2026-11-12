import { useCallback, useMemo } from 'react'
import type { QueryClient } from '@tanstack/react-query'
import {
  useListTeams,
  listTeams,
  getListTeamsQueryKey,
  prefetchListTeamsQuery,
} from '@/api/endpoints/teams/teams'
import { prefetchListMyInvitationsQuery } from '@/api/endpoints/invitations/invitations'
import { useMembershipDefault } from '@/hooks/useMembershipDefault'
import { usePaginatedQuery } from '@/hooks/usePaginatedQuery'
import { useUrlFilters, readUrlFilters } from '@/hooks/useUrlFilters'
import {
  makeTeamFiltersSchema,
  teamFiltersAlias,
  teamFiltersAlwaysSerialize,
  teamApiParams,
} from '@/hooks/filters/teamFilters'
import { prefetchPageWindow, resolveMembershipDefault } from '@/config/prefetchHelpers'
import { useAuthStore } from '@/store/authStore'
import { LIST_QUERY, LIST_REQUEST } from '@/lib/listQuery'

/**
 * The one description of what the team list screen reads, consumed two ways: `TeamListPage` calls
 * {@link useTeamListData} for the query results, the `teams` route in `routes.config.ts` calls
 * {@link prefetchTeamList} for the same data server-side. Same contract as
 * `pages/route/routeListData.ts` — its own module so `routes.config.ts`, which imports it eagerly,
 * doesn't pull the page out of its lazy chunk.
 *
 * The filter *schema itself* is what makes this trickier than a plain filtered list: `membership`'s
 * default depends on whether the visitor belongs to a team, so the schema can't be built until that
 * probe resolves. The page probes via `useMembershipDefault` (a `useListTeams` call), the prefetch
 * via `resolveMembershipDefault` (documented as mirroring it exactly, probe included) — two
 * functions rather than one, because the client reads it through a hook and the server through a
 * `QueryClient` with no hook available; see `resolveMembershipDefault`'s own docblock. Getting the
 * mirroring wrong doesn't error, it just makes a signed-in visitor's first real query miss the SSR
 * cache: a member sees the wrong-shaped list cached, a non-member fires the optimistic "member"
 * guess and then a correcting "all" fetch — exactly the double round trip this file exists to avoid.
 */

/**
 * The team's own list: the filtered page the URL asks for, and the neighbouring pages
 * `usePaginatedQuery` fetches ahead. Returns the membership default and the filter state as
 * `useUrlFilters` gives it (the page needs the setters and the raw `filters`) plus the raw query
 * results, so the page keeps reading `.data` / `.isLoading` / `.error` directly.
 *
 * The pending-invitations banner is deliberately left out: it's a child component
 * (`PendingInvitationsBanner`) with its own `useListMyInvitations` call, not something this page
 * owns — mirroring `rideDetailData.ts`'s treatment of comments and GPS services.
 */
export function useTeamListData() {
  const membershipDefault = useMembershipDefault()
  const schema = useMemo(() => makeTeamFiltersSchema(membershipDefault), [membershipDefault])
  const { filters, setFilters } = useUrlFilters({
    schema,
    alias: teamFiltersAlias,
    alwaysSerialize: teamFiltersAlwaysSerialize,
  })

  const apiParams = useMemo(() => teamApiParams(filters), [filters])
  const teams = useListTeams(apiParams, { query: LIST_QUERY, request: LIST_REQUEST })

  // The neighbouring pages, on the same key `prefetchPageWindow` primes server-side.
  const prefetchPage = useCallback(
    (page: number) => ({
      queryKey: getListTeamsQueryKey({ ...apiParams, page }),
      queryFn: () => listTeams({ ...apiParams, page }, LIST_REQUEST),
    }),
    [apiParams]
  )
  const { totalPages } = usePaginatedQuery({
    page: filters.page,
    pageSize: filters.size,
    totalItems: teams.data?.total ?? 0,
    prefetchPage,
  })

  return { membershipDefault, filters, setFilters, teams, totalPages }
}

/**
 * Server-side counterpart of {@link useTeamListData}: the invitations banner's own query (signed
 * in only — matches `PendingInvitationsBanner`'s `enabled: isAuthenticated`), then the same filters,
 * read from the request's query string through `resolveMembershipDefault` instead of
 * `useMembershipDefault`.
 */
export async function prefetchTeamList(queryClient: QueryClient, url: URL): Promise<void> {
  if (useAuthStore.getState().isAuthenticated) {
    await prefetchListMyInvitationsQuery(queryClient)
  }
  const filters = readUrlFilters(url.searchParams, {
    schema: makeTeamFiltersSchema(await resolveMembershipDefault(queryClient)),
    alias: teamFiltersAlias,
  })
  await prefetchPageWindow(teamApiParams(filters), (p) =>
    prefetchListTeamsQuery(queryClient, p, { request: LIST_REQUEST })
  )
}
