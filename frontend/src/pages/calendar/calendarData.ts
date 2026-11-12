import { keepPreviousData, type QueryClient } from '@tanstack/react-query'
import {
  prefetchGetEventsQuery,
  prefetchGetTeamEventsQuery,
  prefetchGetTokenQuery,
  useGetEvents,
  useGetTeamEvents,
} from '@/api/endpoints/calendar/calendar'
import { prefetchTeamSwitcher, useTeamSwitcherTeams } from '@/components/team/teamSwitcherData'
import { calendarFilterOptions } from '@/hooks/filters/calendarFilters'
import { getInitialCalendarRange, useCalendarDateRange } from '@/hooks/useCalendarDateRange'
import { readUrlFilters, useUrlFilters } from '@/hooks/useUrlFilters'
import { useAuthStore } from '@/store/authStore'
import { LIST_REQUEST } from '@/lib/listQuery'

const EVENTS_QUERY = { staleTime: 1000 * 60 * 5, placeholderData: keepPreviousData } as const

/**
 * What `CalendarPage` reads: its filters, the reader's teams (the team selector's choices — the
 * team switcher's listing, one query key), and the events of the window, all teams' or the one
 * team's (`?team=`, read through the team's endpoint).
 *
 * `keepPreviousData` + `isFetching`: leaving the loaded window (a year view, a distant jump)
 * re-keys the query, and without it `events` would fall back to `[]` and empty the grid under the
 * overlay. The previous month's events stay on screen, dimmed by the overlay, until the new ones
 * arrive.
 */
export function useCalendarData() {
  const { dateRange, handleDateRangeChange } = useCalendarDateRange()
  const { filters, setFilters } = useUrlFilters(calendarFilterOptions)
  const teams = useTeamSwitcherTeams().data?.teams ?? []
  const range = { from: dateRange.from, to: dateRange.to }
  const mine = useGetEvents(range, {
    query: { ...EVENTS_QUERY, enabled: !filters.team },
    request: LIST_REQUEST,
  })
  const team = useGetTeamEvents(filters.team ?? '', range, {
    query: { ...EVENTS_QUERY, enabled: !!filters.team },
    request: LIST_REQUEST,
  })
  return {
    filters,
    setFilters,
    teams,
    events: filters.team ? team : mine,
    dateRange,
    handleDateRangeChange,
  }
}

/**
 * Server-side counterpart of `CalendarPage`'s first events query, keyed on the same
 * `getInitialCalendarRange()` `useCalendarDateRange` seeds its state with — the only reason that
 * first query is prefetchable at all. `CalendarView` reports its visible grid right after mount,
 * but that range is contained in this one and `handleDateRangeChange` bails out rather than
 * re-keying the query, so this prefetch is what the page renders from and keeps rendering from.
 *
 * Also primes `useGetToken`, the query `IcsFeedSettings` fires on mount: `CalendarPage` renders it
 * unconditionally at the bottom of the page, not behind a disclosure or accordion the visitor has
 * to open, so it's on-screen (below the fold, but present in the initial paint) the same as the
 * events grid above it. `useGetToken()` takes no params, so there's nothing to derive — the
 * prefetched key matches by construction.
 *
 * Auth-gated here rather than via `teamScopedPrefetch`: unlike the team-scoped admin routes, the
 * `calendar` route itself isn't team-scoped, so it reads `useAuthStore.getState()` directly, the
 * same way `profileData.ts` does.
 *
 * `TeamCalendarPage` (route `team-calendar`) queries the team-scoped sibling endpoint
 * (`useGetTeamEvents`) through the same `useCalendarDateRange` hook; its own prefetch lives in
 * `teamCalendarData.ts`, which has to gate on team membership as well as on a session.
 */
export async function prefetchCalendar(queryClient: QueryClient, url: URL): Promise<void> {
  if (!useAuthStore.getState().isAuthenticated) return
  const { team } = readUrlFilters(url.searchParams, calendarFilterOptions)
  await Promise.all([
    team
      ? prefetchGetTeamEventsQuery(queryClient, team, getInitialCalendarRange(), {
          request: LIST_REQUEST,
        })
      : prefetchGetEventsQuery(queryClient, getInitialCalendarRange(), { request: LIST_REQUEST }),
    prefetchGetTokenQuery(queryClient),
    prefetchTeamSwitcher(queryClient),
  ])
}
