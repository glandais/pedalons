import { useTranslation } from 'react-i18next'
import { Group, SegmentedControl } from '@mantine/core'
import type { TeamDetailDto } from '@/api/dto'
import type { AgendaTypeValue } from '@/hooks/filters/agendaFilters'
import { useAuth } from '@/hooks/useAuth'

/** The period the bar offers: « Toutes les dates » or « Tout », and « Je participe ». */
export type AgendaBarScope = 'all' | 'me'

interface AgendaFilterBarProps {
  team: Pick<TeamDetailDto, 'enableRides' | 'enableTrips' | 'enableRoutes'>
  /**
   * `list`: « Toutes les dates / Je participe » (RL15) — the list holds both sections, « À venir »
   * then « Plus tôt ». `calendar`: « Tout / Je participe », browsed by month.
   */
  mode: 'list' | 'calendar'
  scope: AgendaBarScope
  onScopeChange: (scope: AgendaBarScope) => void
  type: AgendaTypeValue
  onTypeChange: (type: AgendaTypeValue) => void
}

/**
 * The agenda's criteria, shared by its list (`TeamAgendaPage`) and its calendar view
 * (`TeamCalendarPage`): the period, then the kind — « Tout / Sorties / Voyages », each kind only
 * when the team has its module (a ride or a trip needs the routes too). « Je participe » is for a
 * signed-in reader only: `participating` yields nothing for an anonymous one.
 */
export function AgendaFilterBar({
  team,
  mode,
  scope,
  onScopeChange,
  type,
  onTypeChange,
}: AgendaFilterBarProps) {
  const { t } = useTranslation()
  const { isAuthenticated } = useAuth()

  const me = isAuthenticated ? [{ value: 'me', label: t('publications.scope.me') }] : []
  const scopes = [
    {
      value: 'all',
      label: mode === 'calendar' ? t('agenda.scope.all') : t('agenda.scope.allDates'),
    },
    ...me,
  ]

  const rides = !!team.enableRides && !!team.enableRoutes
  const trips = !!team.enableTrips && !!team.enableRoutes

  return (
    <Group gap="sm" wrap="wrap" align="center">
      {/* Without « Je participe », a period with one value is no choice: an anonymous reader
          gets none. */}
      {isAuthenticated && (
        <SegmentedControl
          value={scope}
          onChange={(next) => onScopeChange(next as AgendaBarScope)}
          data={scopes}
          aria-label={t('agenda.scope.label')}
        />
      )}
      {/* Shown with a single kind too: its tags are only offered once it is picked. */}
      {(rides || trips) && (
        <AgendaTypeControl rides={rides} trips={trips} value={type} onChange={onTypeChange} />
      )}
    </Group>
  )
}

interface AgendaTypeControlProps {
  /** Offer « Sorties »: false hides it (a team without the module). */
  rides: boolean
  /** Offer « Voyages ». */
  trips: boolean
  value: AgendaTypeValue
  onChange: (type: AgendaTypeValue) => void
}

/**
 * The kind selector « Tout / Sorties / Voyages » alone — the agenda bar's, and the personal
 * calendar's (`CalendarPage`), which spans every team and so offers both kinds.
 */
export function AgendaTypeControl({ rides, trips, value, onChange }: AgendaTypeControlProps) {
  const { t } = useTranslation()
  const types = [
    { value: 'all', label: t('agenda.type.all') },
    ...(rides ? [{ value: 'ride', label: t('agenda.type.ride') }] : []),
    ...(trips ? [{ value: 'trip', label: t('agenda.type.trip') }] : []),
  ]
  return (
    <SegmentedControl
      value={value}
      onChange={(next) => onChange(next as AgendaTypeValue)}
      data={types}
      aria-label={t('agenda.type.label')}
    />
  )
}
