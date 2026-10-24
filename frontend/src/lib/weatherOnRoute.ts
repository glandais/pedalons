// The wind on a group's route map (ledger WEB-115, plan docs/plans/2026-10-24-weather-on-map.md):
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
import type { TrackDto, WeatherAttributionDto, WeatherLegDto } from '@/api/dto'
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
