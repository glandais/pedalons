import { Button } from '@mantine/core'
import { IconCalendarOff } from '@tabler/icons-react'
import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import type { CalendarEventDto, CalendarEventsResponse } from '@/api/dto'
import { EmptyState } from '@/components/common/EmptyState'
import { FilteredEmptyState } from '@/components/common/FilteredEmptyState'
import { formatMonthYear } from '@/utils/dateFormat'
import { LOOKAHEAD_MONTHS, firstEventMonth, overlaps } from './calendarMonth'

/** What a calendar page tells its grid so the grid can say an empty month (RL10). */
export interface CalendarMonthEmptyConfig {
  /** Every event of the loaded window, before the page's filters. */
  allEvents: CalendarEventDto[]
  /** The page's filters, as it applies them to `allEvents`. */
  keep: (event: CalendarEventDto) => boolean
  /** The filters in force, named — empty when nothing narrows the calendar. */
  activeFilters: string[]
  onClearFilters: () => void
  /** « Vos équipes n'ont publié… » or « L'équipe n'a publié… ». */
  scope: 'mine' | 'team'
  /** The end of the loaded window (`useCalendarDateRange`'s `to`). */
  loadedTo: string
  /** Names the calendar in the look-ahead's query key: the team's slug, or `mine`. */
  probeKey: string
  /** Reads the events of `[from, to)` — one request, the page's own endpoint. */
  probe: (from: string, to: string) => Promise<CalendarEventsResponse>
}

interface CalendarMonthEmptyProps extends CalendarMonthEmptyConfig {
  month: { start: Date; end: Date }
  tz: string
  language: string
  onGoToMonth: (date: string) => void
}

/**
 * Under the grid of a month that shows nothing (docs/LEDGER_*.md WEB-175, RL10), as the app says it:
 * a month that holds events the filters hide is a filtered empty state, cleared in one gesture; a
 * month with nothing in it says so, in lower case (« en novembre 2026 »), and offers « Aller au
 * prochain mois avec une sortie » when one of the next six has an event the filters keep.
 *
 * The next month is looked for in the loaded window first — seven months from the current one, so
 * no request at all most of the time — and otherwise in one read of what lies beyond it, never one
 * read per month.
 */
export function CalendarMonthEmpty({
  allEvents,
  keep,
  activeFilters,
  onClearFilters,
  scope,
  loadedTo,
  probeKey,
  probe,
  month,
  tz,
  language,
  onGoToMonth,
}: CalendarMonthEmptyProps) {
  const { t } = useTranslation()

  const until = new Date(month.end)
  until.setUTCMonth(until.getUTCMonth() + LOOKAHEAD_MONTHS)
  const kept = allEvents.filter(keep)
  const monthHasEvents = allEvents.some((event) => overlaps(event, month.start, month.end))
  const filtered = activeFilters.length > 0 && monthHasEvents

  const inWindow = firstEventMonth(kept, month.end, until, tz)
  // The loaded window stops before the six months: what lies past it takes one read.
  const beyond =
    new Date(loadedTo) < until ? new Date(Math.max(+new Date(loadedTo), +month.end)) : null
  const probed = useQuery({
    queryKey: ['calendar-next-month', probeKey, beyond?.toISOString(), until.toISOString()],
    queryFn: () => probe(beyond!.toISOString(), until.toISOString()),
    enabled: !filtered && !inWindow && !!beyond,
    staleTime: 5 * 60 * 1000,
  })
  const next =
    inWindow ??
    (beyond && probed.data
      ? firstEventMonth(probed.data.events.filter(keep), beyond, until, tz)
      : null)

  if (filtered) {
    return <FilteredEmptyState resource="events" filters={activeFilters} onClear={onClearFilters} />
  }

  return (
    <EmptyState
      icon={<IconCalendarOff size={48} />}
      title={t('calendar.emptyMonth.title')}
      description={t(scope === 'team' ? 'calendar.emptyMonth.team' : 'calendar.emptyMonth.mine', {
        month: formatMonthYear(month.start, language, tz),
      })}
      actions={
        next ? (
          <Button variant="light" onClick={() => onGoToMonth(next)}>
            {t('calendar.emptyMonth.next')}
          </Button>
        ) : undefined
      }
    />
  )
}
