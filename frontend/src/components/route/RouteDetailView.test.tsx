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

describe('RouteDetailView — what a page sets above the climbs (WEB-143)', () => {
  afterEach(cleanup)

  it('stands under the map and just before the climbs', () => {
    const climb = {
      startDistance: 0,
      endDistance: 1000,
      elevationGain: 80,
      averageGradient: 8,
      maxGradient: 10,
    }
    show({
      route: { ...ROUTE, tracks: [{ ...ROUTE.tracks[0], climbs: [climb] }] } as RouteDetailDto,
      beforeClimbs: <div data-testid="forecast" />,
    })
    const forecast = screen.getByTestId('forecast')
    const climbs = screen.getByRole('heading', { level: 4 })
    const follows = (a: Element, b: Element) =>
      !!(a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING)
    expect(follows(screen.getByTestId('route-map'), forecast)).toBe(true)
    expect(follows(forecast, climbs)).toBe(true)
  })
})

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

describe('RouteDetailView — the page’s extra actions (WEB-169)', () => {
  afterEach(cleanup)

  const withGpx = {
    ...ROUTE,
    media: { markdown: '', assets: { gpx: { url: '/aller.gpx' } } },
  } as unknown as RouteDetailDto

  it('renders them in the downloads’ row, after the downloads', () => {
    show({ route: withGpx, extraActions: <button type="button">Modifier une copie</button> })
    const download = screen.getByRole('link', { name: 'Télécharger GPX' })
    const extra = screen.getByRole('button', { name: 'Modifier une copie' })
    expect(download.parentElement).toBe(extra.parentElement)
    expect(!!(download.compareDocumentPosition(extra) & Node.DOCUMENT_POSITION_FOLLOWING)).toBe(
      true
    )
  })

  it('renders them even without a download to offer', () => {
    show({ extraActions: <button type="button">Modifier une copie</button> })
    expect(screen.getByRole('button', { name: 'Modifier une copie' })).toBeTruthy()
    expect(screen.queryByRole('link', { name: 'Télécharger GPX' })).toBeNull()
  })

  it('renders them in a row of their own', () => {
    show({ extraActions: <button type="button">Modifier une copie</button> })
    expect(screen.getByTestId('route-downloads')).toBeTruthy()
  })

  it('renders no row when there is neither', () => {
    show({ route: withGpx, showDownload: false })
    expect(screen.queryByRole('link', { name: 'Télécharger GPX' })).toBeNull()
    expect(screen.queryByTestId('route-downloads')).toBeNull()
  })

  it('renders no row when the page hides its action (extraActions={false})', () => {
    const { container } = show({ route: withGpx, showDownload: false, extraActions: false })
    expect(screen.queryByTestId('route-downloads')).toBeNull()
    expect(container.textContent).not.toContain('false')
  })
})
