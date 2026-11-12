import { useCallback } from 'react'
import type { QueryClient } from '@tanstack/react-query'
import {
  useGetMembers,
  getMembers,
  getGetMembersQueryKey,
  prefetchGetMembersQuery,
} from '@/api/endpoints/team-members/team-members'
import { prefetchListInvitationsQuery } from '@/api/endpoints/team-invitations/team-invitations'
import { InvitationStatus } from '@/api/dto'
import { teamMemberFiltersSchema, teamMemberFiltersAlias } from '@/hooks/filters/teamMemberFilters'
import { useUrlFilters, readUrlFilters } from '@/hooks/useUrlFilters'
import { usePaginatedQuery } from '@/hooks/usePaginatedQuery'
import { prefetchPageWindow } from '@/config/prefetchHelpers'
import { LIST_QUERY, LIST_REQUEST } from '@/lib/listQuery'

/**
 * `team-members` admin screen: the member list the page owns, plus the pending-invitations query
 * `TeamInvitationList` (a child it always mounts) owns. Both sides share the filter schema/alias
 * pair and the invitation params so the prefetch and the hooks land on the same query keys.
 *
 * The prefetch reads the request's query string through the same `teamMemberFilterOptions` the
 * page's `useUrlFilters` uses, then primes the page the URL asks for plus the neighbours
 * `usePaginatedQuery` fetches ahead — same shape as `routeListData.ts`'s `prefetchRouteList`. A
 * link into a filtered member list (`?search=…` or `?role=ADMIN`) now server-renders that list.
 */
export const teamMemberFilterOptions = {
  schema: teamMemberFiltersSchema,
  alias: teamMemberFiltersAlias,
} as const

/** Params for the pending-invitations query `TeamInvitationList` renders — part of its key. */
export const pendingInvitationsParams = { status: InvitationStatus.PENDING } as const

/**
 * The team's own member list: the filter state (the page needs the setters for its Select/
 * SearchInput controls), the raw `useGetMembers` result, and the neighbouring pages
 * `usePaginatedQuery` fetches ahead — same shape as `useRouteListData` in `routeListData.ts`.
 */
export function useTeamMembersData(teamSlug?: string) {
  const { filters, setFilters } = useUrlFilters(teamMemberFilterOptions)

  const members = useGetMembers(teamSlug!, filters, {
    query: { ...LIST_QUERY, enabled: !!teamSlug },
    request: LIST_REQUEST,
  })

  // The neighbouring pages, on the same key `prefetchPage`/`usePaginatedQuery` primes client-side.
  const prefetchPage = useCallback(
    (page: number) => ({
      queryKey: getGetMembersQueryKey(teamSlug!, { ...filters, page }),
      queryFn: () => getMembers(teamSlug!, { ...filters, page }, LIST_REQUEST),
    }),
    [teamSlug, filters]
  )
  const { totalPages } = usePaginatedQuery({
    page: filters.page,
    pageSize: filters.size,
    totalItems: members.data?.total ?? 0,
    prefetchPage,
  })

  return { filters, setFilters, members, totalPages }
}

/**
 * `team-directory` (the members' own page, `TeamDirectoryPage`): the same member list, without the
 * invitations — those are an admin's, and asking for them as anyone else is a 403.
 */
export async function prefetchTeamDirectory(
  queryClient: QueryClient,
  teamSlug: string,
  url: URL
): Promise<void> {
  const filters = readUrlFilters(url.searchParams, teamMemberFilterOptions)
  await prefetchPageWindow(filters, (p) =>
    prefetchGetMembersQuery(queryClient, teamSlug, p, { request: LIST_REQUEST })
  )
}

export async function prefetchTeamMembers(
  queryClient: QueryClient,
  teamSlug: string,
  url: URL
): Promise<void> {
  await Promise.all([
    prefetchTeamDirectory(queryClient, teamSlug, url),
    // Prefetched here because `TeamInvitationList` — a child the page always mounts — owns this
    // query itself; the page's own hooks never touch it.
    prefetchListInvitationsQuery(queryClient, teamSlug, pendingInvitationsParams),
  ])
}
