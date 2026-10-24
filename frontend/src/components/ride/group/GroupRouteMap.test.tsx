import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import {
  TrackSurface,
  TrackSurfaceState,
  WeatherStatus,
  type RouteDetailDto,
  type TrackDto,
  type WeatherLegDto,
} from '@/api/dto'
import { NEUTRAL_COLOR, getColorFromGradient } from '@/components/map/mapUtils'
import { okWeather, plain, weatherLeg } from '@/test/weatherFixtures'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

// The map is lazy and pulls map vendors: a stand-in that exposes the colour mode it was given,
// the line's colour at the first point when the caller colours it, the colours of the pieces the
// real map would draw, and the line's credit.
vi.mock('@/components/route/RouteMapView', async () => {
  const { createGradientLineFeatures } = await import('@/components/map/mapUtils')
  return {
    RouteMapView: ({
      route,
      colorBy,
      lineColorAt,
      lineAttribution,
      overlays,
      kmMarkers = true,
      fullscreenPath,
    }: {
      route: RouteDetailDto
      colorBy?: string
      lineColorAt?: (track: number, point: number) => string | undefined
      lineAttribution?: string
      overlays?: React.ReactNode
      kmMarkers?: boolean
      fullscreenPath?: string
    }) => (
      <div data-testid="map">
        <span data-testid="map-fullscreen">{fullscreenPath}</span>
        <span data-testid="map-color-by">{colorBy}</span>
        {kmMarkers && <span data-testid="map-km-markers" />}
        {overlays}
        {lineColorAt && (
          <>
            <span data-testid="map-line-color">{lineColorAt(0, 0) ?? 'default'}</span>
            <span data-testid="map-line-pieces">
              {createGradientLineFeatures(route.tracks, lineColorAt)
                .features.map((f) => f.properties?.color)
                .join(' ')}
            </span>
          </>
        )}
        {lineAttribution && <span data-testid="map-credit">{lineAttribution}</span>}
      </div>
    ),
  }
})
// The forecast's points pull react-map-gl: a stand-in saying what it was handed.
vi.mock('@/components/weather/WeatherCheckpointMarkers', () => ({
  WeatherCheckpointMarkers: ({
    leg,
    timezone,
    openIndex,
    onOpenChange,
  }: {
    leg: WeatherLegDto
    timezone?: string
    openIndex?: number | null
    onOpenChange?: (index: number | null) => void
  }) => (
    <>
      <span data-testid="weather-markers">
        {leg.checkpoints.length} {timezone}
      </span>
      <span data-testid="weather-markers-open">{String(openIndex)}</span>
      <button type="button" onClick={() => onOpenChange?.(1)}>
        badge 1
      </button>
    </>
  ),
}))
vi.mock('@/components/ride/RideGroupRouteActions', () => ({
  RideGroupRouteActions: () => null,
}))

import { GroupRouteMap } from './GroupRouteMap'

function route(track: Partial<TrackDto>): RouteDetailDto {
  return {
    waypoints: [],
    tracks: [{ line: { type: 'LineString', coordinates: [] }, climbs: [], ...track }],
  } as unknown as RouteDetailDto
}

/** A 50 km track, its points every 10 km: the fixture leg's single head-wind stretch covers it. */
const LINE = {
  type: 'LineString',
  coordinates: Array.from({ length: 6 }, (_, i) => [5, 45 + i * 0.09, 300, i * 10_000]),
}

function tree(
  r: RouteDetailDto | undefined,
  leg?: WeatherLegDto,
  extra: Partial<React.ComponentProps<typeof GroupRouteMap>> = {}
) {
  return (
    <MantineProvider>
      <GroupRouteMap
        {...extra}
        teamSlug="t"
        routeSlug="r"
        route={r}
        leg={leg}
        attribution={leg ? okWeather.attribution : undefined}
        timezone="Europe/Paris"
        withActions={false}
      />
    </MantineProvider>
  )
}

function show(
  r: RouteDetailDto | undefined,
  leg?: WeatherLegDto,
  extra: Partial<React.ComponentProps<typeof GroupRouteMap>> = {}
) {
  return render(tree(r, leg, extra))
}

describe('GroupRouteMap', () => {
  afterEach(cleanup)

  it('offers the grade / surface switch when the track has a surface', async () => {
    show(
      route({
        surfaceState: TrackSurfaceState.READY,
        surfaces: [{ from: 0, to: 1000, surface: TrackSurface.PAVED }],
      })
    )
    expect(await screen.findByTestId('route-surface-summary')).toBeTruthy()
    expect((await screen.findByTestId('map-color-by')).textContent).toBe('grade')
  })

  it('shows no switch without surfaces', async () => {
    show(route({}))
    await screen.findByTestId('map')
    expect(screen.queryByTestId('route-surface-summary')).toBeNull()
    expect(screen.queryByRole('radiogroup')).toBeNull()
  })

  describe('the wind on the map (WEB-115)', () => {
    it('offers « Pente | Météo » without a surface, the grade by default', async () => {
      show(route({ line: LINE } as Partial<TrackDto>), weatherLeg('g1'))
      expect((await screen.findByTestId('map-color-by')).textContent).toBe('grade')
      const control = screen.getByRole('radiogroup', { name: /Colorer le tracé selon/ })
      expect(plain(control.textContent)).toBe('PenteMétéo')
      expect(screen.queryByTestId('map-line-color')).toBeNull()
      expect(screen.queryByTestId('wind-map-legend')).toBeNull()
    })

    it('offers the three modes with a surface', async () => {
      show(
        route({
          line: LINE,
          surfaceState: TrackSurfaceState.READY,
          surfaces: [{ from: 0, to: 50_000, surface: TrackSurface.PAVED }],
        } as Partial<TrackDto>),
        weatherLeg('g1')
      )
      await screen.findByTestId('map')
      const control = screen.getByRole('radiogroup', { name: /Colorer le tracé selon/ })
      expect(plain(control.textContent)).toBe('PenteRevêtementMétéo')
    })

    it('colours the line by the wind, the profile staying on the grade, and says it in words', async () => {
      show(route({ line: LINE } as Partial<TrackDto>), weatherLeg('g1'))
      await screen.findByTestId('map')
      fireEvent.click(screen.getByLabelText('Météo'))
      expect(screen.getByTestId('map-color-by').textContent).toBe('grade')
      // The fixture's head wind: orange-6 of the generated family
      expect(screen.getByTestId('map-line-color').textContent).toBe('#fd7e14')
      expect(screen.getByTestId('map-credit').textContent).toContain('Open-Meteo.com')
      const legend = plain(screen.getByTestId('wind-map-legend').textContent)
      expect(legend).toContain('Vent sur le tracé :')
      // The exposure bar's totals and units
      expect(legend).toMatch(/Face 50[.,]0 km/)
      expect(legend).not.toContain('Dos')
      expect(legend).toContain('Heures de passage estimées à 25 km/h, vitesse par défaut')
      expect(legend).toContain('Prévisions Open-Meteo.com')
      expect(legend).not.toContain('Prévision ancienne')
    })

    it('flags an old forecast', async () => {
      show(
        route({ line: LINE } as Partial<TrackDto>),
        weatherLeg('g1', { status: WeatherStatus.STALE, speedIsDefault: false })
      )
      await screen.findByTestId('map')
      fireEvent.click(screen.getByLabelText('Météo'))
      const legend = plain(screen.getByTestId('wind-map-legend').textContent)
      expect(legend).toContain('Prévision ancienne')
      expect(legend).not.toContain('vitesse par défaut')
    })

    it('keeps the default colour where no stretch is known, even in a climb', async () => {
      show(
        route({
          line: LINE,
          // A 7 % climb over the first 20 km: its grade colour is an orange
          climbs: [{ startDistance: 0, endDistance: 20_000, averageGradient: 7 }],
        } as unknown as Partial<TrackDto>),
        weatherLeg('g1', {
          segments: [
            { fromDistance: 20_000, toDistance: 50_000, relativeWind: 'TAIL', headwind: 0 },
          ],
        })
      )
      await screen.findByTestId('map')
      fireEvent.click(screen.getByLabelText('Météo'))
      expect(screen.getByTestId('map-line-color').textContent).toBe(NEUTRAL_COLOR)
      // The unknown stretch in the climb's default colour, never its grade's, then the tail wind
      const pieces = screen.getByTestId('map-line-pieces').textContent!.split(' ')
      expect(pieces).toHaveLength(2)
      expect(pieces[0]).toBe(NEUTRAL_COLOR)
      expect(pieces[0]).not.toBe(getColorFromGradient(7))
      expect(pieces[1]).not.toBe(NEUTRAL_COLOR)
    })

    it('falls back to the grade when the forecast goes', async () => {
      const r = route({ line: LINE } as Partial<TrackDto>)
      const { rerender } = show(r, weatherLeg('g1'))
      await screen.findByTestId('map')
      fireEvent.click(screen.getByLabelText('Météo'))
      expect(screen.getByTestId('map-line-color')).toBeTruthy()
      rerender(tree(r, undefined))
      expect(screen.getByTestId('map-color-by').textContent).toBe('grade')
      expect(screen.queryByTestId('map-line-color')).toBeNull()
      expect(screen.queryByTestId('map-credit')).toBeNull()
      expect(screen.queryByTestId('wind-map-legend')).toBeNull()
      expect(screen.queryByRole('radiogroup')).toBeNull()
    })

    it('puts the forecast points on the map in the Météo mode only, the km markers gone (WEB-116)', async () => {
      show(route({ line: LINE } as Partial<TrackDto>), weatherLeg('g1'))
      await screen.findByTestId('map')
      expect(screen.queryByTestId('weather-markers')).toBeNull()
      expect(screen.getByTestId('map-km-markers')).toBeTruthy()
      fireEvent.click(screen.getByLabelText('Météo'))
      expect((await screen.findByTestId('weather-markers')).textContent).toBe('2 Europe/Paris')
      expect(screen.queryByTestId('map-km-markers')).toBeNull()
      fireEvent.click(screen.getByLabelText('Pente'))
      expect(screen.queryByTestId('weather-markers')).toBeNull()
      expect(screen.getByTestId('map-km-markers')).toBeTruthy()
    })

    it('puts no forecast point without a leg, the km markers kept', async () => {
      show(route({ line: LINE } as Partial<TrackDto>))
      await screen.findByTestId('map')
      expect(screen.queryByTestId('weather-markers')).toBeNull()
      expect(screen.getByTestId('map-km-markers')).toBeTruthy()
    })
  })

  describe('the fullscreen map and the shared point (WEB-117)', () => {
    it("opens the route's own map without a path of the page's", async () => {
      show(route({ line: LINE } as Partial<TrackDto>), weatherLeg('g1'))
      expect((await screen.findByTestId('map-fullscreen')).textContent).toMatch(/\/r\/(carte|map)$/)
    })

    it('opens the fullscreen map in the mode the line is in', async () => {
      const fullscreenPath = (colorBy: string) => `/plein-ecran?mode=${colorBy}`
      show(route({ line: LINE } as Partial<TrackDto>), weatherLeg('g1'), { fullscreenPath })
      expect((await screen.findByTestId('map-fullscreen')).textContent).toBe(
        '/plein-ecran?mode=grade'
      )
      fireEvent.click(screen.getByLabelText('Météo'))
      expect(screen.getByTestId('map-fullscreen').textContent).toBe('/plein-ecran?mode=wind')
    })

    it("hands the page's point to the badges, and their choice back to it", async () => {
      const onSelectCheckpoint = vi.fn()
      show(route({ line: LINE } as Partial<TrackDto>), weatherLeg('g1'), {
        selectedCheckpoint: 0,
        onSelectCheckpoint,
      })
      await screen.findByTestId('map')
      fireEvent.click(screen.getByLabelText('Météo'))
      expect((await screen.findByTestId('weather-markers-open')).textContent).toBe('0')
      fireEvent.click(screen.getByRole('button', { name: 'badge 1' }))
      expect(onSelectCheckpoint).toHaveBeenCalledWith(1)
    })

    it('leaves the badges their own popup when the page holds none', async () => {
      show(route({ line: LINE } as Partial<TrackDto>), weatherLeg('g1'))
      await screen.findByTestId('map')
      fireEvent.click(screen.getByLabelText('Météo'))
      expect((await screen.findByTestId('weather-markers-open')).textContent).toBe('undefined')
    })
  })
})
