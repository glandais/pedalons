import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { Title, Group, Stack } from '@mantine/core'
import { getEvents, getTeamEvents } from '@/api/endpoints/calendar/calendar'
import { LIST_REQUEST } from '@/lib/listQuery'
import { AgendaTypeControl } from '@/components/agenda/AgendaFilterBar'
import { CalendarView } from '@/components/calendar/CalendarView'
import { IcsFeedSettings } from '@/components/calendar/IcsFeedSettings'
import { TeamScopeSelect } from '@/components/common/MembershipSelect'
import { ALL_MY_TEAMS } from '@/components/common/membershipLabel'
import { QueryStateBoundary } from '@/components/common/QueryStateBoundary'
import { keepCalendarEvent } from '@/hooks/filters/calendarFilters'
import { useCalendarData } from './calendarData'

/**
 * The personal calendar: every team's rides and trip stages, or one team's (`?team=`, RL2 and RL3)
 * — read through that team's own endpoint, as the app does. Its kind « Tout / Sorties / Voyages »
 * (`?type=`) filters the loaded window client-side, as the team calendar does — the API takes
 * `from`/`to` only, and the query key does not depend on the kind.
 */
export function CalendarPage(): React.ReactElement {
  const { t } = useTranslation()
  const { filters, setFilters, teams, events, dateRange, handleDateRangeChange } = useCalendarData()
  const { data: eventsData } = events
  const team = teams.find((candidate) => candidate.slug === filters.team)

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
        {teams.length > 1 && (
          <TeamScopeSelect
            teams={teams}
            value={filters.team ?? ALL_MY_TEAMS}
            onChange={(slug) => setFilters({ team: slug === ALL_MY_TEAMS ? undefined : slug })}
          />
        )}
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
            activeFilters: [
              ...(filters.filter === 'all'
                ? []
                : [t(`agenda.type.${filters.filter satisfies 'ride' | 'trip'}`)]),
              ...(team ? [team.name] : []),
            ],
            // RL4: the kind lifted, the scope back to « Toutes mes équipes ».
            onClearFilters: () => setFilters({ filter: 'all', team: undefined }),
            scope: filters.team ? 'team' : 'mine',
            loadedTo: dateRange.to,
            probeKey: filters.team ?? 'mine',
            probe: (from, to) =>
              filters.team
                ? getTeamEvents(filters.team, { from, to }, LIST_REQUEST)
                : getEvents({ from, to }, LIST_REQUEST),
          }}
        />
      </QueryStateBoundary>

      <IcsFeedSettings />
    </Stack>
  )
}
