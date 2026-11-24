import type { Instant } from './instant.ts'
import type { RetouchedRouteDto } from './retouchedRouteDto.ts'
import type { RouteRetouchOperation } from './routeRetouchOperation.ts'

/**
 * Proposals to retouch a saved route
 */
export interface RouteRetouchResponse {
  /** The operation answered */
  operation: RouteRetouchOperation
  /** Length of the original route's raw track in metres, the engine's own */
  originalDistanceM: number
  /** Elevation gain of the original track, computed in the same batch as the proposals' so that before and after compare like with like */
  originalAscentM?: number
  /** Elevation loss of the original track */
  originalDescentM?: number
  /** RESIZE: the total distance asked, in metres */
  targetDistanceM?: number
  /** One to three proposals, best first */
  candidates: RetouchedRouteDto[]
  /** When the team's roads were last prepared for the generator. Absent when the request did not use them (discovery) */
  networkPreparedAt?: Instant
}
