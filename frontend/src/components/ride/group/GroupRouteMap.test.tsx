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
    }: {
      route: RouteDetailDto
      colorBy?: string
      lineColorAt?: (track: number, point: number) => string | undefined
      lineAttribution?: string
    }) => (
      <div data-testid="map">
        <span data-testid="map-color-by">{colorBy}</span>
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

function tree(r: RouteDetailDto | undefined, leg?: WeatherLegDto) {
  return (
    <MantineProvider>
      <GroupRouteMap
        teamSlug="t"
        routeSlug="r"
        route={r}
        leg={leg}
        attribution={leg ? okWeather.attribution : undefined}
        withActions={false}
      />
    </MantineProvider>
  )
}

function show(r: RouteDetailDto | undefined, leg?: WeatherLegDto) {
  return render(tree(r, leg))
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
  })
})
