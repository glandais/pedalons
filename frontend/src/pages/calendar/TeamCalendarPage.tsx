import { useMemo } from 'react'
import { Navigate, useNavigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Group, Stack, Title } from '@mantine/core'
import { z } from 'zod'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { ListViewSwitch, type ListView } from '@/components/common/ListViewSwitch'
import { CalendarView } from '@/components/calendar/CalendarView'
import { IcsFeedSettings } from '@/components/calendar/IcsFeedSettings'
import { AgendaFilterBar } from '@/components/agenda/AgendaFilterBar'
import { TeamLayout } from '@/components/team/TeamLayout'
import { paths } from '@/config/paths'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { useUrlFilters } from '@/hooks/useUrlFilters'
import { useTeamCalendarData } from '@/pages/calendar/teamCalendarData'
import type { CalendarEventDto } from '@/api/dto'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'

/**
 * The agenda's calendar view, kept on its own path for the links already out there (ledger
 * `WEB-69`, plan 2026-10-06 §4). Browsed by month, so its period is « Tout / Je participe »
 * (`?w=me`) and its kind « Tout / Sorties / Voyages » (`?type=`), both applied to the events the
 * window already holds — `CalendarEventDto` carries `type` and `registered`, so the query key, and
 * the route's prefetch, do not depend on them.
 */
const calendarFiltersSchema = z.object({
  filter: z.enum(['all', 'ride', 'trip']).default('all').catch('all'),
  scope: z.enum(['all', 'me']).default('all').catch('all'),
})
const calendarFilterOptions = {
  schema: calendarFiltersSchema,
  alias: { filter: 'type', scope: 'w' },
} as const

function keepEvent(
  event: CalendarEventDto,
  filters: z.infer<typeof calendarFiltersSchema>
): boolean {
  if (filters.scope === 'me' && !event.registered) return false
  if (filters.filter === 'ride') return event.type === 'RIDE'
  if (filters.filter === 'trip') return event.type === 'TRIP_STAGE'
  return true
}

export function TeamCalendarPage(): React.ReactElement {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const navigate = useNavigate()
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const { filters, setFilters } = useUrlFilters(calendarFilterOptions)

  const { team, events, handleDateRangeChange } = useTeamCalendarData(teamSlug)
  const { data: teamData, isLoading: isLoadingTeam } = team
  const { data: eventsData, isFetching: isFetchingEvents } = events

  const shown = useMemo(
    () => (eventsData?.events ?? []).filter((event) => keepEvent(event, filters)),
    [eventsData, filters]
  )

  useCanonicalPath(teamData ? paths.teamCalendar(teamData.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('teams.detail.tabs.agenda')} />
  }

  if (!teamData) {
    return <Navigate to={paths.teams()} replace />
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

        <CalendarView
          events={shown}
          isLoading={isFetchingEvents}
          onDateRangeChange={handleDateRangeChange}
        />

        <IcsFeedSettings teamSlug={teamData.slug} />
      </Stack>
    </TeamLayout>
  )
}
