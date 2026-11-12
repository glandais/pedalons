import { useCallback, useMemo } from 'react'
import { useQuery, type QueryClient } from '@tanstack/react-query'
import { useGetTeam, prefetchGetTeamQuery } from '@/api/endpoints/teams/teams'
import { usePaginatedQuery } from '@/hooks/usePaginatedQuery'
import { useUrlFilters, readUrlFilters } from '@/hooks/useUrlFilters'
import {
  agendaApiParams,
  agendaFiltersAlias,
  agendaFiltersSchema,
  agendaTypeToPublicationType,
} from '@/hooks/filters/agendaFilters'
import { prefetchPageWindow, prefetchTeamTags } from '@/config/prefetchHelpers'
import { LIST_QUERY } from '@/lib/listQuery'
import { agendaListQuery } from './agendaUpcomingFirst'

/**
 * The one description of what the team's « Agenda » (`teamAgenda`) reads, consumed two ways:
 * `TeamAgendaPage` calls {@link useTeamAgendaData}, the route's `prefetch` calls
 * {@link prefetchTeamAgenda} — the same filters, read through the same schema and alias, projected
 * by the same {@link agendaApiParams}, so both land on the same query keys (docs/SSR-data-loading.md).
 * The default period, « Toutes les dates », lives in the schema: it reaches the page and the
 * prefetch alike. Each page is read through `agendaListQuery`, the one description of its query.
 */
export const agendaFilterOptions = {
  schema: agendaFiltersSchema,
  alias: agendaFiltersAlias,
} as const

export function useTeamAgendaData(teamSlug?: string) {
  const { filters, setFilters } = useUrlFilters(agendaFilterOptions)

  const team = useGetTeam(teamSlug!, { query: { enabled: !!teamSlug } })

  const apiParams = useMemo(() => agendaApiParams(filters), [filters])
  const publications = useQuery({
    ...agendaListQuery(teamSlug!, apiParams),
    ...LIST_QUERY,
    enabled: !!teamSlug,
  })

  const prefetchPage = useCallback(
    (page: number) => agendaListQuery(teamSlug!, { ...apiParams, page }),
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
      queryClient.prefetchQuery(agendaListQuery(teamSlug, p))
    ),
    tagTarget ? prefetchTeamTags(queryClient, teamSlug, tagTarget) : undefined,
  ])
}
