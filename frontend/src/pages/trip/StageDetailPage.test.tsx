import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { TeamDetailDto, TripDto, TripWeatherDto, WeatherLegDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import { weatherLeg } from '@/test/weatherFixtures'
import { pathVariants, paths } from '@/config/paths'
import type { ColorByOption } from '@/components/route/ColorByControl'

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
  view: {} as Record<string, unknown>,
}))

vi.mock('./stageDetailData', () => ({
  useStageDetailData: () => ({
    team: {
      data: {
        slug: 'np',
        name: 'N Peloton',
        enableTrips: true,
        enableRoutes: true,
      } as TeamDetailDto,
      isLoading: false,
    },
    trip: { data: state.trip, isLoading: false, error: null, refetch: () => {} },
    route: {
      data: { slug: 'aller', name: 'Aller', tracks: [], waypoints: [] },
      isLoading: false,
    },
    routeSlug: 'aller',
    weather: { data: state.weather, isLoading: false, isFetching: false, refetch: () => {} },
  }),
}))
vi.mock('@/hooks/useAuth', () => ({ useAuth: () => ({ isAuthenticated: false }) }))
vi.mock('@/components/route/RouteDetailView', () => ({
  RouteDetailView: (props: Record<string, unknown>) => {
    state.view = props
    return <div data-testid="route-detail" />
  },
}))
vi.mock('@/components/weather', () => ({ StageWeatherSection: () => null }))
vi.mock('@/components/trip/TripLayout', () => ({
  TripLayout: ({ children }: { children: React.ReactNode }) => <>{children}</>,
}))
vi.mock('@/components/comment', () => ({ CommentSection: () => null }))
vi.mock('@/components/common/MediaDisplay', () => ({ MediaDisplay: () => null }))

import { StageDetailPage } from './StageDetailPage'

const trip = (overrides: Partial<TripDto> = {}): TripDto =>
  ({
    id: 't1',
    slug: 'voyage',
    name: 'Voyage',
    status: Status.PUBLISHED,
    finished: false,
    timezone: 'Europe/Paris',
    media: { markdown: '', assets: {} },
    stages: [
      {
        id: 's1',
        slug: 'etape-1',
        name: 'Étape 1',
        dateTime: '2026-10-26T07:00:00Z',
        timezone: 'Europe/Lisbon',
        media: { markdown: '', assets: {} },
        route: { slug: 'aller' },
      },
    ],
    ...overrides,
  }) as unknown as TripDto

const tripWeather = (leg: WeatherLegDto): TripWeatherDto => ({
  status: WeatherStatus.OK,
  stages: [{ stageId: 's1', leg }],
  attribution: { name: 'Open-Meteo.com', url: 'https://open-meteo.com/' },
})

function renderPage() {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter initialEntries={[paths.stage('np', 'voyage', 'etape-1')]}>
          <Routes>
            {Object.values(pathVariants.stage(':teamSlug', ':tripSlug', ':stageSlug')).map(
              (path) => (
                <Route key={path} path={path} element={<StageDetailPage />} />
              )
            )}
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

const fullscreen = (colorBy: ColorByOption) =>
  (state.view.fullscreenPath as (c: ColorByOption) => string)(colorBy)

describe('StageDetailPage — the Météo mode of its map (WEB-118)', () => {
  beforeEach(() => {
    state.trip = trip()
    state.weather = tripWeather(weatherLeg(undefined))
    state.view = {}
  })
  afterEach(cleanup)

  it("hands its map the stage's leg, read in the stage's zone, with the credit", () => {
    renderPage()
    expect(screen.getByTestId('route-detail')).toBeTruthy()
    expect(state.view.windLeg).toBe((state.weather as TripWeatherDto).stages[0].leg)
    expect(state.view.windAttribution).toEqual((state.weather as TripWeatherDto).attribution)
    expect(state.view.timezone).toBe('Europe/Lisbon')
  })

  it('opens the stage’s fullscreen map in the mode its line is in', () => {
    renderPage()
    expect(fullscreen('grade')).toBe(paths.stageMap('np', 'voyage', 'etape-1'))
    expect(fullscreen('wind')).toBe(`${paths.stageMap('np', 'voyage', 'etape-1')}?color=wind`)
  })

  it('offers no Météo mode for a stage gone, nor on a trip over or cancelled', () => {
    state.weather = tripWeather(weatherLeg(undefined, { status: WeatherStatus.OUT_OF_RANGE }))
    renderPage()
    expect(state.view.windLeg).toBeUndefined()
    expect(state.view.windAttribution).toBeUndefined()
    cleanup()
    state.weather = tripWeather(weatherLeg(undefined))
    for (const over of [{ finished: true }, { status: Status.CANCELLED }]) {
      state.trip = trip(over)
      renderPage()
      expect(state.view.windLeg).toBeUndefined()
      cleanup()
    }
  })
})
