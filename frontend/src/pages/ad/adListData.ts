import { useCallback, useMemo } from 'react'
import type { QueryClient } from '@tanstack/react-query'
import { useGetTeam, prefetchGetTeamQuery } from '@/api/endpoints/teams/teams'
import {
  useListAds,
  listAds,
  getListAdsQueryKey,
  prefetchListAdsQuery,
} from '@/api/endpoints/ads/ads'
import { usePaginatedQuery } from '@/hooks/usePaginatedQuery'
import { useUrlFilters, readUrlFilters } from '@/hooks/useUrlFilters'
import { adFiltersSchema, adFiltersAlias, adApiParams } from '@/hooks/filters/adFilters'
import { prefetchPageWindow, prefetchTeamTags } from '@/config/prefetchHelpers'
import { LIST_QUERY, LIST_REQUEST } from '@/lib/listQuery'

/**
 * The one description of what the team ad list reads, consumed two ways: `AdListPage` calls
 * {@link useAdListData} for the query results, the `ads` route in `routes.config.ts` calls
 * {@link prefetchAdList} for the same data server-side. Same contract as
 * `pages/route/routeListData.ts` — its own module so `routes.config.ts`, which imports it eagerly,
 * doesn't pull the page out of its lazy chunk.
 *
 * The filters are the reason this matters more here than on a detail page: the list's query key is
 * derived from the query string, so the page and the prefetch have to read the URL through the
 * *same* schema and alias, and turn it into API params the *same* way. Spelled out twice, a
 * filtered URL server-renders one list and then silently refetches another after hydration.
 */

/** The schema/alias pair both readers must use — the page through the URL, the prefetch through `url.searchParams`. */
export const adListFilterOptions = {
  schema: adFiltersSchema,
  alias: adFiltersAlias,
} as const

/**
 * The team's own ad list: the team, the filtered page the URL asks for, and the neighbouring pages
 * `usePaginatedQuery` fetches ahead. Returns `filters`/`setFilters` as `useUrlFilters` gives them
 * (the page's filter controls need the setter) plus the raw query results, so the page keeps
 * reading `.data` / `.isLoading` / `.isFetching` directly.
 */
export function useAdListData(teamSlug?: string) {
  const { filters, setFilters } = useUrlFilters(adListFilterOptions)

  const team = useGetTeam(teamSlug!, { query: { enabled: !!teamSlug } })

  // A card needs `excerpt`, `thumbnailUrl` and `images`, all of which COMPACT keeps — it only
  // drops the markdown body, the attachments and every picture past the first.
  const apiParams = useMemo(() => adApiParams(filters), [filters])

  const ads = useListAds(teamSlug!, apiParams, {
    query: { ...LIST_QUERY, enabled: !!teamSlug },
    request: LIST_REQUEST,
  })

  // The neighbouring pages, on the same key `prefetchPageWindow` primes server-side.
  const prefetchPage = useCallback(
    (page: number) => ({
      queryKey: getListAdsQueryKey(teamSlug!, { ...apiParams, page }),
      queryFn: () => listAds(teamSlug!, { ...apiParams, page }, LIST_REQUEST),
    }),
    [teamSlug, apiParams]
  )
  const { totalPages } = usePaginatedQuery({
    page: filters.page,
    pageSize: filters.size,
    totalItems: ads.data?.total ?? 0,
    prefetchPage,
  })

  return { filters, setFilters, team, ads, totalPages }
}

/**
 * Server-side counterpart of {@link useAdListData}: the same filters, read from the request's
 * query string instead of the router's, through the same schema and alias — the team plus its
 * filtered ad page window (including `view`), matching the page's query key exactly.
 */
export async function prefetchAdList(
  queryClient: QueryClient,
  teamSlug: string,
  url: URL
): Promise<void> {
  const filters = readUrlFilters(url.searchParams, adListFilterOptions)
  await Promise.all([
    prefetchGetTeamQuery(queryClient, teamSlug),
    prefetchPageWindow(adApiParams(filters), (p) =>
      prefetchListAdsQuery(queryClient, teamSlug, p, { request: LIST_REQUEST })
    ),
    prefetchTeamTags(queryClient, teamSlug, 'AD'),
  ])
}
