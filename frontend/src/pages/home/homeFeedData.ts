import { useCallback, useMemo } from 'react'
import type { QueryClient } from '@tanstack/react-query'
import {
  useListAllPublications,
  listAllPublications,
  getListAllPublicationsQueryKey,
  prefetchListAllPublicationsQuery,
} from '@/api/endpoints/publications/publications'
import { prefetchListMyParticipationsQuery } from '@/api/endpoints/users/users'
import { useGetEvents, prefetchGetEventsQuery } from '@/api/endpoints/calendar/calendar'
import { useListTeams, prefetchListTeamsQuery } from '@/api/endpoints/teams/teams'
import { prefetchGetAvailableServicesQuery } from '@/api/endpoints/gps-services/gps-services'
import { MinRole } from '@/api/dto'
import { useAuth } from '@/hooks/useAuth'
import { useUrlFilters, readUrlFilters } from '@/hooks/useUrlFilters'
import { usePaginatedQuery } from '@/hooks/usePaginatedQuery'
import { useMembershipDefault } from '@/hooks/useMembershipDefault'
import { useMyParticipations } from '@/hooks/useMyParticipations'
import {
  makeHomeFiltersSchema,
  homeFiltersAlias,
  homeFiltersAlwaysSerialize,
} from '@/hooks/filters/homeFilters'
import { publicationApiParams } from '@/hooks/filters/publicationFilters'
import { membershipToMinRole, type MembershipFilterValue } from '@/hooks/filters/membership'
import { prefetchPageWindow, resolveMembershipDefault } from '@/config/prefetchHelpers'
import { useAuthStore } from '@/store/authStore'
import { hourAlignedNowIso } from '@/utils/nowIso'
import { NEXT_RIDE_PARAMS } from './nextRideParams'

/**
 * The one description of what the home feed reads, consumed two ways: `HomePage` calls
 * {@link useHomeFeedData} for the query results, the `home` route in `routes.config.ts` calls
 * {@link prefetchHomeFeed} for the same data server-side. Same contract as
 * `pages/route/routeListData.ts` — its own module so `routes.config.ts`, which imports it eagerly,
 * doesn't pull `HomePage` out of its lazy chunk.
 *
 * Two things have to agree byte-for-byte across the two sides:
 * - `hourAlignedNowIso()` — the `from` boundary of both the feed and "ma prochaine sortie". Each
 *   side calls it itself (it isn't threaded through as a parameter): computed a few hundred ms
 *   apart, on the same clock, it lands on the same hour almost always — that's the whole point of
 *   rounding it. Threading a value through instead would just move the divergence risk elsewhere.
 * - the membership default that seeds `makeHomeFiltersSchema` — `useMembershipDefault` client-side
 *   (a `useListTeams` probe), `resolveMembershipDefault` server-side (its prefetch-then-read
 *   counterpart). Different mechanisms by construction, so this stays out of the shared hook,
 *   exactly as auth stays out of `rideDetailData.ts`.
 */

/**
 * « Mes équipes » on the member home: the teams the user belongs to, with their role and the
 * per-team counters (`upcomingRideCount`, `upcomingTripCount`, `recentPostCount`) the activity
 * line is built from — computed per page by the backend (`TeamStatsRepository`), never per row.
 * The organizer quick actions are derived from the same rows.
 */
export const MY_TEAMS_PARAMS = { minRole: MinRole.MEMBER, page: 0, size: 20 } as const

const WEEK_MS = 7 * 24 * 60 * 60 * 1000

/**
 * « Cette semaine »: the user's calendar from the hour-aligned `now` to seven days later. Both
 * bounds derive from `hourAlignedNowIso()`, so the SSR prefetch and the client compute the same
 * key (see the note on `hourAlignedNowIso` above) — a local « today 00:00 » would differ between
 * the server's zone and the visitor's.
 */
export function weekWindow(nowIso: string) {
  return { from: nowIso, to: new Date(new Date(nowIso).getTime() + WEEK_MS).toISOString() }
}

/**
 * The member home's own blocks, on top of {@link useHomeFeedData}: the week's events of all the
 * user's teams (one call) and their teams. Signed-in only; disabled for a visitor.
 */
export function useMemberHomeData(nowIso: string) {
  const { isAuthenticated } = useAuth()
  const week = useGetEvents(weekWindow(nowIso), { query: { enabled: isAuthenticated } })
  const teams = useListTeams(MY_TEAMS_PARAMS, { query: { enabled: isAuthenticated } })
  return { week, teams }
}

/** The schema/alias pair both readers must use — the page through the URL, the prefetch through `url.searchParams`. */
export function homeFeedFilterOptions(membershipDefault: MembershipFilterValue) {
  return { schema: makeHomeFiltersSchema(membershipDefault), alias: homeFiltersAlias } as const
}

/**
 * Every query `HomePage` itself owns: the filtered feed page the URL asks for (plus the
 * neighbours `usePaginatedQuery` fetches ahead), and the signed-in visitor's next participations
 * for "ma prochaine sortie". Returns the filter state as `useUrlFilters` gives it (the page needs
 * the setters) plus the raw query results.
 */
export function useHomeFeedData() {
  const membershipDefault = useMembershipDefault()
  const filterOptions = useMemo(() => homeFeedFilterOptions(membershipDefault), [membershipDefault])

  const { filters, setFilters } = useUrlFilters({
    ...filterOptions,
    alwaysSerialize: homeFiltersAlwaysSerialize,
  })

  // Hour-aligned and frozen per mount: a `from` that changed on every render, or that disagreed
  // with the SSR prefetch computed a few hundred ms earlier, would defeat the query cache.
  const nowIso = useMemo(() => hourAlignedNowIso(), [])

  const apiParams = useMemo(
    () => ({
      ...publicationApiParams(filters, nowIso),
      minRole: membershipToMinRole[filters.membership],
    }),
    [filters, nowIso]
  )

  const publications = useListAllPublications(apiParams)

  const prefetchPage = useCallback(
    (page: number) => ({
      queryKey: getListAllPublicationsQueryKey({ ...apiParams, page }),
      queryFn: () => listAllPublications({ ...apiParams, page }),
    }),
    [apiParams]
  )

  const { totalPages } = usePaginatedQuery({
    page: filters.page,
    pageSize: filters.size,
    totalItems: publications.data?.total ?? 0,
    prefetchPage,
  })

  // "Ma prochaine sortie" — authenticated-only. Prefetched by the `home` route for a
  // session-carrying SSR request, so it's already in the initial HTML for a signed-in visitor
  // rather than rendering after hydration.
  const participations = useMyParticipations({ from: nowIso, ...NEXT_RIDE_PARAMS })

  return {
    membershipDefault,
    filters,
    setFilters,
    nowIso,
    publications,
    totalPages,
    participations,
  }
}

/**
 * Server-side counterpart of {@link useHomeFeedData}: resolves the feed the URL actually asks
 * for, filters and page included, the same way `HomePage` does — the membership probe feeds the
 * schema's default, the query string overrides it, and `publicationApiParams` projects the result.
 */
export async function prefetchHomeFeed(queryClient: QueryClient, url: URL): Promise<void> {
  const membershipDefault = await resolveMembershipDefault(queryClient)
  if (useAuthStore.getState().isAuthenticated) {
    await prefetchListMyParticipationsQuery(queryClient, {
      from: hourAlignedNowIso(),
      ...NEXT_RIDE_PARAMS,
    })
    await Promise.all([
      prefetchGetEventsQuery(queryClient, weekWindow(hourAlignedNowIso())),
      prefetchListTeamsQuery(queryClient, MY_TEAMS_PARAMS),
      // `NextRideCard`'s « Envoyer vers l'appareil » goes through `useGpsConnections()`.
      prefetchGetAvailableServicesQuery(queryClient),
    ])
  }
  const filters = readUrlFilters(url.searchParams, homeFeedFilterOptions(membershipDefault))
  const feedParams = {
    ...publicationApiParams(filters, hourAlignedNowIso()),
    minRole: membershipToMinRole[filters.membership],
  }
  await prefetchPageWindow(feedParams, (p) => prefetchListAllPublicationsQuery(queryClient, p))
}
