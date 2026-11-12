import { useState } from 'react'
import type { z } from 'zod'
import { useUrlFilters, type UseUrlFiltersOptions } from './useUrlFilters'
import type { RouteFilters } from './filters/routeFilters'
import type { MembershipFilterValue } from './filters/membership'

/**
 * Shared by the team route list and the cross-team one, whose schema also carries a membership
 * filter — hence the schema is a parameter. Any schema passed here extends the route shape.
 */
export function useRouteFilters<S extends z.ZodObject<z.ZodRawShape>>(
  options: UseUrlFiltersOptions<S>
) {
  const [filtersOpen, setFiltersOpen] = useState(false)
  const { filters, setFilters, replaceFilters, defaults } = useUrlFilters(options)
  // The generic schema hides the route shape from the type system, but every caller passes one.
  type Owned = RouteFilters & { tags?: string[]; membership?: MembershipFilterValue }
  const routeFilters = filters as Owned
  const defaultMembership = (defaults as Owned).membership
  const patchRouteFilters = setFilters as unknown as (patch: Partial<Owned>) => void

  const activeFilterCount = countRouteFilters(routeFilters, defaultMembership)
  const hasFiltersOrSearch = activeFilterCount > 0

  // « Effacer les filtres » (RL4): resets every key the count looks at, by name rather than by
  // omission — the membership back to its default on the cross-team list — so the sort and the
  // density, which are no filters, survive the reset.
  const clearFilters = () =>
    patchRouteFilters({
      search: undefined,
      minDistance: undefined,
      maxDistance: undefined,
      minElevationGain: undefined,
      maxElevationGain: undefined,
      hilliness: undefined,
      surfaceType: undefined,
      windDirection: undefined,
      // Only a team's own list has tags, only the cross-team one a membership; elsewhere the key
      // is outside the schema and ignored.
      tags: undefined,
      membership: defaultMembership,
      page: 0,
    })

  return {
    filters: filters as z.infer<S> & RouteFilters,
    setFilters,
    clearFilters,
    // RouteFilterPanel hands back the whole filter set with the cleared keys reset, so this must
    // replace rather than merge.
    handleFiltersChange: replaceFilters,
    handlePageChange: (page: number) => patchRouteFilters({ page }),
    filtersOpen,
    setFiltersOpen,
    hasFiltersOrSearch,
    activeFilterCount,
    defaultMembership,
    pageSize: routeFilters.size,
  }
}

/**
 * What « Effacer les filtres » lifts, counted for the « Filtres » button (RL4): the search, each
 * criterion (a range counts once), the tags, the membership off its default. Never the sort.
 */
export function countRouteFilters(
  filters: RouteFilters & { tags?: string[]; membership?: MembershipFilterValue },
  defaultMembership: MembershipFilterValue | undefined
): number {
  return [
    !!filters.search,
    filters.minDistance !== undefined || filters.maxDistance !== undefined,
    filters.minElevationGain !== undefined || filters.maxElevationGain !== undefined,
    filters.hilliness !== undefined,
    filters.surfaceType !== undefined,
    filters.windDirection !== undefined,
    !!filters.tags?.length,
    filters.membership !== defaultMembership,
  ].filter(Boolean).length
}
