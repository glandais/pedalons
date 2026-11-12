import { useCallback, useMemo } from 'react'
import type { QueryClient } from '@tanstack/react-query'
import { useGetTeam, prefetchGetTeamQuery } from '@/api/endpoints/teams/teams'
import {
  useListRoutes,
  listRoutes,
  getListRoutesQueryKey,
  prefetchListRoutesQuery,
} from '@/api/endpoints/routes/routes'
import { useRouteFilters } from '@/hooks/useRouteFilters'
import { usePaginatedQuery } from '@/hooks/usePaginatedQuery'
import { readUrlFilters } from '@/hooks/useUrlFilters'
import {
  teamRouteFiltersSchema,
  teamRouteFiltersAlias,
  routeApiParams,
} from '@/hooks/filters/routeFilters'
import { prefetchPageWindow, prefetchTeamTags } from '@/config/prefetchHelpers'
import { LIST_QUERY, LIST_REQUEST } from '@/lib/listQuery'

/**
 * The one description of what the team route list reads, consumed two ways: `RouteListPage` calls
 * {@link useRouteListData} for the query results, the `routes` route in `routes.config.ts` calls
 * {@link prefetchRouteList} for the same data server-side. Same contract as
 * `pages/ride/rideDetailData.ts` — its own module so `routes.config.ts`, which imports it eagerly,
 * doesn't pull the page out of its lazy chunk.
 *
 * The filters are the reason this matters more here than on a detail page: the list's query key is
 * derived from the query string, so the page and the prefetch have to read the URL through the
 * *same* schema and alias, and turn it into API params the *same* way. Spelled out twice, a
 * filtered URL server-renders one list and then silently refetches another after hydration.
 */

/** The schema/alias pair both readers must use — the page through the URL, the prefetch through `url.searchParams`. */
export const routeListFilterOptions = {
  schema: teamRouteFiltersSchema,
  alias: teamRouteFiltersAlias,
} as const

/**
 * The team's own route list: the team, the filtered page the URL asks for, and the neighbouring
 * pages `usePaginatedQuery` fetches ahead. Returns the filter state as `useRouteFilters` gives it
 * (the panel needs the setters) plus the raw query results, so the page keeps reading `.data` /
 * `.isLoading` directly.
 */
export function useRouteListData(teamSlug?: string) {
  const filterState = useRouteFilters(routeListFilterOptions)
  const { filters } = filterState

  const team = useGetTeam(teamSlug!, { query: { enabled: !!teamSlug } })

  const apiParams = useMemo(() => routeApiParams(filters), [filters])
  const routes = useListRoutes(teamSlug!, apiParams, {
    query: { ...LIST_QUERY, enabled: !!teamSlug },
    request: LIST_REQUEST,
  })

  // The neighbouring pages, on the same key `prefetchPageWindow` primes server-side.
  const prefetchPage = useCallback(
    (page: number) => ({
      queryKey: getListRoutesQueryKey(teamSlug!, { ...apiParams, page }),
      queryFn: () => listRoutes(teamSlug!, { ...apiParams, page }, LIST_REQUEST),
    }),
    [teamSlug, apiParams]
  )
  const { totalPages } = usePaginatedQuery({
    page: filters.page,
    pageSize: filterState.pageSize,
    totalItems: routes.data?.total ?? 0,
    prefetchPage,
  })

  return { ...filterState, team, routes, totalPages }
}

/**
 * Server-side counterpart of {@link useRouteListData}: the same filters, read from the request's
 * query string instead of the router's, through the same schema and alias.
 *
 * No team-membership dependency here, unlike the cross-team route list — this list is scoped to
 * one team, so its key doesn't depend on who is asking.
 */
export async function prefetchRouteList(
  queryClient: QueryClient,
  teamSlug: string,
  url: URL
): Promise<void> {
  const filters = readUrlFilters(url.searchParams, routeListFilterOptions)
  await Promise.all([
    prefetchGetTeamQuery(queryClient, teamSlug),
    prefetchPageWindow(routeApiParams(filters), (p) =>
      prefetchListRoutesQuery(queryClient, teamSlug, p, { request: LIST_REQUEST })
    ),
    prefetchTeamTags(queryClient, teamSlug, 'ROUTE'),
  ])
}
