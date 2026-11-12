import { useCallback, useMemo } from 'react'
import type { QueryClient } from '@tanstack/react-query'
import { useGetTeam, prefetchGetTeamQuery } from '@/api/endpoints/teams/teams'
import {
  useListPublications,
  listPublications,
  getListPublicationsQueryKey,
  prefetchListPublicationsQuery,
} from '@/api/endpoints/publications/publications'
import { usePaginatedQuery } from '@/hooks/usePaginatedQuery'
import { useUrlFilters, readUrlFilters } from '@/hooks/useUrlFilters'
import {
  agendaApiParams,
  agendaFiltersAlias,
  agendaFiltersSchema,
  agendaTypeToPublicationType,
} from '@/hooks/filters/agendaFilters'
import { prefetchPageWindow, prefetchTeamTags } from '@/config/prefetchHelpers'
import { LIST_QUERY, LIST_REQUEST } from '@/lib/listQuery'

/**
 * The one description of what the team's « Agenda » (`teamAgenda`) reads, consumed two ways:
 * `TeamAgendaPage` calls {@link useTeamAgendaData}, the route's `prefetch` calls
 * {@link prefetchTeamAgenda} — the same filters, read through the same schema and alias, projected
 * by the same {@link agendaApiParams}, so both land on the same query keys (docs/SSR-data-loading.md).
 * The default scope, « À venir », lives in the schema: it reaches the page and the prefetch alike.
 */
export const agendaFilterOptions = {
  schema: agendaFiltersSchema,
  alias: agendaFiltersAlias,
} as const

export function useTeamAgendaData(teamSlug?: string) {
  const { filters, setFilters } = useUrlFilters(agendaFilterOptions)

  const team = useGetTeam(teamSlug!, { query: { enabled: !!teamSlug } })

  const apiParams = useMemo(() => agendaApiParams(filters), [filters])
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

/** Server-side (and hover) counterpart of {@link useTeamAgendaData}. */
export async function prefetchTeamAgenda(
  queryClient: QueryClient,
  teamSlug: string,
  url: URL
): Promise<void> {
  const filters = readUrlFilters(url.searchParams, agendaFilterOptions)
  // The tag filter only offers tags once a kind is chosen.
  const tagTarget = agendaTypeToPublicationType[filters.filter]
  await Promise.all([
    prefetchGetTeamQuery(queryClient, teamSlug),
    prefetchPageWindow(agendaApiParams(filters), (p) =>
      prefetchListPublicationsQuery(queryClient, teamSlug, p, { request: LIST_REQUEST })
    ),
    tagTarget ? prefetchTeamTags(queryClient, teamSlug, tagTarget) : undefined,
  ])
}
