// The surface of a saved track (WEB-100 C1b): reading the spans per point and per class.
import { describe, expect, it } from 'vitest'
import { createTheme, DEFAULT_THEME, mergeMantineTheme } from '@mantine/core'
import {
  SurfaceType,
  TrackSurface,
  TrackSurfaceState,
  type SurfaceSpanDto,
  type TrackDto,
} from '@/api/dto'
import { TRACK_SURFACE_COLORS } from '@/lib/badgeColors.generated'
import {
  TRACK_SURFACES,
  TRACK_SURFACE_SHADES,
  hasSurfaces,
  pointSurfaces,
  surfaceAtDistance,
  surfaceShares,
  suggestSurfaceType,
  surfacesPending,
  trackSurfaceColors,
} from './trackSurface'
import { surfaceColors } from './plannerSurface'

const span = (from: number, to: number, surface: TrackSurface): SurfaceSpanDto => ({
  from,
  to,
  surface,
})

/** A track with a point every 100 m (M restarts at 0), `n` points. */
function track(n: number, extra: Partial<TrackDto> = {}): TrackDto {
  return {
    line: {
      type: 'LineString',
      coordinates: Array.from({ length: n }, (_, i) => [2 + i * 0.001, 45, 100, i * 100]),
    },
    climbs: [],
    ...extra,
  }
}

const SPANS = [
  span(0, 250, TrackSurface.PAVED),
  span(250, 400, TrackSurface.GRAVEL),
  span(400, 500, TrackSurface.PATH),
]

describe('TRACK_SURFACES', () => {
  it('lists every class once, in legend order', () => {
    expect(TRACK_SURFACES).toEqual([
      'PAVED',
      'PAVED_ROUGH',
      'GRAVEL',
      'DIRT',
      'PATH',
      'UNKNOWN',
      'OFF_NETWORK',
    ])
    for (const shades of Object.values(TRACK_SURFACE_SHADES)) {
      expect(Object.keys(shades).sort()).toEqual([...TRACK_SURFACES].sort())
    }
  })
})

describe('trackSurfaceColors', () => {
  const theme = mergeMantineTheme(DEFAULT_THEME, createTheme({}))

  it.each(['light', 'dark'] as const)(
    'resolves the generated families at the %s shades, the three greys apart',
    (scheme) => {
      const colors = trackSurfaceColors(theme, scheme)
      for (const s of TRACK_SURFACES) {
        expect(colors[s]).toBe(
          theme.colors[TRACK_SURFACE_COLORS[s]][TRACK_SURFACE_SHADES[scheme][s]]
        )
      }
      expect(new Set([colors.PAVED, colors.UNKNOWN, colors.OFF_NETWORK]).size).toBe(3)
    }
  )

  it('keeps unknown visible on a light basemap', () => {
    const light = trackSurfaceColors(theme, 'light')
    expect(light.PAVED).toBe(theme.colors.gray[9])
    expect(light.OFF_NETWORK).toBe(theme.colors.gray[7])
    expect(light.UNKNOWN).toBe(theme.colors.gray[6])
  })

  it('lightens paved and dims unknown on the dark basemap', () => {
    const dark = trackSurfaceColors(theme, 'dark')
    expect(dark.PAVED).toBe(theme.colors.gray[2])
    expect(dark.UNKNOWN).toBe(theme.colors.gray[6])
    expect(dark.OFF_NETWORK).toBe(theme.colors.gray[4])
  })
})

describe('the route being drawn (C1a)', () => {
  const theme = mergeMantineTheme(DEFAULT_THEME, createTheme({}))

  it('keeps its colours, now read from the saved route', () => {
    expect(surfaceColors(theme, 'light')).toEqual({
      paved: theme.colors.gray[9],
      unpaved: theme.colors.orange[6],
      unknown: theme.colors.gray[6],
      offNetwork: theme.colors.gray[7],
    })
    expect(surfaceColors(theme, 'dark')).toEqual({
      paved: theme.colors.gray[2],
      unpaved: theme.colors.orange[6],
      unknown: theme.colors.gray[6],
      offNetwork: theme.colors.gray[4],
    })
    for (const scheme of ['light', 'dark'] as const) {
      const saved = trackSurfaceColors(theme, scheme)
      expect(surfaceColors(theme, scheme)).toEqual({
        paved: saved.PAVED,
        unpaved: saved.GRAVEL,
        unknown: saved.UNKNOWN,
        offNetwork: saved.OFF_NETWORK,
      })
    }
  })
})

describe('surfaceAtDistance', () => {
  it('finds the span, a boundary belonging to the span that starts there', () => {
    expect(surfaceAtDistance(SPANS, 0)).toBe('PAVED')
    expect(surfaceAtDistance(SPANS, 249.9)).toBe('PAVED')
    expect(surfaceAtDistance(SPANS, 250)).toBe('GRAVEL')
    expect(surfaceAtDistance(SPANS, 400)).toBe('PATH')
    expect(surfaceAtDistance(SPANS, 500)).toBe('PATH')
  })

  it('is UNKNOWN outside the spans and without any', () => {
    expect(surfaceAtDistance(SPANS, -1)).toBe('UNKNOWN')
    expect(surfaceAtDistance(SPANS, 501)).toBe('UNKNOWN')
    expect(surfaceAtDistance([], 10)).toBe('UNKNOWN')
    expect(surfaceAtDistance(undefined, 10)).toBe('UNKNOWN')
    expect(surfaceAtDistance(null, 10)).toBe('UNKNOWN')
  })

  it('searches many spans', () => {
    const many = Array.from({ length: 1000 }, (_, i) =>
      span(i * 10, (i + 1) * 10, i % 2 ? TrackSurface.DIRT : TrackSurface.PAVED_ROUGH)
    )
    expect(surfaceAtDistance(many, 5)).toBe('PAVED_ROUGH')
    expect(surfaceAtDistance(many, 7777)).toBe('DIRT')
    expect(surfaceAtDistance(many, 9995)).toBe('DIRT')
  })
})

describe('hasSurfaces / surfacesPending', () => {
  const ready = track(6, { surfaceState: TrackSurfaceState.READY, surfaces: SPANS })
  const pending = track(6, { surfaceState: TrackSurfaceState.PENDING })
  const unavailable = track(6, { surfaceState: TrackSurfaceState.UNAVAILABLE })

  it('needs a READY track with spans', () => {
    expect(hasSurfaces([ready])).toBe(true)
    expect(hasSurfaces([pending, ready])).toBe(true)
    expect(hasSurfaces([pending])).toBe(false)
    expect(hasSurfaces([unavailable])).toBe(false)
    expect(hasSurfaces([track(6)])).toBe(false)
    expect(hasSurfaces([track(6, { surfaceState: TrackSurfaceState.READY, surfaces: [] })])).toBe(
      false
    )
  })

  it('is pending when nothing is ready and something is computing', () => {
    expect(surfacesPending([pending])).toBe(true)
    expect(surfacesPending([pending, unavailable])).toBe(true)
    expect(surfacesPending([pending, ready])).toBe(false)
    expect(surfacesPending([unavailable])).toBe(false)
    expect(surfacesPending([track(6)])).toBe(false)
  })
})

describe('pointSurfaces', () => {
  it('reads the segment each point starts, the last point repeating the previous', () => {
    const t = track(6, { surfaceState: TrackSurfaceState.READY, surfaces: SPANS })
    // midpoints 50, 150, 250, 350, 450 then the last repeats
    expect(pointSurfaces([t])).toEqual(['PAVED', 'PAVED', 'GRAVEL', 'GRAVEL', 'PATH', 'PATH'])
  })

  it('restarts the measure on every track and marks a track without surface UNKNOWN', () => {
    const first = track(3, {
      surfaceState: TrackSurfaceState.READY,
      surfaces: [span(0, 200, TrackSurface.DIRT)],
    })
    const second = track(3, { surfaceState: TrackSurfaceState.PENDING })
    const third = track(2, {
      surfaceState: TrackSurfaceState.READY,
      surfaces: [span(0, 100, TrackSurface.OFF_NETWORK)],
    })
    expect(pointSurfaces([first, second, third])).toEqual([
      'DIRT',
      'DIRT',
      'DIRT',
      'UNKNOWN',
      'UNKNOWN',
      'UNKNOWN',
      'OFF_NETWORK',
      'OFF_NETWORK',
    ])
  })

  it('is null when no track is ready', () => {
    expect(pointSurfaces([track(3, { surfaceState: TrackSurfaceState.PENDING })])).toBeNull()
    expect(pointSurfaces([])).toBeNull()
  })
})

describe('surfaceShares', () => {
  it('sums lengths per class in legend order, dropping the empty ones', () => {
    const t = track(6, {
      surfaceState: TrackSurfaceState.READY,
      surfaces: [
        span(0, 100, TrackSurface.PATH),
        span(100, 300, TrackSurface.PAVED),
        span(300, 400, TrackSurface.PATH),
        span(400, 500, TrackSurface.UNKNOWN),
      ],
    })
    const shares = surfaceShares([t])
    expect(shares.map((s) => s.surface)).toEqual(['PAVED', 'PATH', 'UNKNOWN'])
    expect(shares.map((s) => s.length)).toEqual([200, 200, 100])
    expect(shares.reduce((sum, s) => sum + s.share, 0)).toBeCloseTo(1)
    expect(shares[0].share).toBeCloseTo(0.4)
  })

  it('adds the tracks that are ready and ignores the others', () => {
    const a = track(3, {
      surfaceState: TrackSurfaceState.READY,
      surfaces: [span(0, 100, TrackSurface.DIRT)],
    })
    const b = track(3, { surfaceState: TrackSurfaceState.PENDING })
    expect(surfaceShares([a, b, a])).toEqual([{ surface: 'DIRT', length: 200, share: 1 }])
    expect(surfaceShares([b])).toEqual([])
  })
})

describe('suggestSurfaceType (C1c)', () => {
  /** A READY track whose M ends at `length` (the last point). */
  function ready(length: number, spans: SurfaceSpanDto[]): TrackDto {
    return {
      line: {
        type: 'LineString',
        coordinates: [
          [2, 45, 100, 0],
          [2.01, 45, 100, length],
        ],
      },
      climbs: [],
      surfaceState: TrackSurfaceState.READY,
      surfaces: spans,
    }
  }
  /** 1 000 m: `other` metres of `surface`, the rest paved. */
  function mix(other: number, surface: TrackSurface, length = 1000): TrackDto {
    return ready(length, [span(0, other, surface), span(other, length, TrackSurface.PAVED)])
  }

  it('is null without any READY track', () => {
    expect(suggestSurfaceType([])).toBeNull()
    expect(suggestSurfaceType([track(3)])).toBeNull()
    expect(suggestSurfaceType([track(3, { surfaceState: TrackSurfaceState.PENDING })])).toBeNull()
    expect(
      suggestSurfaceType([track(3, { surfaceState: TrackSurfaceState.UNAVAILABLE })])
    ).toBeNull()
  })

  it('suggests ROAD on paved, rough paving included', () => {
    expect(suggestSurfaceType([ready(1000, [span(0, 1000, TrackSurface.PAVED)])])).toBe(
      SurfaceType.ROAD
    )
    expect(suggestSurfaceType([ready(1000, [span(0, 1000, TrackSurface.PAVED_ROUGH)])])).toBe(
      SurfaceType.ROAD
    )
  })

  it('cuts the unpaved share at 5 % and 20 %', () => {
    expect(suggestSurfaceType([mix(49, TrackSurface.GRAVEL)])).toBe(SurfaceType.ROAD)
    expect(suggestSurfaceType([mix(50, TrackSurface.GRAVEL)])).toBe(SurfaceType.MIXED)
    expect(suggestSurfaceType([mix(200, TrackSurface.GRAVEL)])).toBe(SurfaceType.MIXED)
    expect(suggestSurfaceType([mix(201, TrackSurface.GRAVEL)])).toBe(SurfaceType.GRAVEL)
    expect(suggestSurfaceType([mix(201, TrackSurface.DIRT)])).toBe(SurfaceType.GRAVEL)
  })

  it('needs more than 30 % of paths for MTB', () => {
    expect(suggestSurfaceType([mix(300, TrackSurface.PATH)])).toBe(SurfaceType.GRAVEL)
    expect(suggestSurfaceType([mix(301, TrackSurface.PATH)])).toBe(SurfaceType.MTB)
  })

  it('gives up above 30 % unknown or off the network, over the whole length', () => {
    const half = (unknown: number, off: number) =>
      ready(1000, [
        span(0, unknown, TrackSurface.UNKNOWN),
        span(unknown, unknown + off, TrackSurface.OFF_NETWORK),
        span(unknown + off, 1000, TrackSurface.PAVED),
      ])
    expect(suggestSurfaceType([half(200, 100)])).toBe(SurfaceType.ROAD)
    expect(suggestSurfaceType([half(200, 101)])).toBeNull()
  })

  it('reads the share on the known length', () => {
    // 200 unknown, 40 gravel out of 1 000: 40 / 800 = 5 %
    const t = ready(1000, [
      span(0, 200, TrackSurface.UNKNOWN),
      span(200, 240, TrackSurface.GRAVEL),
      span(240, 1000, TrackSurface.PAVED),
    ])
    expect(suggestSurfaceType([t])).toBe(SurfaceType.MIXED)
  })

  it('counts a track without its surface as unknown over its whole length', () => {
    const paved = ready(1000, [span(0, 1000, TrackSurface.PAVED)])
    const failed = ready(1000, []) // not READY with spans
    failed.surfaceState = TrackSurfaceState.UNAVAILABLE
    failed.surfaces = undefined
    expect(suggestSurfaceType([paved, failed])).toBeNull()
    const shortFailed = { ...failed, line: ready(250, []).line }
    expect(suggestSurfaceType([paved, shortFailed])).toBe(SurfaceType.ROAD)
  })
})
