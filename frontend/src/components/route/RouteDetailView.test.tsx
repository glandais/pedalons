import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import type { RouteDetailDto } from '@/api/dto'
import { weatherLeg } from '@/test/weatherFixtures'
import { withMapColor } from '@/hooks/filters/mapColorFilters'
import type { ColorByOption } from './ColorByControl'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

const state = vi.hoisted(() => ({ map: {} as Record<string, unknown> }))
vi.mock('./RouteMapView', () => ({
  RouteMapView: (props: Record<string, unknown>) => {
    state.map = props
    return <div data-testid="route-map" />
  },
}))
vi.mock('@/hooks/useAuth', () => ({ useAuth: () => ({ isAuthenticated: false }) }))
vi.mock('@/hooks/useGpsConnections', () => ({
  useGpsConnections: () => ({ connectedServices: [], uploadRoute: () => {}, isUploading: false }),
}))

import { RouteDetailView } from './RouteDetailView'

const ROUTE = {
  slug: 'aller',
  name: 'Aller',
  distance: 50_000,
  elevationGain: 300,
  elevationLoss: 300,
  visibility: 'PUBLIC',
  createdAt: '2026-10-01T00:00:00Z',
  media: { markdown: '', assets: {} },
  tags: [],
  waypoints: [],
  tracks: [
    {
      line: {
        type: 'LineString',
        coordinates: [
          [5, 45, 100, 0],
          [5, 45.45, 100, 50_000],
        ],
      },
      climbs: [],
    },
  ],
} as unknown as RouteDetailDto

const stageMap = (colorBy: ColorByOption) =>
  withMapColor('/equipes/np/voyages/v/etapes/e/carte', colorBy)

function show(props: Partial<Parameters<typeof RouteDetailView>[0]> = {}) {
  return render(
    <MantineProvider>
      <MemoryRouter>
        <RouteDetailView route={ROUTE} showInfo={false} fullscreenPath={stageMap} {...props} />
      </MemoryRouter>
    </MantineProvider>
  )
}

describe('RouteDetailView — a stage’s Météo mode (WEB-118)', () => {
  beforeEach(() => {
    state.map = {}
  })
  afterEach(cleanup)

  it('offers no mode switch without a forecast nor a surface, its map plain', () => {
    show()
    expect(screen.queryByTestId('route-color-by')).toBeNull()
    expect(state.map.fullscreenPath).toBe(stageMap('grade'))
    expect(state.map.lineColorAt).toBeUndefined()
    expect(state.map.kmMarkers).toBe(true)
  })

  it('keeps a plain fullscreen path as is (the route sheet)', () => {
    show({ fullscreenPath: '/carte' })
    expect(state.map.fullscreenPath).toBe('/carte')
  })

  it('offers « Pente | Météo » with a forecast, the grade by default', () => {
    show({ windLeg: weatherLeg(undefined), timezone: 'Europe/Lisbon' })
    expect(screen.getByLabelText('Météo')).toBeTruthy()
    expect(state.map.colorBy).toBe('grade')
    expect(state.map.overlays).toBeUndefined()
  })

  it('colours the line by the wind, puts the badges, and opens its fullscreen map in that mode', () => {
    show({
      windLeg: weatherLeg(undefined),
      windAttribution: { name: 'Open-Meteo.com', url: 'https://open-meteo.com/' },
      timezone: 'Europe/Lisbon',
    })
    fireEvent.click(screen.getByLabelText('Météo'))
    expect(state.map.lineColorAt).toBeTypeOf('function')
    // The profile stays on the grade
    expect(state.map.colorBy).toBe('grade')
    expect(state.map.kmMarkers).toBe(false)
    expect(state.map.overlays).toBeTruthy()
    expect(state.map.lineAttribution).toContain('Open-Meteo.com')
    expect(state.map.fullscreenPath).toBe(stageMap('wind'))
    const legend = screen.getByTestId('wind-map-legend').textContent ?? ''
    // The stage's own wording of the default speed
    expect(legend).toContain("l'étape n'en indique pas")
  })

  it('falls back on the grade when the forecast goes', () => {
    const { rerender } = show({ windLeg: weatherLeg(undefined) })
    fireEvent.click(screen.getByLabelText('Météo'))
    rerender(
      <MantineProvider>
        <MemoryRouter>
          <RouteDetailView route={ROUTE} showInfo={false} fullscreenPath={stageMap} />
        </MemoryRouter>
      </MantineProvider>
    )
    expect(state.map.lineColorAt).toBeUndefined()
    expect(state.map.fullscreenPath).toBe(stageMap('grade'))
    expect(screen.queryByTestId('wind-map-legend')).toBeNull()
  })
})
