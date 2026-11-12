import { z } from 'zod'
import type { CalendarEventDto } from '@/api/dto'

/**
 * The calendars' filters, applied to the events the loaded window already holds —
 * `CalendarEventDto` carries `type` and `registered`, so the query key, and the route's prefetch,
 * do not depend on them. The kind (`?type=`) is the personal calendar's (`CalendarPage`) and the
 * team's; the period « Tout / Je participe » (`?w=me`) is the team calendar's only.
 */
const calendarTypeField = z.enum(['all', 'ride', 'trip']).default('all').catch('all')

export const calendarTypeFilterOptions = {
  schema: z.object({ filter: calendarTypeField }),
  alias: { filter: 'type' },
} as const

export const teamCalendarFiltersSchema = z.object({
  filter: calendarTypeField,
  scope: z.enum(['all', 'me']).default('all').catch('all'),
})

export const teamCalendarFilterOptions = {
  schema: teamCalendarFiltersSchema,
  alias: { filter: 'type', scope: 'w' },
} as const

export function keepCalendarEvent(
  event: CalendarEventDto,
  filters: { filter: z.infer<typeof calendarTypeField>; scope?: 'all' | 'me' }
): boolean {
  if (filters.scope === 'me' && !event.registered) return false
  if (filters.filter === 'ride') return event.type === 'RIDE'
  if (filters.filter === 'trip') return event.type === 'TRIP_STAGE'
  return true
}
