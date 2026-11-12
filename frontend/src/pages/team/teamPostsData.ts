import { useCallback, useMemo } from 'react'
import type { QueryClient } from '@tanstack/react-query'
import { useGetTeam, prefetchGetTeamQuery } from '@/api/endpoints/teams/teams'
import {
  useListPublications,
  listPublications,
  getListPublicationsQueryKey,
  prefetchListPublicationsQuery,
} from '@/api/endpoints/publications/publications'
import { PublicationType } from '@/api/dto'
import { usePaginatedQuery } from '@/hooks/usePaginatedQuery'
import { useUrlFilters, readUrlFilters } from '@/hooks/useUrlFilters'
import {
  teamPostApiParams,
  teamPostFiltersAlias,
  teamPostFiltersSchema,
} from '@/hooks/filters/teamPostFilters'
import { prefetchPageWindow, prefetchTeamTags } from '@/config/prefetchHelpers'
import { LIST_QUERY, LIST_REQUEST } from '@/lib/listQuery'

/**
 * The one description of what the team's « Publications » (`teamPosts`) reads: the page through
 * {@link useTeamPostsData}, the route's `prefetch` through {@link prefetchTeamPosts}, on the same
 * query keys (docs/SSR-data-loading.md).
 */
export const teamPostFilterOptions = {
  schema: teamPostFiltersSchema,
  alias: teamPostFiltersAlias,
} as const

export function useTeamPostsData(teamSlug?: string) {
  const { filters, setFilters } = useUrlFilters(teamPostFilterOptions)

  const team = useGetTeam(teamSlug!, { query: { enabled: !!teamSlug } })

  const apiParams = useMemo(() => teamPostApiParams(filters), [filters])
  const publications = useListPublications(teamSlug!, apiParams, {
    query: { ...LIST_QUERY, enabled: !!teamSlug },
    request: LIST_REQUEST,
  })

  const prefetchPage = useCallback(
    (page: number) => ({
      queryKey: getListPublicationsQueryKey(teamSlug!, { ...apiParams, page }),
      queryFn: () => listPublications(teamSlug!, { ...apiParams, page }, LIST_REQUEST),
    }),
    [teamSlug, apiParams]
  )

  const { totalPages } = usePaginatedQuery({
    page: filters.page,
    pageSize: filters.size,
    totalItems: publications.data?.total ?? 0,
    prefetchPage,
  })

  return { filters, setFilters, team, publications, totalPages }
}

/** Server-side (and hover) counterpart of {@link useTeamPostsData}. */
export async function prefetchTeamPosts(
  queryClient: QueryClient,
  teamSlug: string,
  url: URL
): Promise<void> {
  const filters = readUrlFilters(url.searchParams, teamPostFilterOptions)
  await Promise.all([
    prefetchGetTeamQuery(queryClient, teamSlug),
    prefetchPageWindow(teamPostApiParams(filters), (p) =>
      prefetchListPublicationsQuery(queryClient, teamSlug, p, { request: LIST_REQUEST })
    ),
    prefetchTeamTags(queryClient, teamSlug, PublicationType.POST),
  ])
}
