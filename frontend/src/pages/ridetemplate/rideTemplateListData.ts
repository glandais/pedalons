import { useCallback } from 'react'
import type { QueryClient } from '@tanstack/react-query'
import {
  useListTemplates,
  listTemplates,
  getListTemplatesQueryKey,
  prefetchListTemplatesQuery,
} from '@/api/endpoints/ride-templates/ride-templates'
import { usePaginatedQuery } from '@/hooks/usePaginatedQuery'
import { useUrlFilters, readUrlFilters } from '@/hooks/useUrlFilters'
import {
  rideTemplateFiltersSchema,
  rideTemplateFiltersAlias,
} from '@/hooks/filters/rideTemplateFilters'
import { prefetchGetTeamQuery } from '@/api/endpoints/teams/teams'
import { organizesTeam, prefetchPageWindow } from '@/config/prefetchHelpers'
import { LIST_QUERY, LIST_REQUEST } from '@/lib/listQuery'

/**
 * The one description of what the team's ride-template list reads, consumed two ways:
 * `RideTemplateListPage` calls {@link useRideTemplateListData} for the query results, the
 * `ride-templates` route in `routes.config.ts` calls {@link prefetchRideTemplateList} for the same
 * data server-side (wrapped in `teamScopedPrefetch`, which already covers the team itself). Same
 * contract as `pages/route/routeListData.ts` — its own module so `routes.config.ts`, which imports
 * it eagerly, doesn't pull the page out of its lazy chunk.
 *
 * `rideTemplateFiltersSchema` maps directly onto `ListTemplatesParams` (search/page/size) — no
 * separate params builder, unlike the route list's `routeApiParams`.
 *
 * The prefetch reads the request's query string through the same `rideTemplateListFilterOptions`
 * the page's `useUrlFilters` uses, via `readUrlFilters`, then primes the page the URL asks for plus
 * the neighbours `usePaginatedQuery` fetches ahead — same shape as `routeListData.ts`'s
 * `prefetchPageWindow`. A filtered URL (`?q=…&p=2`) now server-renders that list.
 */

/** The schema/alias pair the page reads the URL through. */
export const rideTemplateListFilterOptions = {
  schema: rideTemplateFiltersSchema,
  alias: rideTemplateFiltersAlias,
} as const

/**
 * The team's ride-template list: the filtered page the URL asks for, plus the neighbouring pages
 * `usePaginatedQuery` fetches ahead. Returns the filter state as `useUrlFilters` gives it (the page
 * needs `setFilters` for the search box and pagination) plus the raw query results.
 *
 * `canRead`: the server lists the templates to an organizer only (`RideTemplateAccessChecker`) — a
 * plain member is refused. The page knows the reader's role once the team is read, and asks for
 * nothing before (docs/LEDGER_*.md WEB-175, DL23).
 */
export function useRideTemplateListData(teamSlug: string | undefined, canRead: boolean) {
  const filterState = useUrlFilters(rideTemplateListFilterOptions)
  const { filters } = filterState

  const templates = useListTemplates(teamSlug!, filters, {
    query: { ...LIST_QUERY, enabled: !!teamSlug && canRead },
    request: LIST_REQUEST,
  })

  // The neighbouring pages, on the same key `prefetchPageWindow` primes server-side.
  const prefetchPage = useCallback(
    (page: number) => ({
      queryKey: getListTemplatesQueryKey(teamSlug!, { ...filters, page }),
      queryFn: () => listTemplates(teamSlug!, { ...filters, page }, LIST_REQUEST),
    }),
    [teamSlug, filters]
  )
  const { totalPages } = usePaginatedQuery({
    page: filters.page,
    pageSize: filters.size,
    totalItems: templates.data?.total ?? 0,
    prefetchPage,
  })

  return { ...filterState, templates, totalPages }
}

/**
 * Server-side counterpart of {@link useRideTemplateListData}: the same filters, read from the
 * request's query string instead of the router's, through the same schema and alias.
 */
export async function prefetchRideTemplateList(
  queryClient: QueryClient,
  teamSlug: string,
  url: URL
): Promise<void> {
  const filters = readUrlFilters(url.searchParams, rideTemplateListFilterOptions)
  // Same gate as the page: the reader's role comes with the team.
  await prefetchGetTeamQuery(queryClient, teamSlug)
  if (!organizesTeam(queryClient, teamSlug)) return
  await prefetchPageWindow(filters, (p) =>
    prefetchListTemplatesQuery(queryClient, teamSlug, p, { request: LIST_REQUEST })
  )
}
