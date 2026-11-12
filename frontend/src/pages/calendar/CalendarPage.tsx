import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { keepPreviousData } from '@tanstack/react-query'
import { Title, Group, Stack } from '@mantine/core'
import { getEvents, useGetEvents } from '@/api/endpoints/calendar/calendar'
import { LIST_REQUEST } from '@/lib/listQuery'
import { AgendaTypeControl } from '@/components/agenda/AgendaFilterBar'
import { CalendarView } from '@/components/calendar/CalendarView'
import { IcsFeedSettings } from '@/components/calendar/IcsFeedSettings'
import { QueryStateBoundary } from '@/components/common/QueryStateBoundary'
import { keepCalendarEvent, calendarTypeFilterOptions } from '@/hooks/filters/calendarFilters'
import { useCalendarDateRange } from '@/hooks/useCalendarDateRange'
import { useUrlFilters } from '@/hooks/useUrlFilters'

/**
 * The personal calendar: every team's rides and trip stages. Its kind « Tout / Sorties / Voyages »
 * (`?type=`) filters the loaded window client-side, as the team calendar does — the API takes
 * `from`/`to` only, and the query key does not depend on the kind.
 */
export function CalendarPage(): React.ReactElement {
  const { t } = useTranslation()
  const { dateRange, handleDateRangeChange } = useCalendarDateRange()
  const { filters, setFilters } = useUrlFilters(calendarTypeFilterOptions)

  // `keepPreviousData` + `isFetching`: leaving the loaded window (a year view, a distant jump)
  // re-keys the query, and without it `events` would fall back to `[]` and empty the grid under
  // the overlay. The previous month's events stay on screen, dimmed by the overlay, until the new
  // ones arrive.
  const events = useGetEvents(
    { from: dateRange.from, to: dateRange.to },
    {
      query: { staleTime: 1000 * 60 * 5, placeholderData: keepPreviousData },
      request: LIST_REQUEST,
    }
  )
  const { data: eventsData } = events

  const shown = useMemo(
    () => (eventsData?.events ?? []).filter((event) => keepCalendarEvent(event, filters)),
    [eventsData, filters]
  )

  return (
    <Stack>
      <Group justify="space-between" align="center">
        <Title order={2}>{t('calendar.title')}</Title>
      </Group>

      <Group gap="sm" wrap="wrap">
        <AgendaTypeControl
          rides
          trips
          value={filters.filter}
          onChange={(filter) => setFilters({ filter })}
        />
      </Group>

      <QueryStateBoundary
        isLoading={false}
        isError={events.isError}
        error={events.error}
        onRetry={() => void events.refetch()}
      >
        <CalendarView
          events={shown}
          isLoading={events.isLoading}
          isRefreshing={events.isPlaceholderData}
          onDateRangeChange={handleDateRangeChange}
          monthEmpty={{
            allEvents: eventsData?.events ?? [],
            keep: (event) => keepCalendarEvent(event, filters),
            activeFilters:
              filters.filter === 'all'
                ? []
                : [t(`agenda.type.${filters.filter satisfies 'ride' | 'trip'}`)],
            onClearFilters: () => setFilters({ filter: 'all' }),
            scope: 'mine',
            loadedTo: dateRange.to,
            probeKey: 'mine',
            probe: (from, to) => getEvents({ from, to }, LIST_REQUEST),
          }}
        />
      </QueryStateBoundary>

      <IcsFeedSettings />
    </Stack>
  )
}
