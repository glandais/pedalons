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
  weatherSection: {} as Record<string, unknown>,
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
vi.mock('@/components/route/RouteMapPanel', () => ({
  RouteMapPanel: (props: Record<string, unknown>) => {
    state.view = props
    return <div data-testid="route-map" />
  },
}))
vi.mock('@/components/weather/RouteWeatherSection', () => ({
  RouteWeatherSection: (props: Record<string, unknown>) => {
    state.weatherSection = props
    return <div data-testid="route-weather" />
  },
}))
vi.mock('@/components/ride/RideGroupRouteActions', () => ({
  RideGroupRouteActions: () => <div data-testid="route-actions" />,
}))
vi.mock('@/components/comment', () => ({
  CommentSection: () => <div data-testid="comments" />,
}))
vi.mock('@/components/common/MediaDisplay', () => ({
  MediaDisplay: () => <div data-testid="media" />,
}))

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
        media: { markdown: 'Col au départ', assets: { attachments: [] } },
        route: { slug: 'aller', name: 'Aller', distance: 72_000, elevationGain: 1_650 },
      },
      {
        id: 's2',
        slug: 'etape-2',
        name: 'Étape 2',
        dateTime: '2026-10-27T07:00:00Z',
        timezone: 'Europe/Lisbon',
        media: { markdown: '', assets: { attachments: [] } },
      },
    ],
    ...overrides,
  }) as unknown as TripDto

const tripWeather = (leg: WeatherLegDto): TripWeatherDto => ({
  status: WeatherStatus.OK,
  stages: [{ stageId: 's1', leg, departure: { status: leg.status } }],
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

describe('StageDetailPage — the page of a child, as a group (WEB-155)', () => {
  beforeEach(() => {
    state.trip = trip()
    state.weather = tripWeather(weatherLeg(undefined))
    state.view = {}
    state.weatherSection = {}
  })
  afterEach(cleanup)

  it('has one header: the stage as the only h1, the trip named above it', () => {
    renderPage()
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1)
    expect(screen.getByRole('heading', { level: 1, name: 'Étape 1' })).toBeTruthy()
    expect(screen.getByText('Voyage · étape 1 sur 2')).toBeTruthy()
    expect(screen.getByRole('link', { name: /Retour au voyage/ }).getAttribute('href')).toBe(
      paths.trip('np', 'voyage')
    )
  })

  it('moves to the other stages from its header, not from a rail', () => {
    renderPage()
    expect(screen.getByTestId('sibling-nav')).toBeTruthy()
    expect(screen.getByRole('link', { name: 'Suivant : 2 · Étape 2' }).getAttribute('href')).toBe(
      paths.stage('np', 'voyage', 'etape-2')
    )
    expect(screen.queryByRole('tab')).toBeNull()
  })

  it('gives its figures, its untitled instructions and its route card, no people', () => {
    renderPage()
    expect(screen.getByTestId('stage-stats')).toBeTruthy()
    expect(screen.getByTestId('stage-instructions')).toBeTruthy()
    expect(screen.queryByRole('heading', { name: 'Consignes' })).toBeNull()
    expect(screen.getByRole('heading', { level: 3, name: 'Aller' })).toBeTruthy()
    expect(screen.getByTestId('route-actions')).toBeTruthy()
    expect(screen.queryByRole('heading', { name: 'Personnes inscrites' })).toBeNull()
  })

  it("hands the route's weather the stage's leg, departure and zone, for the stage", () => {
    renderPage()
    const stageWeather = (state.weather as TripWeatherDto).stages[0]
    expect(state.weatherSection.subject).toBe('stage')
    expect(state.weatherSection.leg).toBe(stageWeather.leg)
    expect(state.weatherSection.departure).toBe(stageWeather.departure)
    expect(state.weatherSection.timezone).toBe('Europe/Lisbon')
    expect(state.weatherSection.offered).toBe(true)
  })

  it('offers no weather once the trip is over or cancelled', () => {
    for (const over of [{ finished: true }, { status: Status.CANCELLED }]) {
      state.trip = trip(over)
      renderPage()
      expect(state.weatherSection.offered).toBe(false)
      cleanup()
    }
  })

  it('keeps its own comment thread', () => {
    renderPage()
    expect(screen.queryByTestId('comments')).toBeNull() // signed out: members only
  })
})

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
    expect(screen.getByTestId('route-map')).toBeTruthy()
    expect(state.view.leg).toBe((state.weather as TripWeatherDto).stages[0].leg)
    expect(state.view.attribution).toEqual((state.weather as TripWeatherDto).attribution)
    expect(state.view.timezone).toBe('Europe/Lisbon')
    expect(state.view.subject).toBe('stage')
  })

  it('opens the stage’s fullscreen map in the mode its line is in', () => {
    renderPage()
    expect(fullscreen('grade')).toBe(paths.stageMap('np', 'voyage', 'etape-1'))
    expect(fullscreen('wind')).toBe(`${paths.stageMap('np', 'voyage', 'etape-1')}?color=wind`)
  })

  it('offers no Météo mode for a stage gone, nor on a trip over or cancelled', () => {
    state.weather = tripWeather(weatherLeg(undefined, { status: WeatherStatus.OUT_OF_RANGE }))
    renderPage()
    expect(state.view.leg).toBeUndefined()
    expect(state.view.attribution).toBeUndefined()
    cleanup()
    state.weather = tripWeather(weatherLeg(undefined))
    for (const over of [{ finished: true }, { status: Status.CANCELLED }]) {
      state.trip = trip(over)
      renderPage()
      expect(state.view.leg).toBeUndefined()
      cleanup()
    }
  })
})
