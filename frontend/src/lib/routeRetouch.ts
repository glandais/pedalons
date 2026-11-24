import type { TFunction } from 'i18next'
import {
  ErrorCode,
  RetouchKind,
  RouteGeneratorType,
  type GeoPoint,
  type RetouchedRouteDto,
  type RouteRetouchOfferDto,
  type RouteRetouchRequest,
} from '@/api/dto'
import { ApiClientError, apiErrorCode, isNetworkError } from '@/lib/apiError'
import { tRegister, type TranslationKey } from '@/lib/i18nUtils'
import {
  GENERATOR_DEFAULT_DISCOVERY,
  GENERATOR_MAX_KM,
  GENERATOR_MIN_KM,
} from '@/hooks/filters/routeGeneratorFilters'
import { pointToParam, type GeneratedHandoff } from '@/lib/routeGenerator'

/**
 * Retouching a saved route (ledger `API-212`, plan `2026-11-24-retouche-parcours-lot7c.md`): the
 * pure rules of the dialog — bounds, request, the changed stretch, the hand-off to the planner and
 * the words of each refusal.
 */

/** A change smaller than this many km from the bound is read as on it (display rounding). */
const BOUND_EPSILON_KM = 0.05

export interface RetouchBounds {
  /** The route's own length, km. */
  currentKm: number
  minKm: number
  maxKm: number
  /** The smallest change, km, above or below the length. */
  minChangeKm: number
  /** The largest change as a share of the length, 0 to 1. */
  maxChangeShare: number
}

/** The field's bounds read from the offer, never typed here; undefined when the offer lacks them. */
export function retouchBounds(offer: RouteRetouchOfferDto | undefined): RetouchBounds | undefined {
  if (
    !offer?.available ||
    offer.originalDistanceM === undefined ||
    offer.minDistanceKm === undefined ||
    offer.maxDistanceKm === undefined
  ) {
    return undefined
  }
  return {
    currentKm: offer.originalDistanceM / 1000,
    minKm: offer.minDistanceKm,
    maxKm: offer.maxDistanceKm,
    minChangeKm: offer.minChangeKm ?? 1,
    maxChangeShare: offer.maxChangeShare ?? 0.3,
  }
}

/** The target is too close to the route's length for a retouch: the « zone morte ». */
export function isDeadZone(targetKm: number, bounds: RetouchBounds): boolean {
  return Math.abs(targetKm - bounds.currentKm) < bounds.minChangeKm - 1e-9
}

/** The target is out of the offer's range. */
export function isOutOfRange(targetKm: number, bounds: RetouchBounds): boolean {
  return targetKm < bounds.minKm - BOUND_EPSILON_KM || targetKm > bounds.maxKm + BOUND_EPSILON_KM
}

/** The target brought into the range, for a unit conversion that rounded past a bound. */
export function clampTarget(targetKm: number, bounds: RetouchBounds): number {
  return Math.min(bounds.maxKm, Math.max(bounds.minKm, targetKm))
}

/** The target asks for a shorter route: refused more often than the other changes. */
export function isShortening(targetKm: number, currentKm: number): boolean {
  return targetKm < currentKm
}

export type RetouchTarget =
  | { mode: 'resize'; targetKm: number }
  | { mode: 'moveEnd'; point: GeoPoint }
  | { mode: 'moveEnd'; placeId: string }

/** The request: exactly one of `targetDistanceKm` and `end`, and one key of `end`. */
export function routeRetouchRequest(target: RetouchTarget, seed: number): RouteRetouchRequest {
  const base = { discovery: GENERATOR_DEFAULT_DISCOVERY, seed }
  if (target.mode === 'resize') {
    return { ...base, targetDistanceKm: Math.round(target.targetKm * 10) / 10 }
  }
  if ('placeId' in target) return { ...base, end: { placeId: target.placeId } }
  return { ...base, end: { point: { lat: target.point.lat, lng: target.point.lng } } }
}

/**
 * The new stretch of a proposal: `coords[startIndex..endIndex]`, both included, clamped to the
 * line; empty when the indices do not describe a stretch (a truncation has none to highlight).
 */
export function changedCoords(
  coords: number[][],
  startIndex: number,
  endIndex: number
): number[][] {
  const from = Math.max(0, Math.floor(startIndex))
  const to = Math.min(coords.length - 1, Math.floor(endIndex))
  if (coords.length === 0 || from > to) return []
  return coords.slice(from, to + 1)
}

/** A proposal that only cuts the route short: nothing new is drawn. */
export function isTruncation(candidate: Pick<RetouchedRouteDto, 'kind'>): boolean {
  return candidate.kind === RetouchKind.TRUNCATE
}

/** What the planner's import takes, through `location.state` (`readGeneratedHandoff`). */
export function retouchHandoff(
  candidate: RetouchedRouteDto,
  rideType: RouteGeneratorType | undefined,
  name: string
): GeneratedHandoff {
  return {
    polyline: candidate.polyline,
    type: rideType ?? RouteGeneratorType.ROAD,
    distanceM: candidate.distanceM,
    name,
  }
}

/**
 * The generator's page, for a route of about this distance starting where the route does: where a
 * refused shortening goes next. The distance is rounded into the generator's own bounds.
 */
export function generatorLinkFor(
  generatePath: string,
  start: number[] | undefined,
  targetKm: number | undefined,
  type: RouteGeneratorType | undefined
): string {
  const params = new URLSearchParams()
  if (targetKm !== undefined && Number.isFinite(targetKm)) {
    const bounded = Math.min(GENERATOR_MAX_KM, Math.max(GENERATOR_MIN_KM, Math.round(targetKm)))
    params.set('d', String(bounded))
  }
  if (start && start.length >= 2) params.set('s', pointToParam({ lng: start[0], lat: start[1] }))
  if (type) params.set('t', type)
  const query = params.toString()
  return query ? `${generatePath}?${query}` : generatePath
}

/** A ring of `radiusM` metres round `center`, as GeoJSON coordinates (closed), to draw a range. */
export function circleCoords(center: GeoPoint, radiusM: number, steps = 48): number[][] {
  const earth = 6371008.8
  const lat = (center.lat * Math.PI) / 180
  const dLat = (radiusM / earth) * (180 / Math.PI)
  const dLng = dLat / Math.max(Math.cos(lat), 1e-6)
  const ring: number[][] = []
  for (let i = 0; i < steps; i++) {
    const angle = (2 * Math.PI * i) / steps
    ring.push([center.lng + dLng * Math.cos(angle), center.lat + dLat * Math.sin(angle)])
  }
  ring.push(ring[0])
  return ring
}

// --- Errors -------------------------------------------------------------------------------------

/**
 * The words of each code of the retouch. A typed table, never a key built from the enum (ledger
 * `WEB-84`). Codes absent here fall on `errors.api.*`, then on the generic message.
 */
const RETOUCH_ERROR_KEYS: Partial<Record<ErrorCode, TranslationKey>> = {
  [ErrorCode.ROUTE_RETOUCH_NOT_READY]: tRegister('routeRetouch.errors.notReady'),
  [ErrorCode.ROUTE_RETOUCH_UNSUPPORTED]: tRegister('routeRetouch.errors.unsupported'),
  [ErrorCode.ROUTE_RETOUCH_ORDER_ANOMALY]: tRegister('routeRetouch.errors.orderAnomaly'),
  [ErrorCode.ROUTE_RETOUCH_NO_PROPOSAL]: tRegister('routeRetouch.errors.noProposal'),
  [ErrorCode.ROUTE_RETOUCH_END_UNREACHABLE]: tRegister('routeRetouch.errors.endUnreachable'),
  [ErrorCode.GENERATOR_END_TOO_FAR]: tRegister('routeRetouch.errors.endTooFar'),
  [ErrorCode.GENERATOR_OUT_OF_COVERAGE]: tRegister('routeRetouch.errors.outOfCoverage'),
  [ErrorCode.GENERATOR_UNAVAILABLE]: tRegister('routeGenerator.errors.unavailable'),
  [ErrorCode.ROUTE_GENERATOR_BUSY]: tRegister('routeGenerator.errors.busy'),
  [ErrorCode.ROUTE_PLANNER_DISABLED]: tRegister('routeGenerator.errors.disabled'),
}

/** The refusals that are an answer, not a breakdown: shown in blue. */
const INFO_CODES: ReadonlySet<ErrorCode> = new Set([
  ErrorCode.ROUTE_RETOUCH_NO_SHORTER,
  ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_LARGE,
  ErrorCode.ROUTE_RETOUCH_ORDER_ANOMALY,
  ErrorCode.ROUTE_RETOUCH_UNSUPPORTED,
  ErrorCode.ROUTE_RETOUCH_NO_PROPOSAL,
  ErrorCode.ROUTE_RETOUCH_END_UNREACHABLE,
  ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_SMALL,
])

/** The refusals a second identical request meets again: « Réessayer » is not offered. */
const NON_RETRYABLE: ReadonlySet<ErrorCode> = new Set([
  ErrorCode.ROUTE_RETOUCH_NOT_READY,
  ErrorCode.ROUTE_RETOUCH_UNSUPPORTED,
  ErrorCode.ROUTE_RETOUCH_ORDER_ANOMALY,
  ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_SMALL,
  ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_LARGE,
  ErrorCode.ROUTE_RETOUCH_NO_SHORTER,
  ErrorCode.ROUTE_RETOUCH_NO_PROPOSAL,
  ErrorCode.ROUTE_RETOUCH_END_UNREACHABLE,
  ErrorCode.GENERATOR_END_TOO_FAR,
  ErrorCode.GENERATOR_OUT_OF_COVERAGE,
  ErrorCode.ROUTE_GENERATOR_RATE_LIMITED,
  ErrorCode.ROUTE_PLANNER_DISABLED,
  ErrorCode.VALIDATION,
])

/** « Réessayer » helps on a network failure, a busy server or an unknown one. */
export function isRetryableRetouchError(error: unknown): boolean {
  if (isNetworkError(error)) return true
  const code = apiErrorCode(error)
  return code === undefined || !NON_RETRYABLE.has(code)
}

/** Blue (a reply, with next steps) or red (a failure). */
export function retouchErrorTone(error: unknown): 'info' | 'error' {
  const code = apiErrorCode(error)
  return code !== undefined && INFO_CODES.has(code) ? 'info' : 'error'
}

/** A shortening that no proposal answers: the dialog offers the finish and the generator. */
export function isNoShorter(error: unknown): boolean {
  return apiErrorCode(error) === ErrorCode.ROUTE_RETOUCH_NO_SHORTER
}

/** A refusal another seed can turn into proposals: « Autres propositions » stays offered (plan §5). */
export function isOtherSeedUseful(error: unknown): boolean {
  const code = apiErrorCode(error)
  return code === ErrorCode.ROUTE_RETOUCH_NO_PROPOSAL || code === ErrorCode.ROUTE_RETOUCH_NO_SHORTER
}

export interface RetouchErrorTexts {
  /** The distance asked, in the reader's unit. */
  distance: string
  /** The route's own length. */
  current: string
  /** The smallest change. */
  min: string
  /** The largest change as a share of the length, formatted (« 30 % »). */
  percent: string
}

/** The message under the fields for a failed call; épicène, each sentence names what to do. */
export function routeRetouchErrorMessage(
  error: unknown,
  t: TFunction,
  texts: RetouchErrorTexts
): string {
  if (isNetworkError(error)) return t('routeGenerator.errors.network')
  const code = apiErrorCode(error)
  if (code === ErrorCode.ROUTE_GENERATOR_RATE_LIMITED) {
    const seconds = error instanceof ApiClientError ? error.retryAfterSeconds : undefined
    if (seconds !== undefined) {
      return t('routeGenerator.errors.rateLimitedWait', {
        count: Math.max(1, Math.ceil(seconds / 60)),
      })
    }
    return t('errors.api.ROUTE_GENERATOR_RATE_LIMITED')
  }
  // The wordings that name a figure: written out, so that each call carries its own variables
  if (code === ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_SMALL) {
    return t('routeRetouch.errors.changeTooSmall', { min: texts.min, current: texts.current })
  }
  if (code === ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_LARGE) {
    return t('routeRetouch.errors.changeTooLarge', { percent: texts.percent })
  }
  if (code === ErrorCode.ROUTE_RETOUCH_NO_SHORTER) {
    return t('routeRetouch.errors.noShorter', { distance: texts.distance })
  }
  if (code === ErrorCode.VALIDATION) return t('routeRetouch.errors.invalidRequest')
  const key = code ? RETOUCH_ERROR_KEYS[code] : undefined
  if (key) return t(key)
  return t('routeRetouch.errors.generic')
}
