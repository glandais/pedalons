import { RelativeWind } from '@/api/dto'
import type {
  Instant,
  WeatherCheckpointDto,
  WeatherConditionsDto,
  WeatherLegDto,
  WeatherRainAlertDto,
  WindSegmentDto,
} from '@/api/dto'
import { isKnownRelativeWind } from './weatherDisplay'

/**
 * The computations behind a group's « Météo du parcours » (`GroupWeatherSection`): the wind merged
 * into phases, the four verdicts, the temperature curve. Pure — no words, no units: the API speaks
 * metres, °C, km/h and instants, the components translate.
 *
 * Positions are indexes into `leg.checkpoints` (array order, start to finish), not
 * `WeatherCheckpointDto.index`, so a caller can index the array directly.
 */

/** A distance closer than this to a phase boundary is on it (the API rounds to the metre). */
const BOUNDARY_TOLERANCE = 1

/** Arrow angles drawn for a relative wind as a whole: pushing (0), across (90), in the face (180). */
export const RELATIVE_WIND_ANGLE: Record<RelativeWind, number> = {
  [RelativeWind.TAIL]: 0,
  [RelativeWind.CROSS]: 90,
  [RelativeWind.HEAD]: 180,
}

export interface WindPhase {
  relativeWind: RelativeWind
  fromDistance: number
  toDistance: number
  /** The checkpoint nearest the phase's start: its passage opens the phase. */
  firstCheckpoint: number
  /** The checkpoint nearest the phase's end: its passage closes the phase. */
  lastCheckpoint: number
  /** The checkpoints ridden in the phase — from its start, up to its end excluded (the finish
   * belongs to the last phase). Empty for a phase shorter than the spacing of the points: its
   * `firstCheckpoint` then lies in a neighbouring phase, and only anchors its selection and times. */
  checkpoints: number[]
}

function nearestCheckpoint(checkpoints: WeatherCheckpointDto[], distance: number): number {
  let best = 0
  for (let i = 1; i < checkpoints.length; i++) {
    if (
      Math.abs(checkpoints[i].distance - distance) < Math.abs(checkpoints[best].distance - distance)
    )
      best = i
  }
  return best
}

/**
 * The wind stretches merged into consecutive phases of one relative wind: « face from 15 to 45,
 * across to 90 ». A stretch of a kind this build does not know, or an empty one, is dropped — and
 * breaks a phase, so a merged phase never paints over a gap.
 */
export function windPhases(
  segments: WindSegmentDto[],
  checkpoints: WeatherCheckpointDto[]
): WindPhase[] {
  const merged: { relativeWind: RelativeWind; fromDistance: number; toDistance: number }[] = []
  let previousKept = false
  for (const segment of segments) {
    if (!isKnownRelativeWind(segment.relativeWind) || segment.toDistance <= segment.fromDistance) {
      previousKept = false
      continue
    }
    const last = merged[merged.length - 1]
    if (
      previousKept &&
      last.relativeWind === segment.relativeWind &&
      segment.fromDistance - last.toDistance <= BOUNDARY_TOLERANCE
    ) {
      last.toDistance = segment.toDistance
    } else {
      merged.push({
        relativeWind: segment.relativeWind,
        fromDistance: segment.fromDistance,
        toDistance: segment.toDistance,
      })
    }
    previousKept = true
  }
  if (checkpoints.length === 0) return []

  const phases: WindPhase[] = merged.map((phase) => ({
    ...phase,
    firstCheckpoint: nearestCheckpoint(checkpoints, phase.fromDistance),
    lastCheckpoint: nearestCheckpoint(checkpoints, phase.toDistance),
    checkpoints: [],
  }))
  checkpoints.forEach((checkpoint, position) => {
    const phase = phaseAt(phases, checkpoint.distance)
    if (phase !== undefined) phases[phase].checkpoints.push(position)
  })
  return phases
}

/**
 * The phase ridden at `distance`: the one it starts or lies within; at the very end of a phase
 * with nothing after it (the finish), that phase.
 */
export function phaseAt(phases: WindPhase[], distance: number): number | undefined {
  const within = phases.findIndex(
    (phase) =>
      distance >= phase.fromDistance - BOUNDARY_TOLERANCE &&
      distance < phase.toDistance - BOUNDARY_TOLERANCE
  )
  if (within >= 0) return within
  const ending = phases.findIndex(
    (phase) => Math.abs(distance - phase.toDistance) <= BOUNDARY_TOLERANCE
  )
  return ending >= 0 ? ending : undefined
}

/** Where a phase sits in the table's phase row, in half-columns: `[start, end)`, end exclusive. */
export interface PhaseSpan {
  start: number
  end: number
}

/**
 * The phases laid out over the table's columns, so that each one sits exactly above its own
 * points — the row reads with the hours and the wind band under it, never beside them. The row is
 * a grid of two half-columns per point: a phase with points spans their whole columns; one shorter
 * than the spacing of the points (no point of its own) takes the last half-column of the phase
 * before it, the next phase's first half when it opens the leg. A phase that finds no room gets
 * `undefined` and is not drawn there (the phone list and the detail panel still name it).
 */
export function phaseColumns(phases: WindPhase[]): (PhaseSpan | undefined)[] {
  const spans: (PhaseSpan | undefined)[] = phases.map((phase) =>
    phase.checkpoints.length === 0
      ? undefined
      : {
          start: 2 * phase.checkpoints[0],
          end: 2 * (phase.checkpoints[phase.checkpoints.length - 1] + 1),
        }
  )
  phases.forEach((phase, index) => {
    if (phase.checkpoints.length > 0) return
    const before = spans
      .slice(0, index)
      .reverse()
      .find((span) => span !== undefined)
    if (before && before.end - before.start >= 2) {
      before.end -= 1
      spans[index] = { start: before.end, end: before.end + 1 }
      return
    }
    const after = spans.slice(index + 1).find((span) => span !== undefined)
    if (!before && after && after.end - after.start >= 2) {
      spans[index] = { start: after.start, end: after.start + 1 }
      after.start += 1
    }
  })
  return spans
}

/** The point a click on a phase selects: its first own point, else the one nearest its start. */
export function phaseAnchor(phase: WindPhase): number {
  return phase.checkpoints[0] ?? phase.firstCheckpoint
}

/** The phase a checkpoint belongs to, by position (never a phase it only anchors). */
export function phaseOfCheckpoint(phases: WindPhase[], position: number): number | undefined {
  const index = phases.findIndex((phase) => phase.checkpoints.includes(position))
  return index >= 0 ? index : undefined
}

export interface PhaseStats {
  windMin?: number
  windMax?: number
  gustsMax?: number
  rainMax?: number
  temperatureMin?: number
  temperatureMax?: number
}

function maxOf(values: (number | undefined)[]): number | undefined {
  const known = values.filter((v): v is number => v !== undefined)
  return known.length ? Math.max(...known) : undefined
}

function minOf(values: (number | undefined)[]): number | undefined {
  const known = values.filter((v): v is number => v !== undefined)
  return known.length ? Math.min(...known) : undefined
}

/** What the points of a phase forecast: wind range, highest gust, highest chance of rain, temperatures. */
export function phaseStats(phase: WindPhase, checkpoints: WeatherCheckpointDto[]): PhaseStats {
  const weathers = phase.checkpoints
    .map((position) => checkpoints[position]?.weather)
    .filter((w): w is WeatherConditionsDto => !!w)
  return {
    windMin: minOf(weathers.map((w) => w.wind.speed)),
    windMax: maxOf(weathers.map((w) => w.wind.speed)),
    gustsMax: maxOf(weathers.map((w) => w.wind.gusts)),
    rainMax: maxOf(weathers.map((w) => w.precipitationProbability)),
    temperatureMin: minOf(weathers.map((w) => w.temperature)),
    temperatureMax: maxOf(weathers.map((w) => w.temperature)),
  }
}

// ---------------------------------------------------------------------------------------------
// Verdicts
// ---------------------------------------------------------------------------------------------

export interface TemperatureVerdict {
  min: number
  max: number
  /** The departure's (the meeting point, else the first point's), when known. */
  start?: { temperature: number; apparentTemperature: number }
  /** Position of the warmest point, the first of them on a tie. */
  warmest?: number
}

/** Coldest and warmest over the departure and every point, the start's, and where it is warmest. */
export function temperatureVerdict(
  departure: WeatherConditionsDto | undefined,
  checkpoints: WeatherCheckpointDto[]
): TemperatureVerdict | undefined {
  const temperatures = checkpoints.map((c) => c.weather?.temperature)
  const all = [departure?.temperature, ...temperatures]
  const min = minOf(all)
  const max = maxOf(all)
  if (min === undefined || max === undefined) return undefined
  const warmestPoint = maxOf(temperatures)
  const startConditions = departure ?? checkpoints[0]?.weather
  return {
    min,
    max,
    start: startConditions && {
      temperature: startConditions.temperature,
      apparentTemperature: startConditions.apparentTemperature,
    },
    warmest: warmestPoint === undefined ? undefined : temperatures.indexOf(warmestPoint),
  }
}

export type RainVerdict =
  | { kind: 'alert'; alert: WeatherRainAlertDto }
  /** No alert: the highest chance and the first and last points reaching it (none when 0 or unknown). */
  | { kind: 'dry'; max?: number; first?: number; last?: number }

export function rainVerdict(leg: WeatherLegDto): RainVerdict {
  if (leg.rainAlert) return { kind: 'alert', alert: leg.rainAlert }
  const probabilities = leg.checkpoints.map((c) => c.weather?.precipitationProbability)
  const max = maxOf(probabilities)
  if (max === undefined || max <= 0) return { kind: 'dry', max }
  return {
    kind: 'dry',
    max,
    first: probabilities.indexOf(max),
    last: probabilities.lastIndexOf(max),
  }
}

/** The relative wind ridden longest between two distances, by the stretches overlapping them. */
function dominantBetween(
  segments: WindSegmentDto[],
  from: number,
  to: number
): RelativeWind | undefined {
  const lengths = new Map<RelativeWind, number>()
  for (const segment of segments) {
    if (!isKnownRelativeWind(segment.relativeWind)) continue
    const overlap = Math.min(segment.toDistance, to) - Math.max(segment.fromDistance, from)
    if (overlap > 0)
      lengths.set(segment.relativeWind, (lengths.get(segment.relativeWind) ?? 0) + overlap)
  }
  let best: RelativeWind | undefined
  // Ties go to the harder wind: face, then across, then behind.
  for (const kind of [RelativeWind.HEAD, RelativeWind.CROSS, RelativeWind.TAIL]) {
    const length = lengths.get(kind) ?? 0
    if (length > 0 && (best === undefined || length > (lengths.get(best) ?? 0))) best = kind
  }
  return best
}

export interface WindVerdict {
  /** Dominant over the first half of the leg's distance, then over the second. */
  firstHalf?: RelativeWind
  secondHalf?: RelativeWind
  /** Every face phase ends before the first tail phase starts: « face until X, tail after Y ». */
  sequential: boolean
  /** End of the last face phase, and the highest gust forecast in the face phases. */
  head?: { until: number; gusts?: number; distance: number }
  /** Start of the first tail phase. */
  tail?: { from: number; distance: number }
}

export function windVerdict(leg: WeatherLegDto, phases: WindPhase[]): WindVerdict | undefined {
  const length =
    leg.distance > 0 ? leg.distance : Math.max(0, ...leg.segments.map((s) => s.toDistance))
  const half = length / 2
  const firstHalf = dominantBetween(leg.segments, 0, half)
  const secondHalf = dominantBetween(leg.segments, half, length)
  if (!firstHalf && !secondHalf) return undefined

  const heads = phases.filter((p) => p.relativeWind === RelativeWind.HEAD)
  const tails = phases.filter((p) => p.relativeWind === RelativeWind.TAIL)
  const head = heads.length
    ? {
        until: Math.max(...heads.map((p) => p.toDistance)),
        gusts: maxOf(
          heads.flatMap((p) => p.checkpoints.map((c) => leg.checkpoints[c]?.weather?.wind.gusts))
        ),
        distance: leg.windExposure.head,
      }
    : undefined
  const tail = tails.length
    ? { from: Math.min(...tails.map((p) => p.fromDistance)), distance: leg.windExposure.tail }
    : undefined
  return {
    firstHalf,
    secondHalf,
    sequential: !!head && !!tail && head.until <= tail.from + BOUNDARY_TOLERANCE,
    head,
    tail,
  }
}

export interface DaylightVerdict {
  /** Sunset minus arrival, rounded to the minute: negative when arriving after sunset. */
  marginMinutes: number
  /** Whether the leg leaves before sunrise. */
  startsBeforeSunrise: boolean
}

/** Past this many minutes after sunset, the arrival is simply « de nuit ». */
export const NIGHT_AFTER_SUNSET_MINUTES = 60

export function daylightVerdict(
  startTime: Instant,
  arrivalTime: Instant,
  sunrise: Instant | undefined,
  sunset: Instant | undefined
): DaylightVerdict | undefined {
  if (!sunset) return undefined
  const sunsetMs = Date.parse(sunset)
  const arrivalMs = Date.parse(arrivalTime)
  if (Number.isNaN(sunsetMs) || Number.isNaN(arrivalMs)) return undefined
  const sunriseMs = sunrise ? Date.parse(sunrise) : NaN
  return {
    marginMinutes: Math.round((sunsetMs - arrivalMs) / 60_000) + 0,
    startsBeforeSunrise: !Number.isNaN(sunriseMs) && Date.parse(startTime) < sunriseMs,
  }
}

/** Minutes as whole hours and the minutes left: 29 → 0 h 29, 65 → 1 h 05. */
export function durationParts(totalMinutes: number): { hours: number; minutes: number } {
  const abs = Math.abs(Math.round(totalMinutes))
  return { hours: Math.floor(abs / 60), minutes: abs % 60 }
}

// ---------------------------------------------------------------------------------------------
// Drawing
// ---------------------------------------------------------------------------------------------

/**
 * The temperature curve as SVG polylines in a 100 × 100 viewBox, one point per column centre
 * (column i of n spans [i/n, (i+1)/n]). A point without forecast breaks the line, so a gap never
 * reads as a forecast. The warmest sits at 10, the coldest at 90; a flat series at 50.
 */
export function temperaturePolylines(temperatures: (number | undefined)[]): string[] {
  const n = temperatures.length
  const min = minOf(temperatures)
  const max = maxOf(temperatures)
  if (n === 0 || min === undefined || max === undefined) return []
  const y = (t: number) => (max === min ? 50 : 90 - ((t - min) / (max - min)) * 80)
  const lines: string[][] = []
  let current: string[] = []
  temperatures.forEach((t, i) => {
    if (t === undefined) {
      if (current.length) lines.push(current)
      current = []
      return
    }
    const x = ((i + 0.5) / n) * 100
    current.push(`${round2(x)},${round2(y(t))}`)
  })
  if (current.length) lines.push(current)
  return lines.filter((line) => line.length > 1).map((line) => line.join(' '))
}

function round2(value: number): number {
  return Math.round(value * 100) / 100
}

/** Up to `count` positions spread evenly from the first to the last of `n` — the strip's ticks. */
export function tickPositions(n: number, count = 5): number[] {
  if (n <= 0) return []
  if (n <= count) return Array.from({ length: n }, (_, i) => i)
  const positions = Array.from({ length: count }, (_, k) => Math.round((k * (n - 1)) / (count - 1)))
  return [...new Set(positions)]
}

/** The usual spacing of the points, metres: the median gap, the shorter last one aside. */
export function checkpointSpacing(checkpoints: WeatherCheckpointDto[]): number | undefined {
  const gaps = checkpoints
    .slice(1)
    .map((c, i) => c.distance - checkpoints[i].distance)
    .filter((gap) => gap > 0)
  if (gaps.length === 0) return undefined
  const regular = gaps.length > 2 ? gaps.slice(0, -1) : gaps
  const sorted = [...regular].sort((a, b) => a - b)
  return sorted[Math.floor(sorted.length / 2)]
}
