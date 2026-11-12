import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
import timezone from 'dayjs/plugin/timezone'
import type { CalendarEventDto } from '@/api/dto'

dayjs.extend(utc)
dayjs.extend(timezone)

/**
 * How many months ahead « Aller au prochain mois avec une sortie » looks — six, as the app
 * (`kCalendarLookaheadMonths`): past that, the answer no longer interests anyone.
 */
export const LOOKAHEAD_MONTHS = 6

/** The month `date` (a calendar date, `YYYY-MM-DD`) falls in, from its first midnight in `tz`. */
export function monthBounds(date: string, tz: string): { start: Date; end: Date } {
  const first = dayjs.utc(date).startOf('month').format('YYYY-MM-DD')
  const start = dayjs.tz(first, tz)
  return { start: start.toDate(), end: start.add(1, 'month').toDate() }
}

/** Whether `event` shows in `[start, end)`: it begins before the end and is not over before the start. */
export function overlaps(event: CalendarEventDto, start: Date, end: Date): boolean {
  const from = new Date(event.start).getTime()
  const to = new Date(event.end ?? event.start).getTime()
  return from < end.getTime() && to >= start.getTime()
}

/**
 * The first month, after `after`, holding an event that starts before `until` — its first day,
 * `YYYY-MM-DD`, in `tz`, the shape the calendar's `date` takes. Null when there is none.
 */
export function firstEventMonth(
  events: CalendarEventDto[],
  after: Date,
  until: Date,
  tz: string
): string | null {
  let first: CalendarEventDto | null = null
  for (const event of events) {
    const at = new Date(event.start).getTime()
    if (at < after.getTime() || at >= until.getTime()) continue
    if (!first || at < new Date(first.start).getTime()) first = event
  }
  return first ? dayjs(first.start).tz(tz).format('YYYY-MM-01') : null
}
