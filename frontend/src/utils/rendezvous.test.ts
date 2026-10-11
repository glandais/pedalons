import { describe, it, expect } from 'vitest'
import { createServerI18n } from '@/i18n'
import type { PublicationDto } from '@/api/dto'
import { rendezvousMention, tripEndZone } from './rendezvous'
import { formatPublicationSpan, type DatedPublication } from './publicationTiming'

// docs/LEDGER_*.md API-60, plan §7 and §11: the catalogs' own wording, interpolated.
const tFr = (await createServerI18n('fr')).t
const tEn = (await createServerI18n('en')).t

describe('rendezvousMention', () => {
  it('says nothing for Paris read from Brussels, summer and winter', () => {
    expect(
      rendezvousMention('2026-07-11T06:00:00Z', 'Europe/Paris', 'Europe/Brussels', 'fr', tFr)
    ).toBeNull()
    expect(
      rendezvousMention('2026-12-12T07:00:00Z', 'Europe/Paris', 'Europe/Brussels', 'fr', tFr)
    ).toBeNull()
  })

  it('names Tokyo read from Paris, with the reader’s time', () => {
    // Sunday 11 October 2026, 08:00 in Tokyo (UTC+9) = 01:00 the same Sunday in Paris (UTC+2).
    const mention = rendezvousMention(
      '2026-10-10T23:00:00Z',
      'Asia/Tokyo',
      'Europe/Paris',
      'fr',
      tFr
    )
    expect(mention).toEqual({
      label: 'heure de Tokyo',
      readerEquivalent: '01:00 chez vous',
      full: 'heure de Tokyo (01:00 chez vous)',
    })
  })

  it('gives the reader’s day when it is not the entity’s', () => {
    // Sunday 11 October 2026, 06:00 in Tokyo = Saturday 10 October, 23:00 in Paris.
    const mention = rendezvousMention(
      '2026-10-10T21:00:00Z',
      'Asia/Tokyo',
      'Europe/Paris',
      'fr',
      tFr
    )
    expect(mention?.full).toBe('heure de Tokyo (sam. 23:00 chez vous)')
  })

  it('follows the language’s 12/24 h rule in English', () => {
    const mention = rendezvousMention(
      '2026-10-10T21:00:00Z',
      'Asia/Tokyo',
      'Europe/Paris',
      'en',
      tEn
    )
    expect(mention?.full).toBe('Tokyo time (Sat 11:00 PM your time)')
  })

  it('compares offsets at the event’s instant: London and UTC across summer time', () => {
    expect(rendezvousMention('2026-12-12T08:00:00Z', 'Europe/London', 'UTC', 'fr', tFr)).toBeNull()
    expect(
      rendezvousMention('2026-07-11T08:00:00Z', 'Europe/London', 'UTC', 'fr', tFr)?.label
    ).toBe('heure de Londres')
  })

  it('says nothing without a zone or an instant', () => {
    expect(
      rendezvousMention('2026-10-10T21:00:00Z', undefined, 'Europe/Paris', 'fr', tFr)
    ).toBeNull()
    expect(rendezvousMention(undefined, 'Asia/Tokyo', 'Europe/Paris', 'fr', tFr)).toBeNull()
  })

  it('says nothing while the reader’s zone is unknown (the server’s placeholder)', () => {
    expect(rendezvousMention('2026-10-10T21:00:00Z', 'Europe/Paris', null, 'fr', tFr)).toBeNull()
  })

  it('says nothing, and does not throw, for a zone this runtime’s Intl does not know', () => {
    expect(
      rendezvousMention('2026-10-10T21:00:00Z', 'Mars/Olympus_Mons', 'Europe/Paris', 'fr', tFr)
    ).toBeNull()
  })
})

describe('tripEndZone', () => {
  it('is the last stage’s zone, else the trip’s', () => {
    expect(
      tripEndZone({
        timezone: 'Europe/Paris',
        stages: [
          { dateTime: '2026-10-18T00:00:00Z', timezone: 'Asia/Tokyo' },
          { dateTime: '2026-10-16T06:00:00Z', timezone: 'Europe/Paris' },
        ],
      })
    ).toBe('Asia/Tokyo')
    expect(tripEndZone({ timezone: 'Europe/Paris', stages: [] })).toBe('Europe/Paris')
    expect(tripEndZone({ timezone: 'Europe/Paris' })).toBe('Europe/Paris')
  })

  it('skips a zone this runtime’s Intl does not know', () => {
    expect(
      tripEndZone({
        timezone: 'Europe/Paris',
        stages: [{ dateTime: '2026-10-18T00:00:00Z', timezone: 'Mars/Olympus_Mons' }],
      })
    ).toBe('Europe/Paris')
    expect(tripEndZone({ timezone: 'Mars/Olympus_Mons' })).toBeUndefined()
  })
})

function dated(overrides: Record<string, unknown>): DatedPublication {
  return {
    type: 'RIDE',
    status: 'PUBLISHED',
    timezone: 'Europe/Paris',
    ...overrides,
  } as unknown as PublicationDto as DatedPublication
}

describe('formatPublicationSpan', () => {
  it('reads a ride in its own zone, whatever the reader’s', () => {
    // 08:30 → 14:10 in Tokyo.
    const ride = dated({
      timezone: 'Asia/Tokyo',
      dateTime: '2026-10-10T23:30:00Z',
      endDateTime: '2026-10-11T05:10:00Z',
    })
    expect(formatPublicationSpan(ride, 'time', 'fr', tFr)).toBe('08:30 → retour vers 14:10')
  })

  it('falls back to the reader’s zone for a zone this runtime’s Intl does not know', () => {
    const ride = dated({
      timezone: 'Mars/Olympus_Mons',
      dateTime: '2026-10-10T23:30:00Z',
      endDateTime: '2026-10-11T05:10:00Z',
    })
    expect(formatPublicationSpan(ride, 'time', 'fr', tFr, 'Asia/Tokyo')).toBe(
      '08:30 → retour vers 14:10'
    )
  })

  it('judges « same day » on the entity’s wall clock', () => {
    // 20:00 → 23:30 in Paris is one day there, two in UTC+9.
    const ride = dated({
      dateTime: '2026-10-11T18:00:00Z',
      endDateTime: '2026-10-11T21:30:00Z',
    })
    expect(formatPublicationSpan(ride, 'time', 'fr', tFr, 'Asia/Tokyo')).toBe(
      '20:00 → retour vers 23:30'
    )
  })

  it('reads a multi-zone trip’s first day in its zone and its last in the last stage’s', () => {
    // Friday 16 October, 08:00 in Paris → Sunday 18 October, 05:00 in Tokyo (still Saturday in
    // Paris).
    const trip = dated({
      type: 'TRIP',
      dateTime: '2026-10-16T06:00:00Z',
      endDateTime: '2026-10-17T20:00:00Z',
      stages: [
        { dateTime: '2026-10-16T06:00:00Z', timezone: 'Europe/Paris' },
        { dateTime: '2026-10-17T19:00:00Z', timezone: 'Asia/Tokyo' },
      ],
    })
    expect(formatPublicationSpan(trip, 'full', 'fr', tFr)).toBe('ven. 16 → dim. 18 oct.')
    // A list row carries no stages: the trip's zone for both ends.
    expect(
      formatPublicationSpan({ ...trip, stages: [] } as DatedPublication, 'full', 'fr', tFr)
    ).toBe('ven. 16 → sam. 17 oct.')
  })
})
