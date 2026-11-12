import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { TripStageDto } from '@/api/dto'
import { paths } from '@/config/paths'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})
vi.mock('@/components/route/GpsMenuButton', () => ({
  GpsMenuButton: ({ routeSlug }: { routeSlug: string }) => (
    <div data-testid="gps-button" data-route={routeSlug} />
  ),
}))
vi.mock('../common/MediaDisplay', () => ({
  MediaDisplay: () => <div data-testid="media" />,
}))

import { TripStageCard } from './TripStageCard'
import { stageIsOver } from '@/utils/publicationEnd'

const stage = {
  id: 's2',
  slug: 'munster-gerardmer',
  name: 'Munster → Gérardmer',
  dateTime: '2027-05-15T06:30:00Z',
  timezone: 'Europe/Paris',
  averageSpeed: 20,
  media: { markdown: 'Montée du col de la Schlucht', assets: { attachments: [], images: [] } },
  startPlace: { name: 'Gîte du Kalblin' },
  endPlace: { name: 'Auberge du lac' },
  route: { slug: 'schlucht', distance: 72_000, elevationGain: 1_650, media: { assets: {} } },
  sortOrder: 1,
  stageIndex: 2,
  stageCount: 3,
} as unknown as TripStageDto

function renderCard(overrides: Partial<TripStageDto> = {}, riding = false, trackColor?: string) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <TripStageCard
            stage={{ ...stage, ...overrides }}
            index={1}
            teamSlug="np"
            tripSlug="vosges"
            riding={riding}
            trackColor={trackColor}
          />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

describe('TripStageCard (WEB-155)', () => {
  afterEach(cleanup)

  it("links its name — the card's only link — to the stage's page", () => {
    renderCard()
    const links = screen.getAllByRole('link')
    expect(links).toHaveLength(1)
    expect(links[0].getAttribute('href')).toBe(paths.stage('np', 'vosges', 'munster-gerardmer'))
    expect(links[0].textContent).toContain('Munster → Gérardmer')
  })

  it('leaves the description to the stage page, no button inside the link', () => {
    renderCard()
    expect(screen.queryByTestId('media')).toBeNull()
    expect(screen.queryByText('Montée du col de la Schlucht')).toBeNull()
    expect(screen.getAllByRole('link')[0].querySelector('button')).toBeNull()
  })

  it('gives its places and its facts, like a group card', () => {
    renderCard()
    expect(screen.getByText('Gîte du Kalblin')).toBeTruthy()
    expect(screen.getByText('Auberge du lac')).toBeTruthy()
    expect(screen.getByText(/^72(,0)? km$/)).toBeTruthy()
    expect(screen.getByText(/^1[\s\u202f]?650 m$/)).toBeTruthy()
  })

  // R7 (docs/LEDGER_*.md WEB-167): « GPS » to a reader who takes part in the trip, nothing else.
  it('offers « GPS » for its route to a reader who rides the trip, until the stage is over', () => {
    renderCard({}, true)
    expect(screen.getByTestId('gps-button').getAttribute('data-route')).toBe('schlucht')
    expect(screen.queryByText('GPX')).toBeNull()
    cleanup()
    renderCard({ dateTime: '2020-05-15T06:30:00Z' }, true)
    expect(screen.queryByTestId('gps-button')).toBeNull()
  })

  it('offers no export to a reader who does not take part, nor for a stage without a route', () => {
    renderCard()
    expect(screen.queryByTestId('gps-button')).toBeNull()
    cleanup()
    renderCard({ route: undefined }, true)
    expect(screen.queryByTestId('gps-button')).toBeNull()
  })

  it('ends a stage at its estimated arrival, else three hours after its departure', () => {
    const departure = Date.parse('2027-05-15T06:30:00Z')
    const at = (hours: number) => departure + hours * 3_600_000
    expect(stageIsOver({ dateTime: '2027-05-15T06:30:00Z' }, at(2.9))).toBe(false)
    expect(stageIsOver({ dateTime: '2027-05-15T06:30:00Z' }, at(3))).toBe(true)
    const withArrival = {
      dateTime: '2027-05-15T06:30:00Z',
      estimatedArrival: '2027-05-15T12:30:00Z',
    }
    expect(stageIsOver(withArrival, at(5))).toBe(false)
    expect(stageIsOver(withArrival, at(6))).toBe(true)
  })

  // docs/LEDGER_*.md WEB-167, R10: the colour of its trace after its name, as the app's card.
  it('recalls its trace’s colour after its name, and nothing without a trace', () => {
    renderCard({}, false, '#1d32a8')
    const bar = screen.getByTestId('stage-track-color')
    expect(bar.style.backgroundColor).toBe('rgb(29, 50, 168)')
    // After the name, inside the name's link, before its chevron.
    expect(bar.closest('a')?.textContent).toContain('Munster → Gérardmer')
    cleanup()
    renderCard()
    expect(screen.queryByTestId('stage-track-color')).toBeNull()
  })
})
