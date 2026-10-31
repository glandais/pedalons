import { describe, expect, it, vi } from 'vitest'
import { RelativeWind, type TrackDto } from '@/api/dto'
import { routeWind } from '@/hooks/useRouteWindColors'
import { weatherLeg } from '@/test/weatherFixtures'
import { NEUTRAL_COLOR } from '../map/mapUtils'
import type { Chart } from 'chart.js'
import {
  WIND_BAND_GAP,
  WIND_BAND_HEIGHT,
  windBandColors,
  windBandPlugin,
  windBandRuns,
} from './windBand'

const colors = {
  [RelativeWind.TAIL]: '#tail',
  [RelativeWind.CROSS]: '#cross',
  [RelativeWind.HEAD]: '#head',
}

/** A northbound track of `km` km, a point every 5 km, its own distance restarting at 0. */
function track(km: number, fromLat: number): TrackDto {
  const n = km / 5
  return {
    line: {
      type: 'LineString',
      coordinates: Array.from({ length: n + 1 }, (_, i) => [
        5,
        fromLat + (i * 5_000) / 111_195,
        300,
        i * 5_000,
      ]),
    },
    climbs: [],
  } as unknown as TrackDto
}

describe('windBandRuns', () => {
  it('merges the segments of one colour, each in the colour of the point it starts', () => {
    expect(windBandRuns([0, 10, 20, 30, 40], ['a', 'a', 'b', 'b', 'b'], [5])).toEqual([
      { from: 0, to: 20, color: 'a' },
      { from: 20, to: 40, color: 'b' },
    ])
  })

  it('never runs across two tracks, even of one colour, and skips a track of one point', () => {
    expect(
      windBandRuns([0, 10, 20, 0, 5, 0, 10], ['a', 'a', 'a', 'a', 'a', 'a', 'a'], [3, 1, 1, 2])
    ).toEqual([
      { from: 0, to: 20, color: 'a' },
      { from: 0, to: 10, color: 'a' },
    ])
  })
})

describe('windBandColors', () => {
  it('gives an unknown wind the neutral blue, never the grey of a cross wind', () => {
    const band = windBandColors({ winds: [RelativeWind.CROSS, undefined], colors }, 3)
    expect(band).toEqual(['#cross', NEUTRAL_COLOR, NEUTRAL_COLOR])
  })
})

describe('the band of a route of several tracks', () => {
  // Two 20 km tracks, the second 50 km further north; its own distance restarts at 0. Head wind
  // on the first 20 km of the chained measure, tail on the next 20 — the second track is all tail.
  const tracks = [track(20, 45), track(20, 45.5)]
  const leg = weatherLeg('g1', {
    checkpoints: [0, 20_000, 40_000].map((distance, index) => ({ index, distance })) as never,
    segments: [
      { fromDistance: 0, toDistance: 20_000, relativeWind: RelativeWind.HEAD, headwind: 10 },
      { fromDistance: 20_000, toDistance: 40_000, relativeWind: RelativeWind.TAIL, headwind: -10 },
    ],
  })
  const { lineColorAt, profileWind } = routeWind(tracks, leg, colors)
  // The profile's axis: the points laid one after the other, their own distance as is
  const xs = tracks.flatMap((t) => t.line.coordinates.map((p) => p[3]))
  const sizes = tracks.map((t) => t.line.coordinates.length)

  it('colours every point of the profile as the map colours it', () => {
    const band = windBandColors(profileWind, xs.length)
    const line = tracks.flatMap((t, ti) => t.line.coordinates.map((_, i) => lineColorAt(ti, i)))
    expect(band).toEqual(line)
  })

  it("lays the second track's tail wind on that track's own points of the profile", () => {
    expect(windBandRuns(xs, windBandColors(profileWind, xs.length), sizes)).toEqual([
      { from: 0, to: 20_000, color: '#head' },
      { from: 0, to: 20_000, color: '#tail' },
    ])
  })
})

describe('windBandPlugin', () => {
  function chart(runs: { from: number; to: number; color: string }[], crosshair?: { x: number }) {
    const fills: { color: string; x: number; y: number; w: number; h: number }[] = []
    const ctx = {
      fillStyle: '',
      save: vi.fn(),
      restore: vi.fn(),
      beginPath: vi.fn(),
      rect: vi.fn(),
      clip: vi.fn(),
      moveTo: vi.fn(),
      lineTo: vi.fn(),
      stroke: vi.fn(),
      fillRect(x: number, y: number, w: number, h: number) {
        fills.push({ color: this.fillStyle, x, y, w, h })
      },
    }
    const c = {
      ctx,
      chartArea: { left: 0, right: 100, top: 0, bottom: 80 },
      // 1 px per 10 m, the window 0 → 1 km
      scales: { x: { getPixelForValue: (v: number) => v / 10 } },
      options: { plugins: { windBand: { runs } } },
      crosshair,
    }
    const draw = windBandPlugin.afterDatasetsDraw as unknown as (chart: Chart<'line'>) => void
    draw(c as unknown as Chart<'line'>)
    return { fills, ctx }
  }

  it('draws each stretch under the plot at its distances, what lies out of the window skipped', () => {
    const { fills, ctx } = chart(
      [
        { from: 0, to: 500, color: '#head' },
        { from: 500, to: 1000, color: '#tail' },
        { from: 2000, to: 3000, color: '#cross' },
      ],
      { x: 30 }
    )
    const top = 80 + WIND_BAND_GAP
    expect(fills).toEqual([
      { color: '#head', x: -0.5, y: top, w: 51, h: WIND_BAND_HEIGHT },
      { color: '#tail', x: 49.5, y: top, w: 51, h: WIND_BAND_HEIGHT },
    ])
    expect(ctx.rect).toHaveBeenCalledWith(0, top, 100, WIND_BAND_HEIGHT)
    // The cursor carried across the band
    expect(ctx.moveTo).toHaveBeenCalledWith(30, top)
  })

  it('draws nothing without stretches', () => {
    expect(chart([]).fills).toEqual([])
  })
})
