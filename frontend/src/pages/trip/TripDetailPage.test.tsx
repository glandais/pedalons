import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { TeamDetailDto, TripDto, TripWeatherDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import { weatherLeg } from '@/test/weatherFixtures'
import { pathVariants, paths } from '@/config/paths'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

const state = vi.hoisted(() => ({
  trip: undefined as unknown,
  weather: undefined as unknown,
  section: undefined as Record<string, unknown> | undefined,
}))

vi.mock('./tripDetailData', () => ({
  useTripDetailData: () => ({
    team: {
      data: {
        slug: 'np',
        name: 'N Peloton',
        enableTrips: true,
        enableRoutes: true,
        role: 'MEMBER',
      } as TeamDetailDto,
      isLoading: false,
    },
    trip: { data: state.trip, isLoading: false, error: null, refetch: () => {} },
    weather: { data: state.weather, isLoading: false, isFetching: false, refetch: () => {} },
  }),
  invalidateTripWeather: () => Promise.resolve(),
}))
vi.mock('@/hooks/useAuth', () => ({
  useAuth: () => ({ isAuthenticated: true, user: { id: 'u' } }),
}))
vi.mock('@/components/trip/TripOverviewMap', () => ({ TripOverviewMap: () => <div /> }))
vi.mock('@/components/team/TeamContextBanner', () => ({ TeamContextBanner: () => null }))
vi.mock('@/components/moderation/ContentActionsMenu', () => ({ ContentActionsMenu: () => null }))
vi.mock('@/components/comment', () => ({
  CommentSection: () => <div data-testid="comments" />,
}))
vi.mock('@/components/weather/RouteWeatherSection', () => ({
  RouteWeatherSection: (props: Record<string, unknown>) => {
    state.section = props
    return <div data-testid="route-weather" />
  },
}))

import { TripDetailPage } from './TripDetailPage'

const stage = (id: string) => ({
  id,
  slug: `etape-${id}`,
  name: `Étape ${id}`,
  dateTime: '2026-10-26T07:00:00Z',
  timezone: 'Europe/Lisbon',
  media: { markdown: '', assets: { attachments: [] } },
  permissions: { canEdit: false, canDelete: false, canComment: true, indexable: true },
  route: { slug: `r${id}`, distance: 60_000, elevationGain: 800, media: { assets: {} } },
})

const trip = (stageIds: string[]): TripDto =>
  ({
    id: 't1',
    slug: 'voyage',
    name: 'Voyage',
    status: Status.PUBLISHED,
    finished: false,
    dateTime: '2026-10-26T07:00:00Z',
    timezone: 'Europe/Paris',
    media: { markdown: '', assets: { attachments: [] } },
    tags: [],
    team: { slug: 'np', name: 'N Peloton', visibility: 'PUBLIC', accessible: true },
    // The backend's answers for a member (docs/LEDGER_*.md WEB-166).
    permissions: {
      canEdit: false,
      canDelete: false,
      canRegister: true,
      canComment: true,
      canSeeParticipants: true,
      indexable: true,
    },
    participantCount: 0,
    stageCount: stageIds.length,
    registered: false,
    deleted: false,
    stages: stageIds.map(stage),
  }) as unknown as TripDto

const weatherFor = (stageIds: string[]): TripWeatherDto => ({
  status: WeatherStatus.OK,
  stages: stageIds.map((stageId) => ({
    stageId,
    leg: weatherLeg(undefined),
    departure: { status: WeatherStatus.OK },
  })),
  attribution: { name: 'Open-Meteo.com', url: 'https://open-meteo.com/' },
})

function renderPage() {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter initialEntries={[paths.trip('np', 'voyage')]}>
          <Routes>
            {Object.values(pathVariants.trip(':teamSlug', ':tripSlug')).map((path) => (
              <Route key={path} path={path} element={<TripDetailPage />} />
            ))}
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

describe('TripDetailPage — the weather of a trip of one stage (WEB-155)', () => {
  beforeEach(() => {
    state.section = undefined
  })
  afterEach(cleanup)

  it("unrolls its only stage's route weather under #meteo, before the comments", () => {
    state.trip = trip(['s1'])
    state.weather = weatherFor(['s1'])
    const { container } = renderPage()

    const section = screen.getByTestId('route-weather')
    expect(section.closest('#meteo')).toBeTruthy()
    expect(state.section?.subject).toBe('stage')
    expect(state.section?.leg).toBe((state.weather as TripWeatherDto).stages[0].leg)
    expect(state.section?.departure).toBe((state.weather as TripWeatherDto).stages[0].departure)
    expect(state.section?.timezone).toBe('Europe/Lisbon')
    const comments = screen.getByTestId('comments')
    expect(
      section.compareDocumentPosition(comments) & Node.DOCUMENT_POSITION_FOLLOWING
    ).toBeTruthy()
    expect(container.querySelector('.detail-side #meteo')).toBeNull()
  })

  it('keeps no weather block for a trip of several stages: their cards and the map say it', () => {
    state.trip = trip(['s1', 's2'])
    state.weather = weatherFor(['s1', 's2'])
    renderPage()
    expect(screen.queryByTestId('route-weather')).toBeNull()
  })
})
