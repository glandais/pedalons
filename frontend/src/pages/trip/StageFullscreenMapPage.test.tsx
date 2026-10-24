import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes, useLocation } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import type {
  RouteDetailDto,
  TeamDetailDto,
  TripDto,
  TripWeatherDto,
  WeatherLegDto,
} from '@/api/dto'
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
  route: undefined as unknown,
  view: {} as Record<string, unknown>,
}))

vi.mock('./stageMapData', () => ({
  useStageMapData: () => ({
    team: { data: { slug: 'np', name: 'N Peloton' } as TeamDetailDto },
    trip: { data: state.trip, isLoading: false },
    route: { data: state.route, isLoading: false },
    routeSlug: state.route ? 'aller' : undefined,
    weather: { data: state.weather },
  }),
}))
vi.mock('@/hooks/useAppName', () => ({ useAppName: () => 'Pédalons' }))
vi.mock('@/components/route/RouteFullscreenView', () => ({
  RouteFullscreenView: (props: Record<string, unknown>) => {
    state.view = props
    return <div data-testid="fullscreen-view" />
  },
}))

import { StageFullscreenMapPage } from './StageFullscreenMapPage'

const trip = (overrides: Partial<TripDto> = {}): TripDto =>
  ({
    id: 't1',
    slug: 'voyage',
    status: Status.PUBLISHED,
    finished: false,
    timezone: 'Europe/Paris',
    stages: [
      {
        id: 's1',
        slug: 'etape-1',
        name: 'Étape 1',
        timezone: 'Europe/Lisbon',
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

function UrlProbe() {
  return <div data-testid="url">{useLocation().search}</div>
}

function renderPage(suffix = '') {
  return render(
    <MantineProvider>
      <MemoryRouter initialEntries={[paths.stageMap('np', 'voyage', 'etape-1') + suffix]}>
        <Routes>
          {Object.values(pathVariants.stageMap(':teamSlug', ':tripSlug', ':stageSlug')).map(
            (path) => (
              <Route
                key={path}
                path={path}
                element={
                  <>
                    <StageFullscreenMapPage />
                    <UrlProbe />
                  </>
                }
              />
            )
          )}
        </Routes>
      </MemoryRouter>
    </MantineProvider>
  )
}

const windLeg = () => state.view.windLeg as WeatherLegDto | undefined

describe('StageFullscreenMapPage — the Météo mode (WEB-118)', () => {
  beforeEach(() => {
    state.trip = trip()
    state.weather = tripWeather(weatherLeg(undefined))
    state.route = {
      slug: 'aller',
      name: 'Aller',
      tracks: [],
      waypoints: [],
    } as unknown as RouteDetailDto
    state.view = {}
  })
  afterEach(cleanup)

  it("offers the stage's leg, read in the stage's zone, the grade without a mode", () => {
    renderPage()
    expect(screen.getByTestId('fullscreen-view')).toBeTruthy()
    expect(state.view.colorBy).toBe('grade')
    expect(windLeg()).toBe((state.weather as TripWeatherDto).stages[0].leg)
    expect(state.view.windAttribution).toEqual((state.weather as TripWeatherDto).attribution)
    expect(state.view.windSubject).toBe('stage')
    expect(state.view.timezone).toBe('Europe/Lisbon')
    expect(state.view.backTo).toBe(paths.stage('np', 'voyage', 'etape-1'))
  })

  it('arrives in the mode the URL names, and writes a new one in place', () => {
    renderPage('?color=wind')
    expect(state.view.colorBy).toBe('wind')
    act(() => (state.view.onColorByChange as (c: ColorByOption) => void)('grade'))
    expect(screen.getByTestId('url').textContent).toBe('')
    act(() => (state.view.onColorByChange as (c: ColorByOption) => void)('wind'))
    expect(screen.getByTestId('url').textContent).toBe('?color=wind')
  })

  it('offers no Météo mode for a stage gone or not yet forecast, nor on a trip over or cancelled', () => {
    for (const status of [WeatherStatus.OUT_OF_RANGE, WeatherStatus.NOT_YET_AVAILABLE]) {
      state.weather = tripWeather(weatherLeg(undefined, { status }))
      renderPage('?color=wind')
      // The view falls back on the grade for a mode it cannot offer
      expect(windLeg()).toBeUndefined()
      expect(state.view.windAttribution).toBeUndefined()
      cleanup()
    }
    state.weather = tripWeather(weatherLeg(undefined))
    for (const over of [{ finished: true }, { status: Status.CANCELLED }]) {
      state.trip = trip(over)
      renderPage('?color=wind')
      expect(windLeg()).toBeUndefined()
      cleanup()
    }
  })
})
