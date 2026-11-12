import { useCallback, useMemo, useState } from 'react'
import type { QueryClient } from '@tanstack/react-query'
import {
  useListAllRoutes,
  listAllRoutes,
  getListAllRoutesQueryKey,
  useGetAllRoutesBounds,
  prefetchListAllRoutesQuery,
  prefetchGetAllRoutesBoundsQuery,
} from '@/api/endpoints/routes/routes'
import { useRouteFilters } from '@/hooks/useRouteFilters'
import { usePaginatedQuery } from '@/hooks/usePaginatedQuery'
import { useMembershipDefault } from '@/hooks/useMembershipDefault'
import { readUrlFilters } from '@/hooks/useUrlFilters'
import {
  makeAllRouteFiltersSchema,
  resolveRouteDensity,
  allRouteFiltersAlias,
  allRouteFiltersAlwaysSerialize,
  allRouteApiParams,
} from '@/hooks/filters/routeFilters'
import { membershipToMinRole, type MembershipFilterValue } from '@/hooks/filters/membership'
import { allRoutesTilesUrl, toRouteTileFilters } from '@/components/map/mapConstants'
import { prefetchPageWindow, resolveMembershipDefault } from '@/config/prefetchHelpers'
import { LIST_QUERY, LIST_REQUEST } from '@/lib/listQuery'

/**
 * The one description of what the cross-team routes screen reads, consumed four ways:
 * `AllRoutesPage` calls {@link useAllRouteListData}, `AllRoutesMapPage` calls
 * {@link useAllRoutesMapData}, and the `all-routes` / `all-routes-map` routes in
 * `routes.config.ts` call {@link prefetchAllRouteList} / {@link prefetchAllRoutesMap} for the same
 * data server-side. Same contract as `pages/route/routeListData.ts` — its own module so
 * `routes.config.ts`, which imports it eagerly, doesn't pull either page out of its lazy chunk.
 *
 * Both screens share one filter set (`makeAllRouteFiltersSchema(membershipDefault)` +
 * `allRouteFiltersAlias`) and one membership resolution (`useMembershipDefault` on the client,
 * `resolveMembershipDefault` server-side) — spelled out once here so a link carrying `?q=col` or
 * `?membership=member` server-renders the same list/map the client would build from that URL, not
 * the default one.
 */

/** The schema/alias pair both readers must use — the page through the URL, the prefetch through `url.searchParams`. */
export function allRouteFilterOptions(membershipDefault: MembershipFilterValue) {
  return {
    schema: makeAllRouteFiltersSchema(membershipDefault),
    alias: allRouteFiltersAlias,
    alwaysSerialize: allRouteFiltersAlwaysSerialize,
  } as const
}

/**
 * The cross-team route list: the filtered page the URL asks for, and the neighbouring pages
 * `usePaginatedQuery` fetches ahead. Returns the filter state as `useRouteFilters` gives it (the
 * panel needs the setters) plus the raw query results, so the page keeps reading `.data` /
 * `.isLoading` directly.
 */
export function useAllRouteListData() {
  const membershipDefault = useMembershipDefault()
  const schema = useMemo(() => makeAllRouteFiltersSchema(membershipDefault), [membershipDefault])

  const filterState = useRouteFilters({
    schema,
    alias: allRouteFiltersAlias,
    alwaysSerialize: allRouteFiltersAlwaysSerialize,
  })
  const { filters } = filterState

  const apiParams = useMemo(() => allRouteApiParams(filters), [filters])

  const routes = useListAllRoutes(apiParams, {
    query: LIST_QUERY,
    request: LIST_REQUEST,
  })

  const density = resolveRouteDensity(filters.density, routes.data?.total)

  // The neighbouring pages, on the same key `prefetchPageWindow` primes server-side.
  const prefetchPage = useCallback(
    (page: number) => ({
      queryKey: getListAllRoutesQueryKey({ ...apiParams, page }),
      queryFn: () => listAllRoutes({ ...apiParams, page }, LIST_REQUEST),
    }),
    [apiParams]
  )
  const { totalPages } = usePaginatedQuery({
    page: filters.page,
    pageSize: filterState.pageSize,
    totalItems: routes.data?.total ?? 0,
    prefetchPage,
  })

  return { ...filterState, routes, density, totalPages }
}

/**
 * Server-side counterpart of {@link useAllRouteListData}: the same filters, read from the
 * request's query string instead of the router's, membership resolved the same way
 * `useMembershipDefault` would for a signed-in visitor.
 */
export async function prefetchAllRouteList(queryClient: QueryClient, url: URL): Promise<void> {
  const membershipDefault = await resolveMembershipDefault(queryClient)
  const filters = readUrlFilters(url.searchParams, allRouteFilterOptions(membershipDefault))
  await prefetchPageWindow(allRouteApiParams(filters), (p) =>
    prefetchListAllRoutesQuery(queryClient, p, { request: LIST_REQUEST })
  )
}

/**
 * The cross-team map: the filters (for the tile URL MapLibre fetches client-side, outside React
 * Query) and the initial bounds, frozen at mount like the page freezes them — narrowing the
 * filters afterwards reframes nothing, only a remount (the list/map toggle) asks for a fresh
 * extent.
 */
export function useAllRoutesMapData() {
  const membershipDefault = useMembershipDefault()
  const schema = useMemo(() => makeAllRouteFiltersSchema(membershipDefault), [membershipDefault])

  const filterState = useRouteFilters({
    schema,
    alias: allRouteFiltersAlias,
    alwaysSerialize: allRouteFiltersAlwaysSerialize,
  })
  const { filters } = filterState

  const tilesUrl = useMemo(
    () =>
      allRoutesTilesUrl({
        ...toRouteTileFilters(filters),
        minRole: membershipToMinRole[filters.membership],
      }),
    [filters]
  )

  // Frozen at mount, so narrowing the filters reframes nothing and asks the server nothing. The
  // list/map toggle is a navigation, hence a remount, hence a fresh extent.
  const [initialFilters] = useState(() => ({
    ...toRouteTileFilters(filters),
    minRole: membershipToMinRole[filters.membership],
  }))
  const bounds = useGetAllRoutesBounds(initialFilters)

  return { ...filterState, tilesUrl, bounds }
}

/**
 * Server-side counterpart of {@link useAllRoutesMapData}'s bounds query — the only one it prefetches.
 *
 * Keyed on `minRole` alone, like the route entry it replaces: the bounds query key it must match is
 * the page's *initial* one, which the page also derives from the URL's filters, so this only lands
 * the exact key when the request carries no filter beyond `membership`. A filtered map URL (e.g.
 * `?hill=HILLY`) still refetches its bounds after hydration — a pre-existing gap, not something this
 * refactor introduces or fixes.
 */
export async function prefetchAllRoutesMap(queryClient: QueryClient, url: URL): Promise<void> {
  const membershipDefault = await resolveMembershipDefault(queryClient)
  const filters = readUrlFilters(url.searchParams, allRouteFilterOptions(membershipDefault))
  await prefetchGetAllRoutesBoundsQuery(queryClient, {
    minRole: membershipToMinRole[filters.membership],
  })
}
