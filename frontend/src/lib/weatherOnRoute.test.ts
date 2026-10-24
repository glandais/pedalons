import { describe, expect, it } from 'vitest'
import { createTheme, DEFAULT_THEME, mergeMantineTheme } from '@mantine/core'
import { RelativeWind, WeatherStatus, type TrackDto, type WindSegmentDto } from '@/api/dto'
import { windPhases } from '@/components/weather/windPhases'
import { routeLeg, weatherLeg } from '@/test/weatherFixtures'
import {
  attributionHtml,
  chainedDistances,
  checkpointPoint,
  hasWindForecast,
  mapCheckpoints,
  mapWindRotation,
  pointWinds,
  relativeWindStrokeColors,
  windShares,
} from './weatherOnRoute'

/** A northbound track of `km` km, a point every `step` metres, its own distance from `startDist`. */
function track(km: number, step: number, fromLat: number, startDist = 0): TrackDto {
  const n = Math.round((km * 1000) / step)
  return {
    line: {
      type: 'LineString',
      coordinates: Array.from({ length: n + 1 }, (_, i) => [
        5,
        fromLat + (i * step) / 111_195,
        300,
        startDist + i * step,
      ]),
    },
    climbs: [],
  } as unknown as TrackDto
}

function segment(from: number, to: number, relativeWind: string): WindSegmentDto {
  return { fromDistance: from, toDistance: to, relativeWind, headwind: 0 } as WindSegmentDto
}

/** Phases from bare segments, with a checkpoint at every boundary (what the API sends). */
function phasesOf(segments: WindSegmentDto[]) {
  const bounds = [...new Set(segments.flatMap((s) => [s.fromDistance, s.toDistance]))]
  const checkpoints = bounds.map((distance, index) => ({ index, distance }))
  return windPhases(segments, checkpoints as Parameters<typeof windPhases>[1])
}

describe('chainedDistances', () => {
  it('chains two tracks whose own distance restarts at 0, without the gap between them', () => {
    // RouteSampleLookupTest's case: two 20 km tracks, the second starting 50 km further north.
    const distances = chainedDistances([track(20, 5_000, 45), track(20, 5_000, 45.5)])
    expect(distances).toEqual([
      [0, 5_000, 10_000, 15_000, 20_000],
      [20_000, 25_000, 30_000, 35_000, 40_000],
    ])
  })

  it('starts a track at its first point, whatever its own distance starts from', () => {
    expect(chainedDistances([track(1, 500, 45, 300)])).toEqual([[0, 500, 1_000]])
  })

  it('never goes backwards, and leaves an empty track empty', () => {
    const backwards = track(1, 500, 45)
    backwards.line.coordinates[1][3] = -100
    const empty = { line: { type: 'LineString', coordinates: [] } } as unknown as TrackDto
    expect(chainedDistances([backwards, empty, track(1, 1_000, 46)])).toEqual([
      [0, 0, 1_000],
      [],
      [1_000, 2_000],
    ])
  })
})

describe('pointWinds', () => {
  it('reads the second track on the chained measure, not on its own', () => {
    // Head on the first 20 km, tail on the next 20: the second track is all tail, though its own
    // distances (0 → 20 km) fall in the head stretch.
    const phases = phasesOf([
      segment(0, 20_000, RelativeWind.HEAD),
      segment(20_000, 40_000, RelativeWind.TAIL),
    ])
    const winds = pointWinds([track(20, 5_000, 45), track(20, 5_000, 45.5)], phases)
    expect(winds[0]).toEqual(Array(5).fill(RelativeWind.HEAD))
    expect(winds[1]).toEqual(Array(5).fill(RelativeWind.TAIL))
  })

  it('colours each segment by its midpoint, the last point repeating the one before', () => {
    // Stretches change at 15 km, inside the segment 10 → 20 km whose midpoint (15 km) is the
    // boundary: it belongs to the stretch that starts there.
    const phases = phasesOf([
      segment(0, 15_000, RelativeWind.CROSS),
      segment(15_000, 30_000, RelativeWind.HEAD),
    ])
    const winds = pointWinds([track(30, 10_000, 45)], phases)
    expect(winds[0]).toEqual([
      RelativeWind.CROSS,
      RelativeWind.HEAD,
      RelativeWind.HEAD,
      RelativeWind.HEAD,
    ])
  })

  it('leaves a point no known stretch covers without a wind — never the grey of a cross wind', () => {
    const phases = phasesOf([
      segment(0, 10_000, RelativeWind.TAIL),
      segment(10_000, 20_000, 'SWIRL'),
      segment(20_000, 30_000, RelativeWind.HEAD),
    ])
    const winds = pointWinds([track(40, 5_000, 45)], phases)
    expect(winds[0]).toEqual([
      RelativeWind.TAIL,
      RelativeWind.TAIL,
      undefined,
      undefined,
      RelativeWind.HEAD,
      RelativeWind.HEAD,
      // Beyond the last stretch (the route is longer than the forecast)
      undefined,
      undefined,
      undefined,
    ])
  })

  it('is all undefined without phases', () => {
    expect(pointWinds([track(1, 500, 45)], [])).toEqual([[undefined, undefined, undefined]])
  })
})

describe('windShares', () => {
  it('lists with, across and against the wind in that order, a kind never met left out', () => {
    expect(windShares({ windExposure: { head: 40_000, cross: 0, tail: 32_000 } })).toEqual([
      { relativeWind: RelativeWind.TAIL, length: 32_000 },
      { relativeWind: RelativeWind.HEAD, length: 40_000 },
    ])
  })
})

describe('hasWindForecast', () => {
  it('offers the wind for OK and STALE legs whose checkpoints carry weather', () => {
    expect(hasWindForecast(routeLeg())).toBe(true)
    expect(hasWindForecast(routeLeg({ status: WeatherStatus.STALE }))).toBe(true)
  })

  it('offers nothing without a forecast', () => {
    expect(hasWindForecast(undefined)).toBe(false)
    expect(hasWindForecast(weatherLeg('g1', { status: WeatherStatus.NOT_YET_AVAILABLE }))).toBe(
      false
    )
    expect(hasWindForecast(weatherLeg('g1', { status: WeatherStatus.NO_LOCATION }))).toBe(false)
    const bare = weatherLeg('g1')
    expect(
      hasWindForecast({
        ...bare,
        checkpoints: bare.checkpoints.map((c) => ({ ...c, weather: undefined })),
      })
    ).toBe(false)
  })
})

describe('relativeWindStrokeColors', () => {
  it('takes shade 6 of the generated families', () => {
    const theme = mergeMantineTheme(DEFAULT_THEME, createTheme({}))
    expect(relativeWindStrokeColors(theme)).toEqual({
      TAIL: theme.colors.teal[6],
      CROSS: theme.colors.gray[6],
      HEAD: theme.colors.orange[6],
    })
  })
})

describe('attributionHtml', () => {
  it('links the credit, escaped', () => {
    expect(attributionHtml({ name: 'Open-Meteo.com', url: 'https://open-meteo.com/' })).toBe(
      '<a href="https://open-meteo.com/" target="_blank" rel="noopener noreferrer">Open-Meteo.com</a>'
    )
    expect(attributionHtml({ name: '<b>x</b>', url: 'javascript:alert(1)' })).toBe(
      '&lt;b&gt;x&lt;/b&gt;'
    )
  })
})

describe('checkpointPoint (WEB-116)', () => {
  // RouteSampleLookupTest's case: two 20 km tracks, the second 50 km further north, each one's own
  // distance restarting at 0.
  const tracks = [track(20, 5_000, 45), track(20, 5_000, 45.5)]
  const second = tracks[1].line.coordinates

  it('places a point of the second track by the chained distance, without the gap', () => {
    // 25 km along the route is the second point of the second track, not the first track's end
    expect(checkpointPoint(tracks, 25_000)).toEqual([second[1][0], second[1][1]])
    // The join: the first track's end (20 km) comes first
    const first = tracks[0].line.coordinates
    expect(checkpointPoint(tracks, 20_000)).toEqual([first[4][0], first[4][1]])
    expect(checkpointPoint(tracks, 0)).toEqual([first[0][0], first[0][1]])
  })

  it("takes the API's rounding within half a metre, and the last point past the end", () => {
    expect(checkpointPoint(tracks, 25_000.4)).toEqual([second[1][0], second[1][1]])
    expect(checkpointPoint(tracks, 99_000)).toEqual([second[4][0], second[4][1]])
  })

  it('places nothing without a point', () => {
    const empty = { line: { type: 'LineString', coordinates: [] } } as unknown as TrackDto
    expect(checkpointPoint([empty], 0)).toBeUndefined()
  })
})

describe('mapCheckpoints (WEB-116)', () => {
  it('keeps only the checkpoints with their weather, each at its place', () => {
    const tracks = [track(45, 15_000, 45), track(45, 15_000, 46)]
    const leg = routeLeg()
    leg.checkpoints[2] = { ...leg.checkpoints[2], weather: undefined }
    const placed = mapCheckpoints(tracks, leg.checkpoints)
    expect(placed.map((p) => p.checkpoint.index)).toEqual([0, 1, 3, 4, 5, 6])
    // km 60 is the second track's second point (km 45 + 15)
    const km60 = placed.find((p) => p.checkpoint.index === 4)!
    expect([km60.longitude, km60.latitude]).toEqual(tracks[1].line.coordinates[1].slice(0, 2))
  })
})

describe('mapWindRotation', () => {
  it('points where the wind blows to, north up', () => {
    expect(mapWindRotation(0)).toBe(180) // from the north: towards the south
    expect(mapWindRotation(225)).toBe(45) // from the south-west: towards the north-east
    expect(mapWindRotation(180)).toBe(0)
  })

  it('takes the bearing off on a rotated map, the marker staying upright', () => {
    expect(mapWindRotation(0, 90)).toBe(90) // towards the south, the map turned east-up
    expect(mapWindRotation(180, 90)).toBe(270)
    expect(mapWindRotation(225, 200)).toBe(205)
    expect(mapWindRotation(180, -30)).toBe(30)
  })
})
