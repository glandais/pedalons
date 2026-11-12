import type { QueryClient } from '@tanstack/react-query'
import { prefetchGetEventsQuery, prefetchGetTokenQuery } from '@/api/endpoints/calendar/calendar'
import { getInitialCalendarRange } from '@/hooks/useCalendarDateRange'
import { useAuthStore } from '@/store/authStore'
import { LIST_REQUEST } from '@/lib/listQuery'

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
export async function prefetchCalendar(queryClient: QueryClient): Promise<void> {
  if (!useAuthStore.getState().isAuthenticated) return
  await Promise.all([
    prefetchGetEventsQuery(queryClient, getInitialCalendarRange(), { request: LIST_REQUEST }),
    prefetchGetTokenQuery(queryClient),
  ])
}
