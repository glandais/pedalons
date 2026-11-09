// The wind on a group's route map (ledger WEB-115, plan docs/plans/archive/2026-10-24-weather-on-map.md):
// the leg's wind stretches, which the API places by distance only, laid on the track the page
// already holds. Pure and free of the map chunk, so the page and its tests read it without
// MapLibre.
//
// The trap (plan §3): the API measures its checkpoints and stretches along the route's tracks laid
// end to end *without* the gap between the end of one track and the start of the next
// (`RouteSampleLookup.chain`), while the 4th coordinate of a track restarts at 0 on each track.
// `chainedDistances` rebuilds the API's measure; nothing here measures the jump between tracks.
import type { MantineTheme } from '@mantine/core'
import { RelativeWind, WeatherCheckpointKind } from '@/api/dto'
import type {
  TrackDto,
  WeatherAttributionDto,
  WeatherCheckpointDto,
  WeatherConditionsDto,
  WeatherLegDto,
} from '@/api/dto'
import { RELATIVE_WIND_COLORS } from '@/lib/badgeColors.generated'
import { hasForecast } from '@/components/weather/weatherDisplay'
import { phaseAt, type WindPhase } from '@/components/weather/windPhases'

type Tracks = Pick<TrackDto, 'line'>[]

/**
 * The distance of every point along the whole route, as the API measures it: each track starts
 * where the previous one ended, the gap between them counting for nothing, and never backwards (a
 * sanitised import is not something to bet on). One array per track, empty for an empty track.
 */
export function chainedDistances(tracks: Tracks): number[][] {
  let offset = 0
  return tracks.map((track) => {
    const points = track.line.coordinates
    if (points.length === 0) return []
    const first = points[0][3] ?? 0
    let last = offset
    const distances = points.map((point) => {
      last = Math.max(last, offset + (point[3] ?? 0) - first)
      return last
    })
    offset = last
    return distances
  })
}

/**
 * The relative wind of every point (one array per track, same indexes as the geometry): that of
 * the segment the point starts, read at its midpoint on the chained measure; the last point of a
 * track repeats the previous one. Undefined where no known stretch covers the point — the caller
 * then keeps the track's default colour, never the grey, which says « across ».
 */
export function pointWinds(tracks: Tracks, phases: WindPhase[]): (RelativeWind | undefined)[][] {
  const windAt = (distance: number) => {
    const phase = phaseAt(phases, distance)
    return phase === undefined ? undefined : phases[phase].relativeWind
  }
  return chainedDistances(tracks).map((distances) =>
    distances.map((distance, i) => {
      if (i < distances.length - 1) return windAt((distance + distances[i + 1]) / 2)
      // The last point opens no segment: it takes the colour of the one it ends.
      return i > 0 ? windAt((distances[i - 1] + distance) / 2) : windAt(distance)
    })
  )
}

/**
 * Where a point of the leg (a checkpoint, the rain alert) stands on the map, from its distance
 * alone (ledger WEB-116, plan §5 palier 2): the first vertex whose chained distance reaches it,
 * within half a metre — the API rounds its distances, and a checkpoint falls on a vertex. Past the
 * end, the last vertex. Undefined without a single point. `chained` is `chainedDistances(tracks)`,
 * passed in by a caller placing several points so the whole geometry is measured once.
 */
export function checkpointPoint(
  tracks: Tracks,
  distance: number,
  chained: number[][] = chainedDistances(tracks)
): [number, number] | undefined {
  let last: number[] | undefined
  for (let t = 0; t < tracks.length; t++) {
    const points = tracks[t].line.coordinates
    for (let i = 0; i < points.length; i++) {
      if (chained[t][i] >= distance - 0.5) return [points[i][0], points[i][1]]
      last = points[i]
    }
  }
  return last ? [last[0], last[1]] : undefined
}

/** A checkpoint of the leg that has its weather, and its place on the map. */
export interface MapCheckpoint {
  checkpoint: WeatherCheckpointDto & { weather: WeatherConditionsDto }
  longitude: number
  latitude: number
  /** Who gives way when zoomed out (`checkpointRanks`): null never does, a lower rank goes first. */
  rank: number | null
}

/**
 * The checkpoints the map shows a badge for: only those with a forecast — a point « not yet
 * forecast » says nothing on a map — each placed by its distance on the chained measure.
 */
export function mapCheckpoints(
  tracks: Tracks,
  checkpoints: readonly WeatherCheckpointDto[],
  chained: number[][] = chainedDistances(tracks)
): MapCheckpoint[] {
  const placed: Omit<MapCheckpoint, 'rank'>[] = []
  for (const checkpoint of checkpoints) {
    if (!checkpoint.weather) continue
    const point = checkpointPoint(tracks, checkpoint.distance, chained)
    if (!point) continue
    placed.push({
      checkpoint: checkpoint as MapCheckpoint['checkpoint'],
      longitude: point[0],
      latitude: point[1],
    })
  }
  const ranks = checkpointRanks(placed.map((marker) => marker.checkpoint))
  return placed.map((marker, i) => ({ ...marker, rank: ranks[i] }))
}

/**
 * Which points hold out longest when the map zooms out (ledger WEB-142): null for a leg's start and
 * finish, always shown; for the points en route, their depth in a bisection of the route — the
 * middle 0, the quarters 1, the eighths 2… — so that the badges left stay evenly spread. Depends on
 * the leg alone, never on the zoom: the same point keeps its rank from one zoom to the next.
 */
export function checkpointRanks(checkpoints: readonly { kind: string }[]): (number | null)[] {
  const ranks = checkpoints.map((): number | null => null)
  const enRoute = checkpoints.flatMap((c, i) =>
    c.kind === WeatherCheckpointKind.START || c.kind === WeatherCheckpointKind.FINISH ? [] : [i]
  )
  const bisect = (from: number, to: number, depth: number) => {
    if (from > to) return
    const middle = Math.floor((from + to) / 2)
    ranks[enRoute[middle]] = depth
    bisect(from, middle - 1, depth + 1)
    bisect(middle + 1, to, depth + 1)
  }
  bisect(0, enRoute.length - 1, 0)
  return ranks
}

/**
 * How far to move each badge, in screen pixels, so that none lies on another (ledgers WEB-128,
 * WEB-131). Badges whose boxes (`width` × `height`, centred on their point) touch — a loop's start
 * and finish, or points that close up when zooming out — slide **sideways**, at their own height,
 * by the least that clears them, in the route's order: the first of them stays on its point, the
 * next goes to the side it already stands on, right on a tie (the start left of the finish of a
 * loop). No shared row: on a long north-south route, zoomed out, each badge touches the next, and
 * one row would carry them all off the map, far from their points; this way they fall on either
 * side of the track. A badge alone stays put, and nothing lands on it.
 */
export function spreadBadges(
  points: readonly { x: number; y: number }[],
  width: number,
  height: number
): { dx: number; dy: number }[] {
  // Projected points are fractional: without this margin, a badge placed exactly `width` away could
  // still touch by a rounding error, and `clear` would land on the same spot for ever.
  const touches = (a: { x: number; y: number }, b: { x: number; y: number }) =>
    Math.abs(a.x - b.x) < width - 1e-6 && Math.abs(a.y - b.y) < height
  const placed = points.filter((p, i) => !points.some((q, j) => j !== i && touches(p, q)))
  const clear = (point: { x: number; y: number }, side: 1 | -1) => {
    let dx = 0
    for (;;) {
      const hit = placed.find((other) => touches({ x: point.x + dx, y: point.y }, other))
      if (!hit) return dx
      dx = hit.x + side * width - point.x
    }
  }
  return points.map((point) => {
    if (placed.includes(point)) return { dx: 0, dy: 0 }
    const right = clear(point, 1)
    const left = clear(point, -1)
    const dx = Math.abs(left) < Math.abs(right) ? left : right
    placed.push({ x: point.x + dx, y: point.y })
    return { dx, dy: 0 }
  })
}

/**
 * Which badges the map has room for at this zoom, and where (ledger WEB-142): null for a badge left
 * out, else its shift in pixels. A point of rank null is always kept, moved apart from the others
 * of its kind by `spreadBadges`; the others are tried by rank then in order, each kept only when no
 * kept badge stands within `clearWidth` × `clearHeight` of it, and never moved.
 */
export function layoutBadges(
  points: readonly { x: number; y: number; rank: number | null }[],
  width: number,
  height: number,
  clearWidth: number,
  clearHeight: number
): ({ dx: number; dy: number } | null)[] {
  const result = points.map((): { dx: number; dy: number } | null => null)
  const indexes = points.map((_, i) => i)
  const required = indexes.filter((i) => points[i].rank === null)
  const spread = spreadBadges(
    required.map((i) => points[i]),
    width,
    height
  )
  const kept = required.map((i, k) => {
    result[i] = spread[k]
    return { x: points[i].x + spread[k].dx, y: points[i].y + spread[k].dy }
  })
  const candidates = indexes
    .filter((i) => points[i].rank !== null)
    .sort((a, b) => (points[a].rank as number) - (points[b].rank as number))
  for (const i of candidates) {
    const { x, y } = points[i]
    if (kept.some((o) => Math.abs(o.x - x) < clearWidth && Math.abs(o.y - y) < clearHeight))
      continue
    result[i] = { dx: 0, dy: 0 }
    kept.push({ x, y })
  }
  return result
}

/**
 * The rotation of the map's wind arrow, degrees clockwise from north up: where the wind blows
 * *towards* (`direction` is where it comes from, plus 180). Absolute on a map facing north — the
 * relative arrow, the rider's frame, stays in the timeline (plan §4).
 */
export function mapWindRotation(direction: number, bearing = 0): number {
  // The marker stays upright while the map turns: the arrow takes the bearing off
  const angle = (direction + 180 - bearing) % 360
  return Math.round(angle < 0 ? angle + 360 : angle) % 360
}

/** The legend's order: « Dos · Travers · Face ». */
export const WIND_SHARE_ORDER: RelativeWind[] = [
  RelativeWind.TAIL,
  RelativeWind.CROSS,
  RelativeWind.HEAD,
]

/**
 * How much of the leg is ridden with, across and against the wind, metres, in legend order — the
 * server's totals, those of the exposure bar under the forecast. A kind never met is left out.
 */
export function windShares(
  leg: Pick<WeatherLegDto, 'windExposure'>
): { relativeWind: RelativeWind; length: number }[] {
  const lengths: Record<RelativeWind, number> = {
    [RelativeWind.TAIL]: leg.windExposure.tail,
    [RelativeWind.CROSS]: leg.windExposure.cross,
    [RelativeWind.HEAD]: leg.windExposure.head,
  }
  return WIND_SHARE_ORDER.filter((kind) => lengths[kind] > 0).map((relativeWind) => ({
    relativeWind,
    length: lengths[relativeWind],
  }))
}

/**
 * Whether a leg can colour its route by the wind: a forecast (OK or STALE) with at least one
 * checkpoint that carries its weather. NOT_YET_AVAILABLE, NO_LOCATION, OUT_OF_RANGE and
 * UNAVAILABLE offer nothing. A finished or cancelled ride is the page's call.
 */
export function hasWindForecast(leg: WeatherLegDto | undefined): leg is WeatherLegDto {
  return !!leg && hasForecast(leg.status) && leg.checkpoints.some((c) => !!c.weather)
}

/**
 * The shade of the wind on the map and in its legend: 6 in both themes, as the surface's — the
 * darker shades of the dark theme vanish on a dark basemap (docs/BRANDING.md §3.6). The families
 * are the generated ones (contracts/brand-colors.yaml).
 */
export const RELATIVE_WIND_MAP_SHADE = 6

/** The stroke of every relative wind, resolved from the Mantine theme. */
export function relativeWindStrokeColors(theme: MantineTheme): Record<RelativeWind, string> {
  const colors = {} as Record<RelativeWind, string>
  for (const kind of WIND_SHARE_ORDER) {
    colors[kind] = theme.colors[RELATIVE_WIND_COLORS[kind]][RELATIVE_WIND_MAP_SHADE]
  }
  return colors
}

const HTML_ESCAPES: Record<string, string> = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;',
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (c) => HTML_ESCAPES[c])
}

/**
 * The forecast's credit as MapLibre's attribution control takes it — HTML, which it sets as is:
 * the name escaped, the link kept only for an http(s) URL.
 */
export function attributionHtml(attribution: WeatherAttributionDto): string {
  const name = escapeHtml(attribution.name)
  return /^https?:\/\//i.test(attribution.url)
    ? `<a href="${escapeHtml(attribution.url)}" target="_blank" rel="noopener noreferrer">${name}</a>`
    : name
}
