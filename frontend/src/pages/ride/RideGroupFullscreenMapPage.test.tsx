import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes, useLocation } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import type {
  RideDto,
  RideGroupDto,
  RideWeatherDto,
  RouteDetailDto,
  TeamDetailDto,
  WeatherLegDto,
} from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import { okWeather, weatherLeg } from '@/test/weatherFixtures'
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
  ride: undefined as unknown,
  weather: undefined as unknown,
  routes: new Map<string, unknown>(),
  view: {} as Record<string, unknown>,
}))

vi.mock('./rideGroupData', async (importOriginal) => ({
  ...(await importOriginal<typeof import('./rideGroupData')>()),
  useRideGroupData: (_team: string, _ride: string, groupId: string) => {
    const ride = state.ride as RideDto | undefined
    const weather = state.weather as RideWeatherDto | undefined
    return {
      team: { data: { slug: 'np', name: 'N Peloton' } as TeamDetailDto, isLoading: false },
      ride: { data: ride, isLoading: false, error: null, refetch: () => {} },
      weather: { data: weather, isLoading: false, isFetching: false, refetch: () => {} },
      routes: { data: undefined, isLoading: false },
      routesBySlug: state.routes,
      group: ride?.groups.find((g) => g.id === groupId),
      leg: weather?.legs.find((l) => l.groupId === groupId),
    }
  },
}))
vi.mock('@/hooks/useAppName', () => ({ useAppName: () => 'Pédalons' }))
// The viewer pulls the map: a stand-in keeping what it was handed.
vi.mock('@/components/route/RouteFullscreenView', () => ({
  RouteFullscreenView: (props: Record<string, unknown>) => {
    state.view = props
    return <div data-testid="fullscreen-view" />
  },
}))

import { RideGroupFullscreenMapPage } from './RideGroupFullscreenMapPage'

const group = (id: string, name: string): RideGroupDto => ({ id, name }) as RideGroupDto

const ride = (overrides: Partial<RideDto> = {}): RideDto =>
  ({
    slug: 'sortie',
    name: 'Sortie du samedi',
    status: Status.PUBLISHED,
    finished: false,
    timezone: 'Europe/Paris',
    routeSlug: 'boucle',
    groups: [group('g1', 'Rapide'), group('g2', 'Cool')],
    ...overrides,
  }) as RideDto

const boucle = {
  slug: 'boucle',
  name: 'La boucle',
  tracks: [],
  waypoints: [],
} as unknown as RouteDetailDto

function Probe() {
  const location = useLocation()
  return <div data-testid="elsewhere">{location.pathname + location.search}</div>
}

function UrlProbe() {
  const location = useLocation()
  return <div data-testid="url">{location.search}</div>
}

function renderPage(suffix = '', groupId = 'g1') {
  return render(
    <MantineProvider>
      <MemoryRouter initialEntries={[paths.rideGroupMap('np', 'sortie', groupId) + suffix]}>
        <Routes>
          {Object.values(pathVariants.rideGroupMap(':teamSlug', ':rideSlug', ':groupId')).map(
            (path) => (
              <Route
                key={path}
                path={path}
                element={
                  <>
                    <RideGroupFullscreenMapPage />
                    <UrlProbe />
                  </>
                }
              />
            )
          )}
          <Route path="*" element={<Probe />} />
        </Routes>
      </MemoryRouter>
    </MantineProvider>
  )
}

const windLeg = () => state.view.windLeg as WeatherLegDto | undefined

describe('RideGroupFullscreenMapPage (WEB-117)', () => {
  beforeEach(() => {
    state.ride = ride()
    state.weather = okWeather
    state.routes = new Map([['boucle', boucle]])
    state.view = {}
  })
  afterEach(cleanup)

  it("shows the group's route, titled after the ride and the group, back to the group's page", () => {
    renderPage()
    expect(screen.getByTestId('fullscreen-view')).toBeTruthy()
    expect(state.view.route).toBe(boucle)
    expect(state.view.title).toBe('Sortie du samedi · Groupe Rapide')
    expect(state.view.backTo).toBe(paths.rideGroup('np', 'sortie', 'g1'))
    expect(state.view.timezone).toBe('Europe/Paris')
    expect(document.title).toBe('Sortie du samedi · Groupe Rapide — Pédalons')
  })

  it('arrives on the grade without a mode in the URL, the Météo mode on offer', () => {
    renderPage()
    expect(state.view.colorBy).toBe('grade')
    expect(windLeg()?.groupId).toBe('g1')
    expect(state.view.windAttribution).toEqual(okWeather.attribution)
  })

  it('arrives in the mode the URL names', () => {
    renderPage('?color=wind')
    expect(state.view.colorBy).toBe('wind')
    expect(windLeg()?.groupId).toBe('g1')
  })

  it('reads a mode it does not know as the grade', () => {
    renderPage('?color=rainbow')
    expect(state.view.colorBy).toBe('grade')
  })

  it('offers no Météo mode without a forecast, on a finished or a cancelled ride', () => {
    state.weather = {
      ...okWeather,
      legs: [weatherLeg('g1', { status: WeatherStatus.NOT_YET_AVAILABLE }), weatherLeg('g2')],
    }
    renderPage('?color=wind')
    // The view falls back on the grade for a mode it cannot offer
    expect(windLeg()).toBeUndefined()
    expect(state.view.windAttribution).toBeUndefined()
    cleanup()
    state.weather = okWeather
    state.ride = ride({ finished: true })
    renderPage('?color=wind')
    expect(windLeg()).toBeUndefined()
    cleanup()
    state.ride = ride({ status: Status.CANCELLED })
    renderPage('?color=wind')
    expect(windLeg()).toBeUndefined()
  })

  it('writes a new mode in the URL, the grade writing nothing', () => {
    renderPage()
    act(() => (state.view.onColorByChange as (c: ColorByOption) => void)('wind'))
    expect(screen.getByTestId('url').textContent).toBe('?color=wind')
    act(() => (state.view.onColorByChange as (c: ColorByOption) => void)('grade'))
    expect(screen.getByTestId('url').textContent).toBe('')
  })

  it('sends a solo ride to its own map, mode kept (WEB-118), a ride without groups to the ride', () => {
    state.ride = ride({ groups: [group('g1', 'Rapide')] })
    renderPage('?color=wind')
    expect(screen.getByTestId('elsewhere').textContent).toBe(
      `${paths.rideMap('np', 'sortie')}?color=wind`
    )
    cleanup()
    state.ride = ride({ groups: [] })
    renderPage('?color=wind')
    expect(screen.getByTestId('elsewhere').textContent).toBe(paths.ride('np', 'sortie'))
  })

  it("sends a group the ride lacks, or one without a route, back to the group's page", () => {
    renderPage('', 'gone')
    expect(screen.getByTestId('elsewhere').textContent).toBe(
      paths.rideGroup('np', 'sortie', 'gone')
    )
    cleanup()
    state.routes = new Map()
    renderPage()
    expect(screen.getByTestId('elsewhere').textContent).toBe(paths.rideGroup('np', 'sortie', 'g1'))
  })
})
