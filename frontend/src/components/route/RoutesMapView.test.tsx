import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import type { RouteDetailDto, WeatherLegDto } from '@/api/dto'
import { NEUTRAL_COLOR } from '@/components/map/mapUtils'
import { routeColor } from '@/lib/routeColors'
import type { MapItemWind } from '@/lib/tripWeatherOnMap'
import { weatherLeg } from '@/test/weatherFixtures'

const state = vi.hoisted(() => ({
  sources: [] as Record<string, unknown>[],
  layers: [] as Record<string, unknown>[],
  markers: [] as Record<string, unknown>[],
  toggleTrace: undefined as ((itemId: string) => void) | undefined,
  toggleTracks: undefined as (() => void) | undefined,
  moved: [] as string[],
}))

// The map and its layers as plain DOM: what matters is what each trace is handed.
vi.mock('react-map-gl/maplibre', () => ({
  useMap: () => ({ current: undefined }),
  Source: (props: Record<string, unknown> & { children?: React.ReactNode }) => {
    state.sources.push(props)
    return <>{props.children}</>
  },
  Layer: (props: Record<string, unknown>) => {
    state.layers.push(props)
    return null
  },
  FullscreenControl: () => null,
}))
vi.mock('react-chartjs-2', () => ({ Line: () => null }))
vi.mock('../map/PedalonsMap', () => ({
  PedalonsMap: ({
    children,
    onTraceToggle,
    ref,
  }: {
    children?: React.ReactNode
    onTraceToggle?: (itemId: string) => void
    ref?: React.RefObject<unknown>
  }) => {
    state.toggleTrace = onTraceToggle
    if (ref) {
      ref.current = {
        getMap: () => ({
          getLayer: (id: string) => !id.startsWith('wind-arrows-'),
          moveLayer: (id: string) => state.moved.push(id),
        }),
      }
    }
    return <div>{children}</div>
  },
}))
vi.mock('../map/HideTrackControl', () => ({
  HideTrackControl: ({ onToggle }: { onToggle: () => void }) => {
    state.toggleTracks = onToggle
    return null
  },
}))
vi.mock('../map/MapMarkers', () => ({
  StartMarker: () => null,
  EndMarker: () => null,
  HoverMarker: () => null,
  KmMarkersTracesLayer: ({ traces }: { traces: { id: string }[] }) => (
    <span data-testid="km-markers">{traces.map((trace) => trace.id).join(',')}</span>
  ),
}))
vi.mock('@/components/weather/WeatherCheckpointMarkers', () => ({
  WeatherCheckpointMarkers: (props: Record<string, unknown>) => {
    state.markers.push(props)
    return <span data-testid="weather-markers">{props.timezone as string}</span>
  },
}))

const route = (slug: string, lon: number): RouteDetailDto =>
  ({
    slug,
    name: slug,
    distance: 20_000,
    elevationGain: 100,
    tracks: [
      {
        line: {
          type: 'LineString',
          coordinates: Array.from({ length: 21 }, (_, i) => [lon, 45 + i * 0.009, 100, i * 1000]),
        },
        climbs: [],
      },
    ],
    waypoints: [],
  }) as unknown as RouteDetailDto

const ROUTES = [route('aller', 5), route('retour', 6), route('fin', 7)]
vi.mock('@/hooks/useRoutesBulk', () => ({
  useRoutesBulk: () => ({ data: { routes: ROUTES }, isLoading: false }),
}))

import { RoutesMapView } from './RoutesMapView'

const ITEMS = [
  { id: 's1', name: 'Aller', routeSlug: 'aller' },
  { id: 's2', name: 'Retour', routeSlug: 'retour' },
  { id: 's3', name: 'Fin', routeSlug: 'fin' },
]

const headAll = weatherLeg(undefined, {
  segments: [{ fromDistance: 0, toDistance: 20_000, relativeWind: 'HEAD', headwind: 10 }],
})
const tailAll = weatherLeg(undefined, {
  segments: [{ fromDistance: 0, toDistance: 20_000, relativeWind: 'TAIL', headwind: -10 }],
})

const WINDS = new Map<string, MapItemWind>([
  ['s1', { leg: headAll, timezone: 'Europe/Paris' }],
  ['s2', { leg: tailAll, timezone: 'Europe/Lisbon' }],
])

function show(winds?: ReadonlyMap<string, MapItemWind>) {
  return render(view(winds))
}

function view(winds?: ReadonlyMap<string, MapItemWind>) {
  return (
    <MantineProvider>
      <RoutesMapView
        items={ITEMS}
        teamSlug="np"
        winds={winds}
        windAttribution={
          winds ? { name: 'Open-Meteo.com', url: 'https://open-meteo.com/' } : undefined
        }
      />
    </MantineProvider>
  )
}

/** The colours of the line source of item `id`, as the last render handed them. */
function lineColors(id: string): unknown[] {
  const source = state.sources.findLast((s) => s.id === `route-${id}`)
  const data = source?.data as GeoJSON.FeatureCollection
  return data.features.map((f) => f.properties?.color)
}
const linePaint = (id: string) =>
  state.layers.findLast((l) => l.id === `line-${id}`)?.paint as Record<string, unknown>

describe('RoutesMapView', () => {
  describe('km markers (WEB-145, WEB-146)', () => {
    const shown = (kmMarkers?: boolean) => {
      render(
        <MantineProvider>
          <RoutesMapView items={ITEMS} teamSlug="np" kmMarkers={kmMarkers} />
        </MantineProvider>
      )
      return screen.queryByTestId('km-markers')?.textContent ?? null
    }

    it('shows those of every trace when asked', () => {
      expect(shown(true)).toBe('s1,s2,s3')
    })

    it('not unless asked', () => {
      expect(shown()).toBeNull()
    })

    it('drops the trace ticked off in the basemap panel', () => {
      shown(true)
      act(() => state.toggleTrace!('s2'))
      expect(screen.getByTestId('km-markers').textContent).toBe('s1,s3')
    })
  })

  beforeEach(() => {
    state.sources = []
    state.layers = []
    state.moved = []
    state.markers = []
  })
  afterEach(cleanup)

  it('draws each trace in its own colour, no forecast point, without the Météo mode', () => {
    show()
    expect(linePaint('s1')['line-color']).toBe(routeColor(0))
    expect(linePaint('s2')['line-color']).toBe(routeColor(1))
    expect(screen.queryAllByTestId('weather-markers')).toHaveLength(0)
    expect(state.sources.some((s) => s.id === 'routes-wind-credit')).toBe(false)
  })

  it("draws each trace's chevrons on its line's own source, cut once", () => {
    show()
    expect(state.sources.some((s) => String(s.id).startsWith('route-arrows-'))).toBe(false)
    expect(state.layers.some((l) => l.id === 'arrows-s1')).toBe(true)
  })

  // WEB-130: under the 3D terrain a paint change alone never reaches the screen
  it('moves the lit trace above the others, which also repaints it under the terrain', () => {
    const lit = (highlightedItemId: string) => (
      <MantineProvider>
        <RoutesMapView items={ITEMS} teamSlug="np" highlightedItemId={highlightedItemId} />
      </MantineProvider>
    )
    const { rerender } = render(lit('s2'))
    expect(state.moved).toEqual(['line-s2', 'arrows-s2'])

    state.moved = []
    rerender(lit('s3'))
    expect(state.moved).toEqual(['line-s3', 'arrows-s3'])

    state.moved = []
    rerender(lit('s3'))
    expect(state.moved).toEqual([])
  })

  // WEB-130: the first trace is lit from the start, so hovering it changes nothing afterwards
  it('mounts the lit trace last, so it starts above the others', () => {
    show()
    expect(state.layers.filter((l) => String(l.id).startsWith('line-')).map((l) => l.id)).toEqual([
      'line-s2',
      'line-s3',
      'line-s1',
    ])
  })

  it('stays on the last hovered trace once nothing is hovered', () => {
    const lit = (highlightedItemId: string | null) => (
      <MantineProvider>
        <RoutesMapView items={ITEMS} teamSlug="np" highlightedItemId={highlightedItemId} />
      </MantineProvider>
    )
    const { rerender } = render(lit('s2'))
    rerender(lit(null))
    expect(linePaint('s2')['line-width']).toBe(8)
    expect(linePaint('s1')['line-width']).toBe(5)
  })

  it('goes back to the first trace when the last hovered one is unticked', () => {
    const lit = (highlightedItemId: string | null) => (
      <MantineProvider>
        <RoutesMapView items={ITEMS} teamSlug="np" highlightedItemId={highlightedItemId} />
      </MantineProvider>
    )
    const { rerender } = render(lit('s2'))
    rerender(lit(null))
    act(() => state.toggleTrace!('s2'))
    expect(linePaint('s1')['line-width']).toBe(8)
  })

  // WEB-130: the texture is drawn once, so a fade would stay frozen at its first frames
  it('does not fade the highlight', () => {
    show()
    expect(linePaint('s1')).toMatchObject({
      'line-width-transition': { duration: 0 },
      'line-opacity-transition': { duration: 0 },
    })
  })

  describe('in the Météo mode (a trip overview, WEB-118)', () => {
    it('colours every stage by its own wind, a stage without a forecast in the default colour', () => {
      show(WINDS)
      expect(linePaint('s1')['line-color']).toEqual(['get', 'color'])
      const [head] = lineColors('s1')
      const [tail] = lineColors('s2')
      expect(head).not.toBe(tail)
      expect(lineColors('s1').every((c) => c === head)).toBe(true)
      expect(lineColors('s3')).toEqual([NEUTRAL_COLOR])
      // The chevrons keep the whole tracks, on a source of their own
      expect(state.sources.findLast((s) => s.id === 'route-arrows-s1')?.data).toBeDefined()
      expect(state.layers.some((l) => l.id === 'wind-arrows-s1')).toBe(true)
    })

    it("puts the badges of every stage with a forecast, each in its stage's zone", () => {
      show(WINDS)
      const badges = screen.getAllByTestId('weather-markers')
      expect(badges.map((b) => b.textContent)).toEqual(['Europe/Paris', 'Europe/Lisbon'])
      expect(state.markers.map((m) => m.leg as WeatherLegDto)).toEqual([headAll, tailAll])
      // Each on its own stage's tracks
      expect(state.markers[0].tracks).toBe(ROUTES[0].tracks)
      expect(state.markers[1].tracks).toBe(ROUTES[1].tracks)
    })

    it('keeps one popup open over the whole map', () => {
      show(WINDS)
      const last = () => state.markers.slice(-2)
      expect(last().map((m) => m.openIndex)).toEqual([null, null])
      act(() => (last()[0].onOpenChange as (i: number | null) => void)(1))
      expect(last().map((m) => m.openIndex)).toEqual([1, null])
      act(() => (last()[1].onOpenChange as (i: number | null) => void)(0))
      expect(last().map((m) => m.openIndex)).toEqual([null, 0])
      // A stage's popup closing never closes another's
      act(() => (last()[0].onOpenChange as (i: number | null) => void)(null))
      expect(last().map((m) => m.openIndex)).toEqual([null, 0])
    })

    it("names each stage on its badges, a multi-day trip's stages told apart", () => {
      show(WINDS)
      expect(state.markers.slice(-2).map((m) => m.context)).toEqual(['Aller', 'Retour'])
    })

    it('never reopens a popup by itself once the Météo mode was left', () => {
      const { rerender } = show(WINDS)
      const last = () => state.markers.slice(-2)
      act(() => (last()[0].onOpenChange as (i: number | null) => void)(1))
      expect(last().map((m) => m.openIndex)).toEqual([1, null])
      rerender(view())
      rerender(view(WINDS))
      expect(last().map((m) => m.openIndex)).toEqual([null, null])
    })

    it('never reopens a popup by itself once its trace, or every trace, was hidden', () => {
      show(WINDS)
      const last = () => state.markers.slice(-2)
      const open = () => act(() => (last()[0].onOpenChange as (i: number | null) => void)(1))
      open()
      act(() => state.toggleTrace!('s1'))
      expect(state.markers.at(-1)?.leg).toBe(tailAll)
      act(() => state.toggleTrace!('s1'))
      expect(last().map((m) => m.openIndex)).toEqual([null, null])
      open()
      act(() => state.toggleTracks!())
      act(() => state.toggleTracks!())
      expect(last().map((m) => m.openIndex)).toEqual([null, null])
    })

    it("owes the forecast's credit on the map", () => {
      show(WINDS)
      const credit = state.sources.findLast((s) => s.id === 'routes-wind-credit')
      expect(credit?.attribution).toContain('Open-Meteo.com')
    })
  })

  // docs/LEDGER_*.md WEB-157: the class that sizes the profile and lifts the bottom line
  describe('bottom inset under the profile (WEB-157)', () => {
    const wrapper = (container: HTMLElement) => container.querySelector('.map-stack')!

    it('is set on the map wrapper while the profile is drawn', () => {
      const { container } = show()
      expect(wrapper(container).classList.contains('routes-map--profile')).toBe(true)
      expect(container.querySelector('.routes-map-profile')).not.toBeNull()
    })

    it('goes with the profile, once every trace is unticked', () => {
      const { container } = show()
      act(() => ITEMS.forEach((item) => state.toggleTrace!(item.id)))
      expect(container.querySelector('.routes-map-profile')).toBeNull()
      expect(wrapper(container).classList.contains('routes-map--profile')).toBe(false)
    })
  })
})
