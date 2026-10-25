import { keepPreviousData, type QueryClient } from '@tanstack/react-query'
import { useGetTeam, prefetchGetTeamQuery } from '@/api/endpoints/teams/teams'
import {
  useGetTeamEvents,
  prefetchGetTeamEventsQuery,
  prefetchGetTokenQuery,
} from '@/api/endpoints/calendar/calendar'
import { useCalendarDateRange, getInitialCalendarRange } from '@/hooks/useCalendarDateRange'
import { useAuthStore } from '@/store/authStore'
import { readsMemberContent } from '@/config/prefetchHelpers'

/**
 * Server/client counterpart of `TeamCalendarPage`: the team, its first events window, and the ICS
 * token `IcsFeedSettings` reads unconditionally (it renders on every paint, not behind a
 * disclosure). Escaped `calendarData.ts`'s fix because the manual crawler of the time (since retired,
 * docs/LEDGER_*.md WEB-53) never measured this route; `e2e/routes-render.e2e.ts` now audits it.
 *
 * Keyed the same way `calendarData.ts` keys the personal calendar: `getInitialCalendarRange()` is
 * what `useCalendarDateRange` seeds its state with, so the first `useGetTeamEvents` call and the
 * prefetch land on the same query key — and the visible grid `CalendarView` reports on mount falls
 * inside that window, so it does not re-key the query.
 *
 * The route is `auth: 'authenticated'` but the API beneath it is member-only
 * (`CalendarAccessChecker` needs a team role, not just a session — see the route comment in
 * `routes.config.ts`). Mirrors `prefetchMemberComments`: fetch the team first, then read its
 * `role` back out of the cache (a platform admin reads it too, `readsMemberContent`) before prefetching the events that would 403 for a non-member. The
 * token endpoint carries no such gate — it's the signed-in user's own feed, not the team's — so
 * it prefetches for any authenticated visitor, matching what `IcsFeedSettings` actually fetches.
 */
export function useTeamCalendarData(teamSlug?: string) {
  const { dateRange, handleDateRangeChange } = useCalendarDateRange()

  const team = useGetTeam(teamSlug!, { query: { enabled: !!teamSlug } })

  // `keepPreviousData`, like `CalendarPage`: leaving the loaded window re-keys the query, and the
  // page would otherwise empty its grid under the overlay while the new window loads. Read the
  // result as `isFetching`, not `isLoading` — with previous data in hand `isLoading` stays false.
  const events = useGetTeamEvents(
    teamSlug!,
    { from: dateRange.from, to: dateRange.to },
    { query: { enabled: !!teamSlug, staleTime: 1000 * 60 * 5, placeholderData: keepPreviousData } }
  )

  return { team, events, dateRange, handleDateRangeChange }
}

export async function prefetchTeamCalendar(
  queryClient: QueryClient,
  teamSlug: string
): Promise<void> {
  if (!useAuthStore.getState().isAuthenticated) return

  await prefetchGetTeamQuery(queryClient, teamSlug)

  await Promise.all([
    readsMemberContent(queryClient, teamSlug)
      ? prefetchGetTeamEventsQuery(queryClient, teamSlug, getInitialCalendarRange())
      : Promise.resolve(queryClient),
    prefetchGetTokenQuery(queryClient),
  ])
}
