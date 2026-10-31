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
import { RelativeWind } from '@/api/dto'
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
import { distance } from '@/components/map/mapUtils'

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
  const placed: MapCheckpoint[] = []
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
  return placed
}

/** Two badges closer than this share a spot: a loop's start and finish. */
const SAME_SPOT_METERS = 100

/**
 * Where each badge stands among those sharing its spot (`SAME_SPOT_METERS`), in the order of the
 * route: a loop's start and finish would otherwise lie one on the other, the finish hiding the
 * start. `count` is 1 for a badge alone.
 */
export function sameSpotRanks(
  markers: readonly MapCheckpoint[]
): { rank: number; count: number }[] {
  const groups: number[][] = []
  const groupOf: number[] = []
  markers.forEach((marker, i) => {
    const group = groups.findIndex((members) =>
      members.some((j) => {
        const other = markers[j]
        return (
          distance(marker.longitude, marker.latitude, other.longitude, other.latitude) <
          SAME_SPOT_METERS
        )
      })
    )
    if (group >= 0) {
      groupOf.push(group)
      groups[group].push(i)
    } else {
      groupOf.push(groups.length)
      groups.push([i])
    }
  })
  return markers.map((_, i) => {
    const members = groups[groupOf[i]]
    return { rank: members.indexOf(i), count: members.length }
  })
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
