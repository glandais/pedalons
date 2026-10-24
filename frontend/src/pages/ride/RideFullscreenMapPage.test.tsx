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
import { ownLeg, soloGroup } from '@/utils/soloGroup'

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

vi.mock('./rideDetailData', async (importOriginal) => ({
  ...(await importOriginal<typeof import('./rideDetailData')>()),
  useRideDetailData: () => {
    const ride = state.ride as RideDto | undefined
    const weather = state.weather as RideWeatherDto | undefined
    const solo = soloGroup(ride)
    return {
      team: { data: { slug: 'np', name: 'N Peloton' } as TeamDetailDto, isLoading: false },
      ride: { data: ride, isLoading: false, error: null, refetch: () => {} },
      weather: { data: weather, isLoading: false, isFetching: false, refetch: () => {} },
      routes: { data: undefined, isLoading: false },
      routesBySlug: state.routes,
      soloGroup: solo,
      soloLeg: solo && ride ? ownLeg(ride, weather) : undefined,
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

import { RideFullscreenMapPage } from './RideFullscreenMapPage'

const group = (id: string, name: string, routeSlug?: string): RideGroupDto =>
  ({ id, name, routeSlug }) as RideGroupDto

const ride = (overrides: Partial<RideDto> = {}): RideDto =>
  ({
    slug: 'sortie',
    name: 'Sortie du samedi',
    status: Status.PUBLISHED,
    finished: false,
    timezone: 'America/Montreal',
    routeSlug: 'boucle',
    groups: [group('g1', 'Seul')],
    ...overrides,
  }) as RideDto

const route = (slug: string) =>
  ({ slug, name: slug, tracks: [], waypoints: [] }) as unknown as RouteDetailDto

const soloWeather: RideWeatherDto = { ...okWeather, legs: [weatherLeg('g1')] }

function Probe() {
  const location = useLocation()
  return <div data-testid="elsewhere">{location.pathname + location.search}</div>
}

function UrlProbe() {
  const location = useLocation()
  return <div data-testid="url">{location.search}</div>
}

function renderPage(suffix = '') {
  return render(
    <MantineProvider>
      <MemoryRouter initialEntries={[paths.rideMap('np', 'sortie') + suffix]}>
        <Routes>
          {Object.values(pathVariants.rideMap(':teamSlug', ':rideSlug')).map((path) => (
            <Route
              key={path}
              path={path}
              element={
                <>
                  <RideFullscreenMapPage />
                  <UrlProbe />
                </>
              }
            />
          ))}
          <Route path="*" element={<Probe />} />
        </Routes>
      </MemoryRouter>
    </MantineProvider>
  )
}

const windLeg = () => state.view.windLeg as WeatherLegDto | undefined

describe('RideFullscreenMapPage (WEB-118)', () => {
  beforeEach(() => {
    state.ride = ride()
    state.weather = soloWeather
    state.routes = new Map([['boucle', route('boucle')]])
    state.view = {}
  })
  afterEach(cleanup)

  it("shows the solo group's route, titled after the ride, back to the ride, in its zone", () => {
    renderPage()
    expect(screen.getByTestId('fullscreen-view')).toBeTruthy()
    expect((state.view.route as RouteDetailDto).slug).toBe('boucle')
    expect(state.view.title).toBe('Sortie du samedi')
    expect(state.view.backTo).toBe(paths.ride('np', 'sortie'))
    expect(state.view.timezone).toBe('America/Montreal')
    expect(document.title).toBe('Sortie du samedi — Pédalons')
  })

  it("draws the group's own route when it has one", () => {
    state.ride = ride({ groups: [group('g1', 'Seul', 'autre')] })
    state.routes = new Map([
      ['boucle', route('boucle')],
      ['autre', route('autre')],
    ])
    renderPage()
    expect((state.view.route as RouteDetailDto).slug).toBe('autre')
  })

  it('arrives on the grade without a mode in the URL, the Météo mode on offer', () => {
    renderPage()
    expect(state.view.colorBy).toBe('grade')
    expect(windLeg()?.groupId).toBe('g1')
    expect(state.view.windAttribution).toEqual(okWeather.attribution)
  })

  it('arrives in the mode the URL names, an unknown one reading as the grade', () => {
    renderPage('?color=wind')
    expect(state.view.colorBy).toBe('wind')
    cleanup()
    renderPage('?color=rainbow')
    expect(state.view.colorBy).toBe('grade')
  })

  it('offers no Météo mode without a forecast, on a finished or a cancelled ride', () => {
    state.weather = {
      ...okWeather,
      legs: [weatherLeg('g1', { status: WeatherStatus.NOT_YET_AVAILABLE })],
    }
    renderPage('?color=wind')
    // The view falls back on the grade for a mode it cannot offer
    expect(windLeg()).toBeUndefined()
    expect(state.view.windAttribution).toBeUndefined()
    cleanup()
    state.weather = soloWeather
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

  it('sends a ride with no group or several, or a group without a route, to the ride', () => {
    state.ride = ride({ groups: [group('g1', 'A'), group('g2', 'B')] })
    renderPage('?color=wind')
    expect(screen.getByTestId('elsewhere').textContent).toBe(paths.ride('np', 'sortie'))
    cleanup()
    state.ride = ride({ groups: [] })
    renderPage()
    expect(screen.getByTestId('elsewhere').textContent).toBe(paths.ride('np', 'sortie'))
    cleanup()
    state.ride = ride()
    state.routes = new Map()
    renderPage()
    expect(screen.getByTestId('elsewhere').textContent).toBe(paths.ride('np', 'sortie'))
  })
})
