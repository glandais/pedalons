import type { TFunction } from 'i18next'
import { z } from 'zod'
import {
  CompassPoint,
  ErrorCode,
  RouteGeneratorType,
  type GeoPoint,
  type RouteGeneratorNetworkDetails,
  type RouteGeneratorRequest,
} from '@/api/dto'
import { ApiClientError, apiErrorCode, isNetworkError } from '@/lib/apiError'
import { distance as haversine } from '@/components/map/mapUtils'
import { tRegister, type TranslationKey } from '@/lib/i18nUtils'

/** What the generator needs of the page's parameters (`RouteGeneratorFilters` carries more). */
export interface GeneratorParams {
  /** `"lat,lng"`; absent: the team's location. */
  start?: string
  /** `"lat,lng"`; absent: a loop. */
  end?: string
  bearing?: CompassPoint
  distanceKm: number
  familiarity: number
  type?: RouteGeneratorType
  seed: number
}

// --- Points in the query string -----------------------------------------------------------------

/** `"lat,lng"`, 5 decimals (about a metre): what reaches the URL. */
export function pointToParam(point: GeoPoint): string {
  return `${point.lat.toFixed(5)},${point.lng.toFixed(5)}`
}

/** The point of a `"lat,lng"` string; undefined when it is not one. */
export function pointFromParam(value: string | undefined): GeoPoint | undefined {
  if (!value) return undefined
  const match = /^(-?\d{1,3}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)$/.exec(value.trim())
  if (!match) return undefined
  const lat = Number(match[1])
  const lng = Number(match[2])
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return undefined
  if (Math.abs(lat) > 90 || Math.abs(lng) > 180) return undefined
  return { lat, lng }
}

/** The canonical (5 decimals) form of a `"lat,lng"` string, undefined for garbage. */
export function normalizePointParam(value: string): string | undefined {
  const point = pointFromParam(value)
  return point ? pointToParam(point) : undefined
}

// --- Hand-off to the route editor ---------------------------------------------------------------

/** The candidate the generator page hands to the editor, through `location.state`. */
export const generatedHandoffSchema = z.object({
  polyline: z.string().min(1),
  type: z.enum(RouteGeneratorType),
  distanceM: z.number().nonnegative(),
})

export type GeneratedHandoff = z.infer<typeof generatedHandoffSchema>

/** The hand-off a history state carries, undefined when absent or malformed. */
export function readGeneratedHandoff(state: unknown): GeneratedHandoff | undefined {
  const generated = (state as { generated?: unknown } | null | undefined)?.generated
  const parsed = generatedHandoffSchema.safeParse(generated)
  return parsed.success ? parsed.data : undefined
}

// --- Rules --------------------------------------------------------------------------------------

/**
 * The end is far when the straight line from the start is at least half the wished distance: the
 * backend's rule (`QueryContext.bearingApplies = chord < D/2`, measured between the snapped nodes),
 * which then ignores the bearing. The client compares the clicked points, so close to the threshold
 * the two may disagree, which is harmless.
 */
export function isEndFar(
  start: GeoPoint | undefined,
  end: GeoPoint | undefined,
  distanceKm: number
): boolean {
  if (!start || !end) return false
  return haversine(start.lng, start.lat, end.lng, end.lat) >= (distanceKm * 1000) / 2
}

/** The type of the team's routes that are the most numerous; ROAD > GRAVEL > MTB on a tie. */
export function dominantGeneratorType(counts: {
  ROAD?: number
  GRAVEL?: number
  MTB?: number
}): RouteGeneratorType {
  let best: RouteGeneratorType = RouteGeneratorType.ROAD
  let bestCount = counts.ROAD ?? 0
  for (const type of [RouteGeneratorType.GRAVEL, RouteGeneratorType.MTB]) {
    const count = counts[type] ?? 0
    if (count > bestCount) {
      best = type
      bestCount = count
    }
  }
  return best
}

/**
 * The request of the page's parameters. `start` and `end` are left out when absent, `bearing` when
 * the end is far (it would be ignored anyway), and the type is the page's, else the dominant one.
 */
export function routeGeneratorRequest(
  params: GeneratorParams,
  type: RouteGeneratorType,
  resolvedStart?: GeoPoint
): RouteGeneratorRequest {
  const start = pointFromParam(params.start)
  const end = pointFromParam(params.end)
  const far = isEndFar(start ?? resolvedStart, end, params.distanceKm)
  const request: RouteGeneratorRequest = {
    distanceKm: params.distanceKm,
    familiarity: params.familiarity,
    type: params.type ?? type,
    seed: params.seed,
  }
  if (start) request.start = start
  if (end) request.end = end
  if (params.bearing && !far) request.bearing = params.bearing
  return request
}

export type FamiliarityBand = 'low' | 'mid' | 'high'

/** The mean familiarity of a route, in words: a percentage of a log-normalised count means nothing. */
export function familiarityBand(familiarity: number): FamiliarityBand {
  if (familiarity < 1 / 3) return 'low'
  if (familiarity < 2 / 3) return 'mid'
  return 'high'
}

/** The shared out-and-back stretch is mentioned from this length. */
export const SHARED_MIN_METERS = 100

// --- GPX of a candidate -------------------------------------------------------------------------

function escapeXml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;')
}

/**
 * A GPX holding one track of one segment, no elevation: the planner's import endpoint adds them.
 * `coords` are `[lng, lat]` pairs.
 */
export function gpxFromLine(name: string, coords: number[][]): string {
  const points = coords
    .map((c) => `<trkpt lat="${c[1].toFixed(6)}" lon="${c[0].toFixed(6)}"></trkpt>`)
    .join('')
  return (
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<gpx version="1.1" creator="Pedalons" xmlns="http://www.topografix.com/GPX/1/1">' +
    `<trk><name>${escapeXml(name)}</name><trkseg>${points}</trkseg></trk></gpx>`
  )
}

/** « Parcours généré de 82 km ». */
export function generatedRouteName(distanceText: string, t: TFunction): string {
  return t('routeGenerator.generatedName', { distance: distanceText })
}

// --- Errors -------------------------------------------------------------------------------------

/**
 * The codes the generator words its own way (it names the distance, the routes still being
 * analysed, the wait); any other gets its `errors.api.*` message, then the generic one. A typed
 * table, never a key built from the enum (ledger `WEB-84`).
 */
const GENERATOR_ERROR_KEYS: Partial<Record<ErrorCode, TranslationKey>> = {
  [ErrorCode.GENERATOR_START_TOO_FAR]: tRegister('routeGenerator.errors.startTooFar'),
  [ErrorCode.GENERATOR_END_TOO_FAR]: tRegister('routeGenerator.errors.endTooFar'),
  [ErrorCode.ROUTE_GENERATOR_BUSY]: tRegister('routeGenerator.errors.busy'),
  [ErrorCode.ROUTE_PLANNER_DISABLED]: tRegister('routeGenerator.errors.disabled'),
}

/** The refusals that a second identical request meets again: « Réessayer » is not offered. */
const GENERATOR_NON_RETRYABLE: ReadonlySet<ErrorCode> = new Set([
  ErrorCode.GENERATOR_START_TOO_FAR,
  ErrorCode.GENERATOR_END_TOO_FAR,
  ErrorCode.GENERATOR_DISTANCE_TOO_SHORT,
  ErrorCode.GENERATOR_NO_ROUTE,
  ErrorCode.GENERATOR_NETWORK_TOO_SMALL,
  ErrorCode.ROUTE_GENERATOR_RATE_LIMITED,
  ErrorCode.ROUTE_PLANNER_DISABLED,
])

/** « Réessayer » helps on a network failure, a busy server or an unknown one. */
export function isRetryableGeneratorError(error: unknown): boolean {
  if (isNetworkError(error)) return true
  const code = apiErrorCode(error)
  return code === undefined || !GENERATOR_NON_RETRYABLE.has(code)
}

function networkDetails(error: unknown): RouteGeneratorNetworkDetails | undefined {
  if (!(error instanceof ApiClientError)) return undefined
  const details = error.error.errorDetails as { type?: string } | undefined
  return details?.type === 'GENERATOR_NETWORK_TOO_SMALL'
    ? (details as RouteGeneratorNetworkDetails)
    : undefined
}

/**
 * The message under the generator for a failed call. `distance` is the requested distance in the
 * reader's unit (« 120 km »). Épicène, no point médian: each sentence names the action.
 */
export function generatorErrorMessage(
  error: unknown,
  t: TFunction,
  { distance }: { distance: string }
): string {
  if (isNetworkError(error)) return t('routeGenerator.errors.network')
  const code = apiErrorCode(error)
  if (code === ErrorCode.GENERATOR_NETWORK_TOO_SMALL) {
    const details = networkDetails(error)
    if (details?.incomplete) {
      return t('routeGenerator.errors.networkPending', { count: details.pendingRouteCount })
    }
    if (details && details.routeCount === 0) return t('routeGenerator.errors.networkEmpty')
    return t('routeGenerator.errors.networkTooSmall', { distance })
  }
  if (code === ErrorCode.GENERATOR_DISTANCE_TOO_SHORT) {
    return t('routeGenerator.errors.distanceTooShort', { distance })
  }
  if (code === ErrorCode.GENERATOR_NO_ROUTE) return t('routeGenerator.errors.noRoute', { distance })
  if (code === ErrorCode.ROUTE_GENERATOR_RATE_LIMITED) {
    const seconds = error instanceof ApiClientError ? error.retryAfterSeconds : undefined
    if (seconds !== undefined) {
      return t('routeGenerator.errors.rateLimitedWait', {
        count: Math.max(1, Math.ceil(seconds / 60)),
      })
    }
    return t('errors.api.ROUTE_GENERATOR_RATE_LIMITED')
  }
  const key = code ? GENERATOR_ERROR_KEYS[code] : undefined
  if (key) return t(key)
  return t('routeGenerator.errors.generic')
}
