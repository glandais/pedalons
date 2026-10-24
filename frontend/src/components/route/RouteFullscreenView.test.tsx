import { afterEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react'
import { Link, MemoryRouter, Route, Routes, useLocation } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { TrackSurface, TrackSurfaceState, type TrackDto, type WaypointDto } from '@/api/dto'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

const seen = vi.hoisted(() => ({
  map: {} as Record<string, unknown>,
  chart: {} as Record<string, unknown>,
}))

vi.mock('@/components/common/PrefetchLink', () => ({
  PrefetchLink: Link,
}))
vi.mock('@/hooks/useMapStyle', () => ({ useMapStyle: () => ({ darkBasemap: false }) }))
vi.mock('@/hooks/useMapChartZoomSync', () => ({
  useMapChartZoomSync: () => ({
    mapRef: { current: null },
    chartRef: { current: null },
    mapMoving: { current: false },
    chartMoving: { current: false },
    onMapMoveStart: () => {},
    onMapMoveEnd: () => {},
    onChartMoveStart: () => {},
    onChartMoveComplete: () => {},
  }),
}))
vi.mock('./RouteTrackMap', () => ({
  RouteTrackMap: (props: Record<string, unknown>) => {
    seen.map = props
    return <div data-testid="track-map" />
  },
}))
vi.mock('./ElevationChart', () => ({
  ElevationChart: (props: Record<string, unknown>) => {
    seen.chart = props
    return <div data-testid="elevation-chart" />
  },
}))

import { RouteFullscreenView, type FullscreenRoute } from './RouteFullscreenView'
import type { ColorByOption } from './ColorByControl'
import { WeatherStatus, type WeatherLegDto } from '@/api/dto'
import { okWeather, plain, weatherLeg } from '@/test/weatherFixtures'
import type { WaypointSelection } from '@/lib/waypoints'

const line = {
  type: 'LineString' as const,
  coordinates: [
    [2, 48, 100, 0],
    [2.01, 48, 110, 700],
    [2.02, 48, 120, 1400],
  ],
}

function route(extra: Partial<TrackDto> = {}): FullscreenRoute {
  return {
    distance: 1400,
    elevationGain: 20,
    elevationLoss: 0,
    waypoints: [],
    tracks: [{ line, climbs: [], ...extra } as TrackDto],
  }
}

function renderView(shown: FullscreenRoute, history: string[] = ['/map']) {
  return render(
    <MemoryRouter initialEntries={history} initialIndex={history.length - 1}>
      <MantineProvider>
        <Routes>
          <Route
            path="/map"
            element={<RouteFullscreenView route={shown} title="Boucle" backTo="/back" />}
          />
          <Route path="*" element={<LocationProbe />} />
        </Routes>
      </MantineProvider>
    </MemoryRouter>
  )
}

function LocationProbe() {
  const { pathname } = useLocation()
  return <div data-testid="landed">{pathname}</div>
}

describe('RouteFullscreenView surface switch', () => {
  afterEach(cleanup)

  it('offers no switch while the route has no surface', () => {
    renderView(route({ surfaceState: TrackSurfaceState.PENDING }))
    expect(screen.queryByTestId('route-fullscreen-color-by')).toBeNull()
    expect(seen.map.lineColorAt).toBeUndefined()
    expect(seen.chart.colorBy).toBe('grade')
  })

  it('colours the line and the profile by surface once asked', () => {
    renderView(
      route({
        surfaceState: TrackSurfaceState.READY,
        surfaces: [
          { from: 0, to: 700, surface: TrackSurface.PAVED },
          { from: 700, to: 1400, surface: TrackSurface.GRAVEL },
        ],
      })
    )
    expect(screen.getByTestId('route-fullscreen-color-by')).toBeTruthy()
    expect(seen.map.lineColorAt).toBeUndefined()
    expect(seen.chart.colorBy).toBe('grade')

    fireEvent.click(screen.getByText('Revêtement'))
    expect(seen.chart.colorBy).toBe('surface')
    const surfaceAt = seen.chart.surfaceAt as (i: number) => string
    expect(surfaceAt(0)).not.toBe(surfaceAt(1))
    const lineColorAt = seen.map.lineColorAt as (t: number, p: number) => string
    expect(lineColorAt(0, 0)).not.toBe(lineColorAt(0, 1))
  })
})

describe('RouteFullscreenView waypoints', () => {
  afterEach(cleanup)

  it('hands the same selection to the map and to the profile', () => {
    const waypoint = { name: 'Fontaine', type: 'WATER' } as WaypointDto
    renderView({ ...route(), waypoints: [waypoint] })
    expect(seen.map.waypointSelection).toBeNull()

    act(() => {
      ;(seen.chart.onSelectWaypoint as (w: WaypointDto) => void)(waypoint)
    })
    expect(seen.chart.selectedWaypoint).toBe(waypoint)
    expect(seen.map.waypointSelection).toEqual({ waypoint, from: 'profile' })

    act(() => {
      ;(seen.map.onWaypointSelect as (s: WaypointSelection | null) => void)(null)
    })
    expect(seen.chart.selectedWaypoint).toBeNull()
  })
})

describe('RouteFullscreenView back button', () => {
  afterEach(cleanup)

  it('goes back to the page that opened the map', () => {
    renderView(route(), ['/group', '/map'])
    fireEvent.click(screen.getByLabelText('Retour'))
    expect(screen.getByTestId('landed').textContent).toBe('/group')
  })

  it('falls back to its own page when the map was opened directly', () => {
    renderView(route())
    fireEvent.click(screen.getByLabelText('Retour'))
    expect(screen.getByTestId('landed').textContent).toBe('/back')
  })
})

describe('RouteFullscreenView Météo mode (WEB-117)', () => {
  afterEach(cleanup)

  /** A 50 km track, its points every 10 km: the fixture leg's head wind covers it. */
  const windRoute = (): FullscreenRoute => ({
    ...route(),
    distance: 50_000,
    tracks: [
      {
        line: {
          type: 'LineString',
          coordinates: Array.from({ length: 6 }, (_, i) => [5, 45 + i * 0.09, 300, i * 10_000]),
        },
        climbs: [],
      } as unknown as TrackDto,
    ],
  })

  function renderWind(props: {
    colorBy?: ColorByOption
    onColorByChange?: (c: ColorByOption) => void
    windLeg?: WeatherLegDto
  }) {
    return render(
      <MemoryRouter initialEntries={['/map']}>
        <MantineProvider>
          <RouteFullscreenView
            route={windRoute()}
            title="Groupe Rapide"
            backTo="/back"
            windAttribution={okWeather.attribution}
            timezone="Europe/Paris"
            {...props}
          />
        </MantineProvider>
      </MemoryRouter>
    )
  }

  it('offers « Pente | Météo » with a forecast, the grade by default', () => {
    renderWind({ windLeg: weatherLeg('g1') })
    const control = screen.getByTestId('route-fullscreen-color-by')
    expect(plain(control.textContent)).toBe('PenteMétéo')
    expect(seen.map.lineColorAt).toBeUndefined()
    expect(seen.map.kmMarkers).toBe(true)
    expect(screen.queryByTestId('wind-map-legend')).toBeNull()
  })

  it('colours the line by the wind, with its badges, legend and credit, the profile on the grade', () => {
    renderWind({ colorBy: 'wind', windLeg: weatherLeg('g1', { status: WeatherStatus.STALE }) })
    const lineColorAt = seen.map.lineColorAt as (t: number, p: number) => string
    // The fixture's head wind: orange-6 of the generated family
    expect(lineColorAt(0, 0)).toBe('#fd7e14')
    expect(seen.map.overlays).toBeTruthy()
    expect(seen.map.kmMarkers).toBe(false)
    expect(seen.map.lineAttribution).toContain('Open-Meteo.com')
    expect(seen.chart.colorBy).toBe('grade')
    const legend = plain(screen.getByTestId('wind-map-legend').textContent)
    expect(legend).toMatch(/Face 50[.,]0 km/)
    expect(legend).toContain('Prévision ancienne')
    expect(legend).toContain('Prévisions Open-Meteo.com')
  })

  it('reads the Météo mode as the grade without a forecast', () => {
    renderWind({ colorBy: 'wind' })
    expect(screen.queryByTestId('route-fullscreen-color-by')).toBeNull()
    expect(seen.map.lineColorAt).toBeUndefined()
    expect(seen.map.overlays).toBeFalsy()
    expect(seen.map.kmMarkers).toBe(true)
    expect(screen.queryByTestId('wind-map-legend')).toBeNull()
  })

  it('reports a switch to the page that holds the mode, and follows it', () => {
    const onColorByChange = vi.fn()
    const { rerender } = renderWind({
      colorBy: 'grade',
      windLeg: weatherLeg('g1'),
      onColorByChange,
    })
    fireEvent.click(screen.getByLabelText('Météo'))
    expect(onColorByChange).toHaveBeenCalledWith('wind')
    // Held by the page: nothing changes until it says so
    expect(seen.map.lineColorAt).toBeUndefined()
    rerender(
      <MemoryRouter initialEntries={['/map']}>
        <MantineProvider>
          <RouteFullscreenView
            route={windRoute()}
            title="Groupe Rapide"
            backTo="/back"
            colorBy="wind"
            windLeg={weatherLeg('g1')}
            onColorByChange={onColorByChange}
          />
        </MantineProvider>
      </MemoryRouter>
    )
    expect(seen.map.lineColorAt).toBeDefined()
  })
})
