import { describe, expect, it } from 'vitest'
import type { RelativeWind, TrackDto } from '@/api/dto'
import { NEUTRAL_COLOR } from '@/components/map/mapUtils'
import { weatherLeg } from '@/test/weatherFixtures'
import { windTraceLines } from './routesMapWind'

const COLORS: Record<RelativeWind, string> = { HEAD: 'head', CROSS: 'cross', TAIL: 'tail' }

/** A straight track of `n + 1` points, 1 km apart, its 4th coordinate from `from` metres. */
const track = (lon: number, n: number, from = 0): TrackDto =>
  ({
    line: {
      type: 'LineString',
      coordinates: Array.from({ length: n + 1 }, (_, i) => [
        lon,
        45 + i * 0.009,
        100,
        from + i * 1000,
      ]),
    },
    climbs: [],
  }) as unknown as TrackDto

const colorsOf = (lines: GeoJSON.FeatureCollection<GeoJSON.LineString>) =>
  lines.features.map((f) => [f.properties?.color, f.geometry.coordinates.length])

describe('windTraceLines: a trip stage by its own wind (WEB-118)', () => {
  // Two stages of 20 km each, both measured from their own start: each leg's distances restart at 0
  const first = [track(5, 20)]
  const second = [track(6, 20)]
  const headAll = weatherLeg(undefined, {
    segments: [{ fromDistance: 0, toDistance: 20_000, relativeWind: 'HEAD', headwind: 10 }],
  })
  const tailThenCross = weatherLeg(undefined, {
    segments: [
      { fromDistance: 0, toDistance: 10_000, relativeWind: 'TAIL', headwind: -8 },
      { fromDistance: 10_000, toDistance: 20_000, relativeWind: 'CROSS', headwind: 0 },
    ],
  })

  it("colours each stage by its own leg, the second from its own start, not the trip's", () => {
    expect(colorsOf(windTraceLines(first, { leg: headAll, timezone: 'UTC' }, COLORS))).toEqual([
      ['head', 21],
    ])
    // Chained from the trip's start (20 km on), the second stage would read no wind at all
    expect(
      colorsOf(windTraceLines(second, { leg: tailThenCross, timezone: 'UTC' }, COLORS))
    ).toEqual([
      ['tail', 11],
      ['cross', 11],
    ])
  })

  it("chains a stage's own tracks without the gap between them (plan §3)", () => {
    // The stage's second track restarts its 4th coordinate at 0: it carries on from 10 km
    const twoTracks = [track(6, 10), track(6.1, 10)]
    expect(
      colorsOf(windTraceLines(twoTracks, { leg: tailThenCross, timezone: 'UTC' }, COLORS))
    ).toEqual([
      ['tail', 11],
      ['cross', 11],
    ])
  })

  it("draws a stage without a forecast in the line's default colour, never grey", () => {
    expect(colorsOf(windTraceLines(first, undefined, COLORS))).toEqual([[NEUTRAL_COLOR, 21]])
    expect(NEUTRAL_COLOR).not.toBe(COLORS.CROSS)
  })
})
