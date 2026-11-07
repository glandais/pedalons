import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest'
import type { TFunction } from 'i18next'
import { createServerI18n } from '@/i18n'
import {
  formatDateTime,
  formatDeparture,
  formatDepartureDay,
  formatLongDay,
  formatRelativeDay,
  relativeDay,
} from './dateFormat'

// The departure's one format (docs/BRANDING.md §8.3, ledger BRAND-8, docs/LEDGER_*.md WEB-137).
// « Now » is Friday 10 April 2026, 12:00 in Paris.
const NOW = new Date('2026-04-10T10:00:00Z')
const PARIS = 'Europe/Paris'

let fr: TFunction
let en: TFunction
beforeAll(async () => {
  fr = (await createServerI18n('fr')).t
  en = (await createServerI18n('en')).t
})

describe('formatDeparture', () => {
  it('gives the short day and the time, without the current year', () => {
    expect(formatDeparture('2026-04-25T07:00:00Z', 'fr', PARIS, fr, { now: NOW })).toBe(
      'sam. 25 avr. · 09:00'
    )
    expect(formatDeparture('2026-04-25T07:00:00Z', 'en', PARIS, en, { now: NOW })).toBe(
      'Sat, Apr 25 · 9:00 AM'
    )
  })

  it('adds the year outside the current one', () => {
    expect(formatDeparture('2027-04-10T07:00:00Z', 'fr', PARIS, fr, { now: NOW })).toBe(
      'sam. 10 avr. 2027 · 09:00'
    )
    expect(formatDeparture('2027-04-10T07:00:00Z', 'en', PARIS, en, { now: NOW })).toBe(
      'Sat, Apr 10, 2027 · 9:00 AM'
    )
  })

  it('says today and tomorrow, and only those', () => {
    expect(formatDeparture('2026-04-10T16:00:00Z', 'fr', PARIS, fr, { now: NOW })).toBe(
      "Aujourd'hui · 18:00"
    )
    expect(formatDeparture('2026-04-11T07:00:00Z', 'fr', PARIS, fr, { now: NOW })).toBe(
      'Demain · 09:00'
    )
    expect(formatDeparture('2026-04-11T07:00:00Z', 'en', PARIS, en, { now: NOW })).toBe(
      'Tomorrow · 9:00 AM'
    )
    // The day after tomorrow and yesterday are dated.
    expect(formatDeparture('2026-04-12T07:00:00Z', 'fr', PARIS, fr, { now: NOW })).toBe(
      'dim. 12 avr. · 09:00'
    )
    expect(formatDeparture('2026-04-09T07:00:00Z', 'fr', PARIS, fr, { now: NOW })).toBe(
      'jeu. 9 avr. · 09:00'
    )
  })

  it('keeps the absolute day when asked to', () => {
    expect(
      formatDeparture('2026-04-11T07:00:00Z', 'fr', PARIS, fr, { now: NOW, relative: false })
    ).toBe('sam. 11 avr. · 09:00')
  })

  it('judges today, tomorrow and the year in the departure’s zone', () => {
    // 23:30 in Paris on 10 April is already 11 April, 06:30 in Tokyo: tomorrow there.
    const late = new Date('2026-04-10T21:30:00Z')
    expect(relativeDay('2026-04-10T22:00:00Z', 'Asia/Tokyo', late)).toBe('today')
    expect(relativeDay('2026-04-10T22:00:00Z', PARIS, late)).toBe('tomorrow')
    // New Year's Eve in Paris, already 2027 in Tokyo.
    const eve = new Date('2026-12-31T20:00:00Z')
    expect(formatDeparture('2027-01-05T00:00:00Z', 'fr', 'Asia/Tokyo', fr, { now: eve })).toBe(
      'mar. 5 janv. · 09:00'
    )
  })

  it('is empty for no date', () => {
    expect(formatDeparture(null, 'fr', PARIS, fr)).toBe('')
  })
})

describe('formatRelativeDay', () => {
  it('names today and tomorrow, nothing else', () => {
    expect(formatRelativeDay('2026-04-10T16:00:00Z', PARIS, fr, NOW)).toBe("Aujourd'hui")
    expect(formatRelativeDay('2026-04-11T07:00:00Z', PARIS, fr, NOW)).toBe('Demain')
    expect(formatRelativeDay('2026-04-11T07:00:00Z', PARIS, en, NOW)).toBe('Tomorrow')
    expect(formatRelativeDay('2026-04-12T07:00:00Z', PARIS, fr, NOW)).toBeNull()
    expect(formatRelativeDay('2026-04-09T07:00:00Z', PARIS, fr, NOW)).toBeNull()
    expect(formatRelativeDay(undefined, PARIS, fr, NOW)).toBeNull()
  })

  it('crosses a month end', () => {
    expect(relativeDay('2026-05-01T07:00:00Z', PARIS, new Date('2026-04-30T10:00:00Z'))).toBe(
      'tomorrow'
    )
  })
})

describe('formatLongDay', () => {
  it('spells the day out, the year only outside the current one', () => {
    expect(formatLongDay('2026-04-25T07:00:00Z', 'fr', PARIS, fr, NOW)).toBe('samedi 25 avril')
    expect(formatLongDay('2027-04-10T07:00:00Z', 'fr', PARIS, fr, NOW)).toBe('samedi 10 avril 2027')
    expect(formatLongDay('2026-04-25T07:00:00Z', 'en', PARIS, en, NOW)).toBe('Saturday, April 25')
  })
})

// docs/LEDGER_*.md WEB-138: the site has one abbreviated day and one date-and-time format.
describe('formatDepartureDay', () => {
  it('abbreviates the day, the year only outside the current one', () => {
    expect(formatDepartureDay('2026-04-25T07:00:00Z', 'fr', PARIS, fr, NOW)).toBe('sam. 25 avr.')
    expect(formatDepartureDay('2027-04-10T07:00:00Z', 'fr', PARIS, fr, NOW)).toBe(
      'sam. 10 avr. 2027'
    )
    expect(formatDepartureDay('2026-04-25T07:00:00Z', 'en', PARIS, en, NOW)).toBe('Sat, Apr 25')
  })
})

describe('formatDateTime', () => {
  afterEach(() => vi.useRealTimers())

  it('reads as the departure, never relative: no more « samedi 11 avril 2026 à 09:00 »', () => {
    vi.useFakeTimers({ toFake: ['Date'] })
    vi.setSystemTime(NOW)
    expect(formatDateTime('2026-04-11T07:00:00Z', 'fr', PARIS)).toBe('sam. 11 avr. · 09:00')
    expect(formatDateTime('2027-04-10T07:00:00Z', 'fr', PARIS)).toBe('sam. 10 avr. 2027 · 09:00')
    expect(formatDateTime('2026-04-11T07:00:00Z', 'en', PARIS)).toBe('Sat, Apr 11 · 9:00 AM')
  })
})
