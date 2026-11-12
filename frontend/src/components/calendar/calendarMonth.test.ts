import { describe, expect, it } from 'vitest'
import type { CalendarEventDto } from '@/api/dto'
import { firstEventMonth, monthBounds, overlaps } from './calendarMonth'

const ev = (start: string, end?: string) => ({ id: start, start, end }) as CalendarEventDto

describe('calendarMonth', () => {
  it('bounds the month from its first midnight in the zone', () => {
    const { start, end } = monthBounds('2026-11-12', 'Europe/Paris')
    expect(start.toISOString()).toBe('2026-10-31T23:00:00.000Z')
    expect(end.toISOString()).toBe('2026-11-30T23:00:00.000Z')
  })

  it('an event shows in the month it begins in, or the one it runs into', () => {
    const { start, end } = monthBounds('2026-11-12', 'UTC')
    expect(overlaps(ev('2026-11-30T20:00:00Z'), start, end)).toBe(true)
    expect(overlaps(ev('2026-10-31T20:00:00Z', '2026-11-02T10:00:00Z'), start, end)).toBe(true)
    expect(overlaps(ev('2026-12-01T08:00:00Z'), start, end)).toBe(false)
  })

  it('finds the first month after, within the look-ahead, as the calendar’s date', () => {
    const events = [
      ev('2027-02-03T08:00:00Z'),
      ev('2027-01-20T08:00:00Z'),
      ev('2026-10-01T08:00:00Z'),
    ]
    const after = new Date('2026-12-01T00:00:00Z')
    expect(firstEventMonth(events, after, new Date('2027-06-01T00:00:00Z'), 'UTC')).toBe(
      '2027-01-01'
    )
    expect(firstEventMonth(events, after, new Date('2027-01-01T00:00:00Z'), 'UTC')).toBeNull()
  })
})
