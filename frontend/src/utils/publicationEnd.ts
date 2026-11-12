/**
 * When a ride, a trip or a stage is over (docs/LEDGER_*.md WEB-167, R6 and R7). Imports nothing but
 * types: `rideGroupData` reads it, and a module reached from the routes' config must not pull the
 * date formatters (and i18n) along.
 */
import type { RideDto, TripDto, TripStageDto } from '@/api/dto'

/**
 * Over: `endDateTime`, the end the server stores (API-85), has passed — « Terminée », not the API's
 * `finished`, which only says the start has. Leaving a group and exporting its route stay offered
 * until then (docs/LEDGER_*.md WEB-167, R6 and R7). An end the payload lacks never makes it over.
 */
export function isOver(
  publication: Pick<RideDto | TripDto, 'endDateTime'>,
  now: number = Date.now()
): boolean {
  const end = Date.parse(publication.endDateTime)
  return Number.isFinite(end) && now >= end
}

/** A stage without an estimated arrival rides three hours, the server's rule for a ride's end. */
const STAGE_FALLBACK_MS = 3 * 60 * 60 * 1000

/** The stage is over: its estimated arrival, else its departure plus three hours, has passed. */
export function stageIsOver(
  stage: Pick<TripStageDto, 'dateTime' | 'estimatedArrival'>,
  now: number = Date.now()
): boolean {
  const end = stage.estimatedArrival
    ? Date.parse(stage.estimatedArrival)
    : Date.parse(stage.dateTime) + STAGE_FALLBACK_MS
  return Number.isFinite(end) && now >= end
}
