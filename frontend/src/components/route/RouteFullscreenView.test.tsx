import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { Link, MemoryRouter, Route, Routes, useLocation } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { TrackSurface, TrackSurfaceState, type TrackDto } from '@/api/dto'

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
