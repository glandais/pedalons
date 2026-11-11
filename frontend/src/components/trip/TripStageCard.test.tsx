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
vi.mock('@/components/ride/RideGroupRouteActions', () => ({
  RideGroupRouteActions: () => <div data-testid="route-actions" />,
}))
vi.mock('../common/MediaDisplay', () => ({
  MediaDisplay: () => <div data-testid="media" />,
}))

import { TripStageCard } from './TripStageCard'

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

function renderCard(overrides: Partial<TripStageDto> = {}) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <TripStageCard
            stage={{ ...stage, ...overrides }}
            index={1}
            teamSlug="np"
            tripSlug="vosges"
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

  it('gives its places, its facts and the route actions, like a group card', () => {
    renderCard()
    expect(screen.getByText('Gîte du Kalblin')).toBeTruthy()
    expect(screen.getByText('Auberge du lac')).toBeTruthy()
    expect(screen.getByText(/^72(,0)? km$/)).toBeTruthy()
    expect(screen.getByText(/^1[\s\u202f]?650 m$/)).toBeTruthy()
    expect(screen.getByTestId('route-actions')).toBeTruthy()
  })

  it('offers no route actions for a stage without a route', () => {
    renderCard({ route: undefined })
    expect(screen.queryByTestId('route-actions')).toBeNull()
  })
})
