import { describe, expect, it } from 'vitest'
import { RelativeWind } from '@/api/dto'
import type { WeatherCheckpointDto, WindSegmentDto } from '@/api/dto'
import { conditions, weatherLeg } from '@/test/weatherFixtures'
import {
  checkpointSpacing,
  daylightVerdict,
  durationParts,
  phaseAnchor,
  phaseColumns,
  phaseAt,
  phaseOfCheckpoint,
  phaseStats,
  rainVerdict,
  temperaturePolylines,
  temperatureVerdict,
  tickPositions,
  windPhases,
  windVerdict,
} from './routeWeather'

const km = (n: number) => n * 1000

/** Points every 15 km, a passage every 30 min from 07:00 UTC, temperatures and rain chances given. */
function points(
  temperatures: (number | undefined)[],
  rain: (number | undefined)[] = [],
  gusts: (number | undefined)[] = []
): WeatherCheckpointDto[] {
  return temperatures.map((temperature, i) => ({
    index: i,
    kind: i === 0 ? 'START' : i === temperatures.length - 1 ? 'FINISH' : 'EN_ROUTE',
    distance: km(15 * i),
    time: new Date(Date.UTC(2026, 9, 18, 7, 30 * i)).toISOString(),
    weather:
      temperature === undefined
        ? undefined
        : {
            ...conditions,
            temperature,
            apparentTemperature: temperature - 2,
            precipitationProbability: rain[i],
            wind: { speed: 10 + i, gusts: gusts[i], direction: 0, compass: 'N' as const },
          },
  }))
}

const segment = (from: number, to: number, relativeWind: string): WindSegmentDto => ({
  fromDistance: km(from),
  toDistance: km(to),
  relativeWind: relativeWind as RelativeWind,
  headwind: 0,
})

// The shape of the real « Raymond Ride 300 »: across, face, across, face, across, then behind.
const raymondSegments = [
  segment(0, 15, 'CROSS'),
  segment(15, 30, 'HEAD'),
  segment(30, 45, 'HEAD'),
  segment(45, 60, 'CROSS'),
  segment(60, 90, 'CROSS'),
  segment(90, 150, 'HEAD'),
  segment(150, 180, 'CROSS'),
  segment(180, 300, 'TAIL'),
]
const raymondPoints = points(Array.from({ length: 21 }, (_, i) => 7 + (i % 10)))

describe('windPhases', () => {
  it('merges consecutive stretches of one wind, bounded by their checkpoints', () => {
    const phases = windPhases(raymondSegments, raymondPoints)
    expect(phases.map((p) => [p.relativeWind, p.fromDistance / 1000, p.toDistance / 1000])).toEqual(
      [
        ['CROSS', 0, 15],
        ['HEAD', 15, 45],
        ['CROSS', 45, 90],
        ['HEAD', 90, 150],
        ['CROSS', 150, 180],
        ['TAIL', 180, 300],
      ]
    )
    expect(phases[1]).toMatchObject({ firstCheckpoint: 1, lastCheckpoint: 3, checkpoints: [1, 2] })
    // The finish belongs to the last phase.
    expect(phases[5].checkpoints).toEqual([12, 13, 14, 15, 16, 17, 18, 19, 20])
  })

  it('breaks a phase over a stretch of an unknown wind, and drops empty ones', () => {
    const phases = windPhases(
      [
        segment(0, 15, 'HEAD'),
        segment(15, 30, 'SIDEWAYS'),
        segment(30, 45, 'HEAD'),
        segment(45, 45, 'TAIL'),
      ],
      points([1, 2, 3, 4])
    )
    expect(phases.map((p) => [p.relativeWind, p.fromDistance / 1000])).toEqual([
      ['HEAD', 0],
      ['HEAD', 30],
    ])
    expect(windPhases(raymondSegments, [])).toEqual([])
  })

  it('finds the phase of a distance and of a checkpoint', () => {
    const phases = windPhases(raymondSegments, raymondPoints)
    expect(phaseAt(phases, km(15))).toBe(1)
    expect(phaseAt(phases, km(300))).toBe(5)
    expect(phaseAt(phases, km(400))).toBeUndefined()
    expect(phaseOfCheckpoint(phases, 7)).toBe(3)
  })

  it('leaves a phase shorter than the point spacing without points of its own', () => {
    const cps = points([10, 14, 12])
    const phases = windPhases(
      [segment(0, 20, 'HEAD'), segment(20, 22, 'CROSS'), segment(22, 30, 'TAIL')],
      cps
    )
    // km 15 belongs to the face phase only; the short across phase merely anchors on it.
    expect(phases[0].checkpoints).toEqual([0, 1])
    expect(phases[1]).toMatchObject({ firstCheckpoint: 1, lastCheckpoint: 1, checkpoints: [] })
    expect(phases[2].checkpoints).toEqual([2])
    expect(phaseOfCheckpoint(phases, 1)).toBe(0)
    expect(phaseAnchor(phases[1])).toBe(1)
    expect(phaseAnchor(phases[2])).toBe(2)
    expect(phaseStats(phases[1], cps)).toEqual({
      windMin: undefined,
      windMax: undefined,
      gustsMax: undefined,
      rainMax: undefined,
      temperatureMin: undefined,
      temperatureMax: undefined,
    })
  })
})

describe('phaseColumns', () => {
  it('puts each phase above its own points, in half-columns', () => {
    const spans = phaseColumns(windPhases(raymondSegments, raymondPoints))
    // 21 points → 42 half-columns, covered end to end with no overlap.
    expect(spans).toEqual([
      { start: 0, end: 2 },
      { start: 2, end: 6 },
      { start: 6, end: 12 },
      { start: 12, end: 20 },
      { start: 20, end: 24 },
      { start: 24, end: 42 },
    ])
  })

  it('gives a phase without points the last half of the phase before it', () => {
    const cps = points([10, 14, 12])
    const phases = windPhases(
      [segment(0, 20, 'HEAD'), segment(20, 22, 'CROSS'), segment(22, 30, 'TAIL')],
      cps
    )
    expect(phaseColumns(phases)).toEqual([
      { start: 0, end: 3 },
      { start: 3, end: 4 },
      { start: 4, end: 6 },
    ])
  })

  it('sums what the points of a phase forecast', () => {
    const cps = points([10, 14, 12], [0, 20, 5], [25, 32, undefined])
    const [phase] = windPhases([segment(0, 30, 'HEAD')], cps)
    expect(phaseStats(phase, cps)).toEqual({
      windMin: 10,
      windMax: 12,
      gustsMax: 32,
      rainMax: 20,
      temperatureMin: 10,
      temperatureMax: 14,
    })
  })
})

describe('temperatureVerdict', () => {
  it('spans the departure and every point, and names the warmest point', () => {
    const verdict = temperatureVerdict(
      { ...conditions, temperature: 8, apparentTemperature: 5 },
      points([6.7, 12, 16, undefined, 15])
    )
    expect(verdict).toEqual({
      min: 6.7,
      max: 16,
      start: { temperature: 8, apparentTemperature: 5 },
      warmest: 2,
    })
  })

  it("falls back to the first point's start, and says nothing without any temperature", () => {
    expect(temperatureVerdict(undefined, points([9, 11]))?.start).toEqual({
      temperature: 9,
      apparentTemperature: 7,
    })
    expect(temperatureVerdict(undefined, points([undefined]))).toBeUndefined()
  })
})

describe('rainVerdict', () => {
  it('gives the alert when the leg has one', () => {
    const alert = { probability: 60, time: '2026-10-18T12:30:00Z', condition: 'RAIN' as const }
    expect(rainVerdict(weatherLeg('g', { rainAlert: alert }))).toEqual({ kind: 'alert', alert })
  })

  it('gives the highest chance and the window of the points reaching it', () => {
    const leg = weatherLeg('g', { checkpoints: points([1, 2, 3, 4, 5], [0, 13, 9, 13, 3]) })
    expect(rainVerdict(leg)).toEqual({ kind: 'dry', max: 13, first: 1, last: 3 })
  })

  it('says dry, without a window, when every chance is 0 or unknown', () => {
    expect(rainVerdict(weatherLeg('g', { checkpoints: points([1, 2], [0, 0]) }))).toEqual({
      kind: 'dry',
      max: 0,
    })
    expect(rainVerdict(weatherLeg('g', { checkpoints: points([1, 2]) }))).toEqual({
      kind: 'dry',
      max: undefined,
    })
  })
})

describe('windVerdict', () => {
  it('reads the dominant wind of each half, face until the last face phase, tail after', () => {
    const leg = weatherLeg('g', {
      distance: km(300),
      checkpoints: points(
        Array.from({ length: 21 }, () => 10),
        [],
        Array.from({ length: 21 }, (_, i) => (i === 7 ? 32 : 20))
      ),
      segments: raymondSegments,
      windExposure: { head: km(90), cross: km(90), tail: km(120) },
    })
    const verdict = windVerdict(leg, windPhases(leg.segments, leg.checkpoints))
    expect(verdict).toEqual({
      firstHalf: RelativeWind.HEAD,
      secondHalf: RelativeWind.TAIL,
      sequential: true,
      head: { until: km(150), gusts: 32, distance: km(90) },
      tail: { from: km(180), distance: km(120) },
    })
  })

  it('is not sequential when a face phase follows a tail one', () => {
    const leg = weatherLeg('g', {
      distance: km(45),
      checkpoints: points([1, 2, 3, 4]),
      segments: [segment(0, 15, 'TAIL'), segment(15, 45, 'HEAD')],
      windExposure: { head: km(30), cross: 0, tail: km(15) },
    })
    const verdict = windVerdict(leg, windPhases(leg.segments, leg.checkpoints))
    expect(verdict).toMatchObject({ sequential: false, firstHalf: 'TAIL', secondHalf: 'HEAD' })
  })

  it('says nothing without any known stretch', () => {
    const leg = weatherLeg('g', { segments: [] })
    expect(windVerdict(leg, [])).toBeUndefined()
  })
})

describe('daylightVerdict', () => {
  it('gives the margin before sunset, rounded to the minute', () => {
    expect(
      daylightVerdict(
        '2026-10-18T06:30:00Z',
        '2026-10-18T16:44:43.880Z',
        '2026-10-18T06:28:38Z',
        '2026-10-18T17:13:22Z'
      )
    ).toEqual({ marginMinutes: 29, startsBeforeSunrise: false })
  })

  it('goes negative after sunset, and flags a start before sunrise', () => {
    expect(
      daylightVerdict(
        '2026-10-18T06:00:00Z',
        '2026-10-18T17:53:22Z',
        '2026-10-18T06:28:38Z',
        '2026-10-18T17:13:22Z'
      )
    ).toEqual({ marginMinutes: -40, startsBeforeSunrise: true })
  })

  it('says nothing without a sunset', () => {
    expect(
      daylightVerdict('2026-10-18T06:00:00Z', '2026-10-18T10:00:00Z', undefined, undefined)
    ).toBeUndefined()
  })

  it('splits a duration in hours and minutes', () => {
    expect(durationParts(29)).toEqual({ hours: 0, minutes: 29 })
    expect(durationParts(-65)).toEqual({ hours: 1, minutes: 5 })
  })
})

describe('drawing', () => {
  it('draws the temperature curve at the column centres, breaking over a gap', () => {
    expect(temperaturePolylines([10, 20, undefined, 15, 10])).toEqual([
      '10,90 30,10',
      '70,50 90,90',
    ])
    expect(temperaturePolylines([12, 12])).toEqual(['25,50 75,50'])
    expect(temperaturePolylines([undefined, 12, undefined])).toEqual([])
    expect(temperaturePolylines([])).toEqual([])
  })

  it('spreads up to five ticks from the first point to the last', () => {
    expect(tickPositions(22)).toEqual([0, 5, 11, 16, 21])
    expect(tickPositions(3)).toEqual([0, 1, 2])
    expect(tickPositions(0)).toEqual([])
  })

  it('reads the usual spacing of the points, the shorter last stretch aside', () => {
    const cps = points([1, 2, 3, 4])
    cps[3] = { ...cps[3], distance: km(52) }
    expect(checkpointSpacing(cps)).toBe(km(15))
    expect(checkpointSpacing(cps.slice(0, 1))).toBeUndefined()
  })
})
