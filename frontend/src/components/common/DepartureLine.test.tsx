import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import type { CalendarEventDto, RideDto, TripDto, TripStageDto } from '@/api/dto'
import { plain } from '@/test/weatherFixtures'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))
vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { DepartureLine } from './DepartureLine'
import { DayBox } from './DayBox'
import { AgendaRow } from '@/components/agenda/AgendaRow'
import { TripStageCard } from '@/components/trip/TripStageCard'
import { WeekAgenda } from '@/components/home/WeekAgenda'

function renderIn(node: ReactNode) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>{node}</MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

const line = () => plain(screen.getByTestId('departure-line').textContent)

const TEAM_REF = { id: 't1', name: 'VC Craponne', slug: 'vc-craponne', visibility: 'PUBLIC' }
const MEDIA = { markdown: '', assets: { images: [], attachments: [] } }

// docs/BRANDING.md §7.8 and §8.3, docs/LEDGER_*.md WEB-138. The reader is in Paris (Vitest's
// zone), « now » Friday 10 April 2026 at noon.
beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] })
  vi.setSystemTime(new Date('2026-04-10T10:00:00Z'))
})
afterEach(() => {
  cleanup()
  vi.useRealTimers()
})

describe('DepartureLine', () => {
  it('says « Départ 09:00 » in 700, then the return, dimmed', () => {
    renderIn(
      <DepartureLine
        date="2026-04-11T07:00:00Z"
        zone="Europe/Paris"
        returnAt="2026-04-11T12:10:00Z"
      />
    )
    expect(line()).toBe('Départ 09:00 · retour vers 14:10')
    expect(screen.getByText('Départ 09:00').style.fontWeight).toBe('700')
  })

  it('dates a return on another day', () => {
    renderIn(
      <DepartureLine
        date="2026-04-11T19:00:00Z"
        zone="Europe/Paris"
        returnAt="2026-04-11T23:30:00Z"
      />
    )
    expect(line()).toBe('Départ 21:00 · retour vers dim. 12 avr. · 01:30')
  })

  it('names the day without a day box beside it: relative for tomorrow, the year outside 2026', () => {
    renderIn(<DepartureLine date="2026-04-11T07:00:00Z" zone="Europe/Paris" withDay />)
    expect(line()).toBe('Demain · 09:00')
    cleanup()
    renderIn(<DepartureLine date="2026-04-18T07:00:00Z" zone="Europe/Paris" withDay />)
    expect(line()).toBe('sam. 18 avr. · 09:00')
    cleanup()
    renderIn(<DepartureLine date="2027-04-10T07:00:00Z" zone="Europe/Paris" withDay />)
    expect(line()).toBe('sam. 10 avr. 2027 · 09:00')
  })

  it('reads the entity’s zone, with its indicator', () => {
    // 09:00 in Tokyo is 02:00 in Paris.
    renderIn(<DepartureLine date="2026-04-18T00:00:00Z" zone="Asia/Tokyo" />)
    expect(screen.getByText('Départ 09:00')).toBeTruthy()
    expect(
      within(screen.getByTestId('departure-line')).getByRole('img', {
        name: /heure de Tokyo \(02:00 chez vous\)/,
      })
    ).toBeTruthy()
  })

  it('announces the day of a hidden day box', () => {
    renderIn(<DepartureLine date="2026-04-11T07:00:00Z" zone="Europe/Paris" announceDay />)
    expect(line()).toBe('samedi 11 avril, Départ 09:00')
  })
})

describe('DayBox', () => {
  it('is flat by default and posed on a picture', () => {
    renderIn(<DayBox date="2026-04-11T07:00:00Z" zone="Europe/Paris" />)
    expect(screen.getByTestId('day-box').getAttribute('data-variant')).toBe('flat')
    cleanup()
    renderIn(<DayBox date="2026-04-11T07:00:00Z" zone="Europe/Paris" variant="posed" />)
    const box = screen.getByTestId('day-box')
    expect(box.getAttribute('data-variant')).toBe('posed')
    expect(box.textContent).toBe('sam.11avr.')
  })
})

describe('the departure on the screens migrated by WEB-138', () => {
  it('AgendaRow: the day box, then the departure line out of the statistics', () => {
    const ride = {
      type: 'RIDE',
      team: TEAM_REF,
      id: 'r1',
      slug: 'boucle',
      name: 'Boucle',
      media: MEDIA,
      dateTime: '2026-04-11T07:00:00Z',
      endDateTime: '2026-04-11T12:10:00Z',
      timezone: 'Europe/Paris',
      status: 'PUBLISHED',
      visibility: 'PUBLIC',
      participantCount: 4,
      groupCount: 2,
      groupSummaries: [],
      registered: false,
    } as unknown as RideDto
    renderIn(<AgendaRow publication={ride} />)
    expect(screen.getByTestId('day-box').textContent).toBe('sam.11avr.')
    expect(line()).toBe('Départ 09:00 · retour vers 14:10')
  })

  it('AgendaRow: a trip’s span, on a turquoise line', () => {
    const trip = {
      type: 'TRIP',
      team: TEAM_REF,
      id: 'tr1',
      slug: 'raid',
      name: 'Raid',
      media: MEDIA,
      dateTime: '2026-05-15T06:00:00Z',
      endDateTime: '2026-05-17T15:00:00Z',
      timezone: 'Europe/Paris',
      status: 'PUBLISHED',
      visibility: 'PUBLIC',
      participantCount: 4,
      stageCount: 3,
      registered: false,
    } as unknown as TripDto
    renderIn(<AgendaRow publication={trip} />)
    expect(line()).toBe('ven. 15 → dim. 17 mai')
  })

  it('TripStageCard: « Demain · 09:00 », not the long date', () => {
    const stage = {
      id: 's1',
      slug: 'etape-1',
      name: 'Étape au long nom qui ne doit pas être tronqué par la date',
      dateTime: '2026-04-11T07:00:00Z',
      timezone: 'Europe/Paris',
      media: MEDIA,
    } as unknown as TripStageDto
    renderIn(<TripStageCard stage={stage} index={0} teamSlug="t" tripSlug="raid" />)
    expect(line()).toBe('Demain · 09:00')
  })

  it('WeekAgenda: the day box of every list and the time in 700', () => {
    const event: CalendarEventDto = {
      id: 'e1',
      title: 'Boucle',
      start: '2026-04-11T07:00:00Z',
      allDay: false,
      type: 'RIDE',
      teamSlug: 't',
      teamName: 'VC Craponne',
      entitySlug: 'boucle',
      registered: false,
      status: 'PUBLISHED',
      timezone: 'Europe/Paris',
      finished: false,
    }
    renderIn(<WeekAgenda nowIso="2026-04-10T10:00:00Z" events={[event]} isLoading={false} />)
    expect(screen.getByTestId('day-box').textContent).toBe('sam.11avr.')
    expect(screen.getByText('09:00').style.fontWeight).toBe('700')
  })
})
