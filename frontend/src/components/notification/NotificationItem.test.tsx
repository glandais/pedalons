import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import fr from '@/locales/fr/common.json'
import type { NotificationDto } from '@/api/dto'
import { NotificationChange, NotificationSubjectType, NotificationType } from '@/api/dto'

// The French catalog's wording, interpolated: the reader is in Europe/Paris (Vitest's fixed zone,
// no signed-in user).
vi.mock('react-i18next', async (importOriginal) => ({
  ...(await importOriginal<typeof import('react-i18next')>()),
  useTranslation: () => ({
    t: (key: string, options: Record<string, string> = {}) =>
      ((fr as Record<string, string>)[key] ?? key).replace(
        /\{\{(\w+)\}\}/g,
        (_: string, name: string) => options[name] ?? ''
      ),
    i18n: { language: 'fr' },
  }),
}))

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

import { NotificationItem } from './NotificationItem'

function notification(overrides: Partial<NotificationDto>): NotificationDto {
  return {
    id: 'n1',
    type: NotificationType.RIDE_REMINDER,
    read: false,
    createdAt: '2026-10-07T10:00:00Z',
    teamSlug: 'np',
    teamName: 'Nantes Pédale',
    subjectType: NotificationSubjectType.RIDE,
    subjectSlug: 'sortie',
    subjectName: 'Sortie du dimanche',
    changes: [],
    ...overrides,
  }
}

function details(dto: NotificationDto): string | null {
  render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <NotificationItem notification={dto} onOpen={() => {}} />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
  const line = screen.queryByText(
    (_, el) => el?.tagName === 'P' && /Départ|Nouvelle|Nouveau/.test(el.textContent ?? '')
  )
  return line?.textContent ?? null
}

// docs/LEDGER_*.md API-60, plan §7: the subject's date is a rendezvous, read in its own zone.
describe('NotificationItem', () => {
  // « Now » in 2026: the year is said only outside the current one, « Demain » only tomorrow
  // (docs/BRANDING.md §8.3, docs/LEDGER_*.md WEB-138).
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ['Date'] })
    vi.setSystemTime(new Date('2026-10-01T10:00:00Z'))
  })
  afterEach(() => {
    cleanup()
    vi.useRealTimers()
  })

  it('reads a reminder in the ride’s zone, with the mention when the reader’s offset differs', () => {
    // Sunday 11 October 2026, 06:00 in Tokyo = Saturday 23:00 in Paris.
    expect(
      details(
        notification({ subjectDateTime: '2026-10-10T21:00:00Z', subjectTimezone: 'Asia/Tokyo' })
      )
    ).toBe('Départ : dim. 11 oct. · 06:00 · heure de Tokyo (sam. 23:00 chez vous)')
  })

  it('says « Demain » for tomorrow, the year outside the current one (WEB-138)', () => {
    expect(
      details(
        notification({ subjectDateTime: '2026-10-02T07:00:00Z', subjectTimezone: 'Europe/Paris' })
      )
    ).toBe('Départ : Demain · 09:00')
    cleanup()
    expect(
      details(
        notification({ subjectDateTime: '2027-04-10T07:00:00Z', subjectTimezone: 'Europe/Paris' })
      )
    ).toBe('Départ : sam. 10 avr. 2027 · 09:00')
  })

  it('says nothing more when the ride’s zone has the reader’s offset', () => {
    expect(
      details(
        notification({
          subjectDateTime: '2026-10-11T06:00:00Z',
          subjectTimezone: 'Europe/Brussels',
        })
      )
    ).toBe('Départ : dim. 11 oct. · 08:00')
  })

  it('falls back to the reader’s zone, without mention, for a notification with no zone', () => {
    expect(details(notification({ subjectDateTime: '2026-10-10T21:00:00Z' }))).toBe(
      'Départ : sam. 10 oct. · 23:00'
    )
  })

  it('puts the dated change last, so the mention follows its date', () => {
    expect(
      details(
        notification({
          type: NotificationType.RIDE_UPDATED,
          subjectDateTime: '2026-10-10T21:00:00Z',
          subjectTimezone: 'Asia/Tokyo',
          changes: [NotificationChange.DATE_TIME, NotificationChange.START_PLACE],
        })
      )
    ).toBe(
      `${fr['notifications.change.START_PLACE']} · Nouvelle date : dim. 11 oct. · 06:00 · heure de Tokyo (sam. 23:00 chez vous)`
    )
  })

  it('adds no mention to a change that carries no date', () => {
    expect(
      details(
        notification({
          type: NotificationType.RIDE_UPDATED,
          subjectDateTime: '2026-10-10T21:00:00Z',
          subjectTimezone: 'Asia/Tokyo',
          changes: [NotificationChange.START_PLACE],
        })
      )
    ).toBe(fr['notifications.change.START_PLACE'])
  })
})
