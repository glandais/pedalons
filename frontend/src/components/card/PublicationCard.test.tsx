import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { PostDto, PublicationDto, RideDto, TripDto } from '@/api/dto'
import { plain } from '@/test/weatherFixtures'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))
vi.mock('@/config/appConfig', () => ({ isSingleTeam: () => false }))
vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { PublicationCard } from './PublicationCard'

const TEAM_REF = { id: 't1', name: 'VC Craponne', slug: 'vc-craponne', visibility: 'PUBLIC' }
const MEDIA = { markdown: '', assets: { images: [], attachments: [] } }

function ride(overrides: Partial<RideDto> = {}): RideDto {
  return {
    type: 'RIDE',
    team: TEAM_REF,
    id: 'r1',
    slug: 'boucle',
    name: 'Boucle de la vallée',
    media: MEDIA,
    // Saturday 11 April 2026, 09:00 → 14:10 in Paris.
    dateTime: '2026-04-11T07:00:00Z',
    endDateTime: '2026-04-11T12:10:00Z',
    timezone: 'Europe/Paris',
    status: 'PUBLISHED',
    finished: false,
    visibility: 'TEAM',
    participantCount: 12,
    groupCount: 3,
    groups: [],
    groupSummaries: [],
    topParticipants: [],
    deleted: false,
    registered: false,
    full: false,
    tags: [],
    commentCount: 2,
    ...overrides,
  } as RideDto
}

function trip(overrides: Partial<TripDto> = {}): TripDto {
  return {
    type: 'TRIP',
    team: TEAM_REF,
    id: 'tr1',
    slug: 'raid',
    name: 'Raid des Cévennes',
    media: MEDIA,
    // Friday 15 → Sunday 17 May 2026 in Paris.
    dateTime: '2026-05-15T06:00:00Z',
    endDateTime: '2026-05-17T15:00:00Z',
    timezone: 'Europe/Paris',
    status: 'PUBLISHED',
    finished: false,
    visibility: 'TEAM',
    participantCount: 5,
    stageCount: 3,
    participants: [],
    deleted: false,
    registered: false,
    tags: [],
    ...overrides,
  } as TripDto
}

function renderCard(publication: PublicationDto) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <PublicationCard publication={publication} showTeam={false} />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

const text = () => plain(document.body.textContent)

// docs/BRANDING.md §7.1, docs/LEDGER_*.md WEB-138 (rule BRAND-8, option A). The reader is in Paris
// (Vitest's zone), « now » Friday 10 April 2026 at noon.
describe('PublicationCard: the departure is primary', () => {
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ['Date'] })
    vi.setSystemTime(new Date('2026-04-10T10:00:00Z'))
  })
  afterEach(() => {
    cleanup()
    vi.useRealTimers()
  })

  it('poses the day box on the picture', () => {
    renderCard(ride())
    const box = screen.getByTestId('day-box')
    expect(box.textContent).toBe('sam.11avr.')
    expect(box.getAttribute('data-variant')).toBe('posed')
  })

  it('carries the « Demain » pill tomorrow, « Aujourd’hui » today, none on another day', () => {
    renderCard(ride())
    expect(screen.getByTestId('day-pill').textContent).toBe('Demain')
    cleanup()
    renderCard(ride({ dateTime: '2026-04-10T16:00:00Z', endDateTime: '2026-04-10T19:00:00Z' }))
    expect(screen.getByTestId('day-pill').textContent).toBe("Aujourd'hui")
    cleanup()
    renderCard(ride({ dateTime: '2026-04-18T07:00:00Z', endDateTime: '2026-04-18T12:00:00Z' }))
    expect(screen.queryByTestId('day-pill')).toBeNull()
  })

  // MOB-115, as the app (docs/LEDGER_*.md WEB-167): the day box stays, the pill goes.
  it('carries no pill on a cancelled or started ride, nor on a cancelled trip', () => {
    renderCard(ride({ status: 'CANCELLED' }))
    expect(screen.getByTestId('day-box')).toBeTruthy()
    expect(screen.queryByTestId('day-pill')).toBeNull()
    cleanup()
    renderCard(
      ride({
        dateTime: '2026-04-10T07:00:00Z',
        endDateTime: '2026-04-10T12:00:00Z',
        finished: true,
      })
    )
    expect(screen.queryByTestId('day-pill')).toBeNull()
    cleanup()
    renderCard(
      trip({
        dateTime: '2026-04-11T06:00:00Z',
        endDateTime: '2026-04-12T15:00:00Z',
        status: 'CANCELLED',
      })
    )
    expect(screen.queryByTestId('day-pill')).toBeNull()
  })

  it('gives the departure line under the title, in 700', () => {
    renderCard(ride())
    const line = screen.getByTestId('departure-line')
    expect(plain(line.textContent)).toBe('Départ 09:00')
    expect(within(line).getByText('Départ 09:00').style.fontWeight).toBe('700')
  })

  it('leaves the date out of the statistics bar', () => {
    renderCard(ride())
    // The counters are still there…
    expect(text()).toContain('12 personnes')
    expect(text()).toContain('2 commentaires')
    // …and the date only once: the day box. No « sam. 11 avr. », no full date, below.
    expect(text()).not.toContain('sam. 11 avr.')
    expect(text()).not.toContain('2026')
    expect(screen.getAllByText(/09:00/)).toHaveLength(1)
  })

  it('gives no participant count to a ride without groups', () => {
    renderCard(ride({ groupCount: 0, participantCount: 0 }))
    expect(text()).not.toContain('personne')
  })

  it('reads the registered group’s departure (WEB-136)', () => {
    renderCard(
      ride({
        registered: true,
        registeredGroupId: 'g2',
        registeredGroup: { id: 'g2', name: 'Groupe B', startAt: '2026-04-11T07:30:00Z' },
      } as Partial<RideDto>)
    )
    expect(plain(screen.getByTestId('departure-line').textContent)).toContain('Départ 09:30')
  })

  it('gives a trip its span on a turquoise day box', () => {
    renderCard(trip())
    const box = screen.getByTestId('day-box')
    expect(box.textContent).toBe('ven.15mai')
    expect(plain(screen.getByTestId('departure-line').textContent)).toBe(
      'Départ 08:00 · ven. 15 → dim. 17 mai'
    )
    expect(text()).toContain('3 étapes')
  })

  it('poses nothing on a post', () => {
    renderCard({
      type: 'POST',
      team: TEAM_REF,
      id: 'p1',
      slug: 'nouvelles',
      name: 'Nouvelles du club',
      media: MEDIA,
      dateTime: '2026-04-11T07:00:00Z',
      timezone: 'Europe/Paris',
      status: 'PUBLISHED',
      visibility: 'TEAM',
      deleted: false,
      tags: [],
    } as unknown as PostDto)
    expect(screen.queryByTestId('day-box')).toBeNull()
    expect(screen.queryByTestId('departure-line')).toBeNull()
  })
})
