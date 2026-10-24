// The wind of a trip's stages on its maps (ledger WEB-118, plan
// docs/plans/archive/2026-10-24-weather-on-map.md §5 palier 3 lot B): a stage's leg comes from the trip's
// weather (`TripWeatherDto`), with the same checkpoints, stretches and statuses as a ride group's,
// so the group's logic (`weatherOnRoute.ts`) lays it on the stage's own route. Pure, free of the
// map chunk.
import type { TripDto, TripWeatherDto, WeatherLegDto, WindExposureDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import { hasWindForecast } from './weatherOnRoute'

/** Whether the trip's maps can offer the Météo mode at all: neither finished nor cancelled. */
function tripOffersWind(trip: TripDto): boolean {
  return !trip.finished && trip.status !== Status.CANCELLED
}

/**
 * A stage's leg when its maps offer the Météo mode (WEB-118): a forecast with at least one point's
 * weather (`hasWindForecast` — a stage already gone is OUT_OF_RANGE and offers none), on a trip
 * neither finished nor cancelled. One rule for the stage's page and its fullscreen map, which must
 * agree: a link to the map in the Météo mode falls back on the grade exactly when the page would.
 */
export function stageWindLeg(
  trip: TripDto,
  weather: TripWeatherDto | undefined,
  stageId: string | undefined
): WeatherLegDto | undefined {
  if (!stageId || !tripOffersWind(trip)) return undefined
  const leg = weather?.stages.find((s) => s.stageId === stageId)?.leg
  return hasWindForecast(leg) ? leg : undefined
}

/** One trace of the trip's overview map in the Météo mode: its leg, read in its own zone. */
export interface MapItemWind {
  leg: WeatherLegDto
  /** The stage's zone (a stage may differ from its trip): its passages read in it. */
  timezone: string
}

/**
 * The wind of every trace of the trip's overview map, by map item id (`TripDetailPage`'s items):
 * each stage's leg on its own route, at its own day, read in its own zone. Only the stages with a
 * wind forecast — a stage gone, beyond the horizon or without a route has none, and its trace keeps
 * the line's default colour.
 *
 * A trip drawn on its own route (`trip.routeSlug`) has a single trace: it takes the single leg of a
 * trip without stages (no `stageId`, the trip's route at its own time). Its stages, if it has any,
 * are forecast along *their* routes, which the overview does not draw — so none of them is laid on
 * the trip's line, where its distances would land anywhere.
 */
export function tripMapWinds(
  trip: TripDto,
  weather: TripWeatherDto | undefined
): Map<string, MapItemWind> {
  const winds = new Map<string, MapItemWind>()
  if (!weather || !tripOffersWind(trip)) return winds
  if (trip.routeSlug) {
    const only = weather.stages.length === 1 ? weather.stages[0] : undefined
    if (only && !only.stageId && hasWindForecast(only.leg)) {
      winds.set(trip.id, { leg: only.leg, timezone: trip.timezone })
    }
    return winds
  }
  for (const stage of trip.stages ?? []) {
    if (!stage.route?.slug) continue
    const leg = weather.stages.find((s) => s.stageId === stage.id)?.leg
    if (hasWindForecast(leg)) winds.set(stage.id, { leg, timezone: stage.timezone })
  }
  return winds
}

/** What a wind legend reads of a leg — or of several stages taken together. */
export type WindLegendSource = Pick<
  WeatherLegDto,
  'windExposure' | 'status' | 'speedIsDefault' | 'averageSpeed'
>

/**
 * The legend of the trip's overview map in the Météo mode: the stages with a forecast taken
 * together. Their shares add up the server's own totals, stage by stage (the stages never overlap,
 * each is its own ride), so « Dos · Travers · Face » reads the whole of what is still to ride with a
 * forecast — the sum of the stages' own legends, in one line whatever their number. « Prévision
 * ancienne » as soon as one stage's is; the default speed as soon as one stage rides at it (the same
 * 25 km/h for all of them).
 */
export function combinedWindLegend(legs: readonly WeatherLegDto[]): WindLegendSource | undefined {
  if (legs.length === 0) return undefined
  const windExposure: WindExposureDto = { head: 0, cross: 0, tail: 0 }
  for (const leg of legs) {
    windExposure.head += leg.windExposure.head
    windExposure.cross += leg.windExposure.cross
    windExposure.tail += leg.windExposure.tail
  }
  const atDefault = legs.find((leg) => leg.speedIsDefault)
  return {
    windExposure,
    status: legs.some((leg) => leg.status === WeatherStatus.STALE)
      ? WeatherStatus.STALE
      : WeatherStatus.OK,
    speedIsDefault: !!atDefault,
    averageSpeed: (atDefault ?? legs[0]).averageSpeed,
  }
}
