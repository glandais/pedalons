import { useMemo } from 'react'
import { Navigate, useNavigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Group, Stack, Title } from '@mantine/core'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { getTeamEvents } from '@/api/endpoints/calendar/calendar'
import { LIST_REQUEST } from '@/lib/listQuery'
import { ListViewSwitch, type ListView } from '@/components/common/ListViewSwitch'
import { CalendarView } from '@/components/calendar/CalendarView'
import { IcsFeedSettings } from '@/components/calendar/IcsFeedSettings'
import { AgendaFilterBar } from '@/components/agenda/AgendaFilterBar'
import { TeamLayout } from '@/components/team/TeamLayout'
import { TeamUnavailable } from '@/components/team/TeamUnavailable'
import { QueryStateBoundary } from '@/components/common/QueryStateBoundary'
import { paths } from '@/config/paths'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { useUrlFilters } from '@/hooks/useUrlFilters'
import { useTeamCalendarData } from '@/pages/calendar/teamCalendarData'
import { keepCalendarEvent, teamCalendarFilterOptions } from '@/hooks/filters/calendarFilters'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'

/**
 * The agenda's calendar view, kept on its own path for the links already out there (ledger
 * `WEB-69`, plan 2026-10-06 §4). Browsed by month, so its period is « Tout / Je participe »
 * (`?w=me`) and its kind « Tout / Sorties / Voyages » (`?type=`), both applied to the events the
 * window already holds (`calendarFilters.ts`).
 */
export function TeamCalendarPage(): React.ReactElement {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const navigate = useNavigate()
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const { filters, setFilters } = useUrlFilters(teamCalendarFilterOptions)

  const { team, events, dateRange, handleDateRangeChange } = useTeamCalendarData(teamSlug)
  const { data: teamData, isLoading: isLoadingTeam } = team
  const { data: eventsData } = events

  const shown = useMemo(
    () => (eventsData?.events ?? []).filter((event) => keepCalendarEvent(event, filters)),
    [eventsData, filters]
  )

  useCanonicalPath(teamData ? paths.teamCalendar(teamData.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('teams.detail.tabs.agenda')} />
  }

  if (!teamData) {
    return (
      <TeamUnavailable
        error={team.error}
        isError={team.isError}
        onRetry={() => void team.refetch()}
      />
    )
  }

  // The calendar and its ICS feed are for the team's members (CalendarAccessChecker) — and a
  // platform admin, who passes every access check: anyone else gets the agenda's lists.
  if (!teamData.role && !isPlatformAdmin) {
    return <Navigate to={paths.teamAgenda(teamData.slug)} replace />
  }

  // Back to the agenda's list in the view picked, with the same kind and « Je participe ».
  const onViewChange = (view: ListView) => {
    if (view === 'calendar') return
    const query = new URLSearchParams()
    if (filters.filter !== 'all') query.set('type', filters.filter)
    if (filters.scope === 'me') query.set('w', 'me')
    if (view === 'row') query.set('view', 'row')
    const qs = query.toString()
    navigate(qs ? `${paths.teamAgenda(teamData.slug)}?${qs}` : paths.teamAgenda(teamData.slug))
  }

  return (
    <TeamLayout team={teamData} currentTab="agenda">
      <Stack>
        <Title order={2}>{t('teams.detail.tabs.agenda')}</Title>

        <Group justify="space-between" align="center" wrap="wrap" gap="sm">
          <AgendaFilterBar
            team={teamData}
            mode="calendar"
            scope={filters.scope}
            onScopeChange={(scope) => setFilters({ scope: scope === 'me' ? 'me' : 'all' })}
            type={filters.filter}
            onTypeChange={(filter) => setFilters({ filter })}
          />
          <ListViewSwitch
            views={['card', 'row', 'calendar']}
            value="calendar"
            onChange={onViewChange}
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
              activeFilters: [
                ...(filters.scope === 'me' ? [t('publications.scope.me')] : []),
                ...(filters.filter === 'all'
                  ? []
                  : [t(`agenda.type.${filters.filter satisfies 'ride' | 'trip'}`)]),
              ],
              onClearFilters: () => setFilters({ filter: 'all', scope: 'all' }),
              scope: 'team',
              loadedTo: dateRange.to,
              probeKey: teamData.slug,
              probe: (from, to) => getTeamEvents(teamData.slug, { from, to }, LIST_REQUEST),
            }}
          />
        </QueryStateBoundary>

        <IcsFeedSettings teamSlug={teamData.slug} />
      </Stack>
    </TeamLayout>
  )
}
