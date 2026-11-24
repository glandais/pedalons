import type { RouteGeneratorType } from './routeGeneratorType.ts'
import type { RouteRetouchOperation } from './routeRetouchOperation.ts'
import type { RouteRetouchUnavailable } from './routeRetouchUnavailable.ts'

/**
 * Whether a route can be retouched by the caller now, and within which bounds. Nothing is computed to answer: the engine's capabilities and the heads of the route's stored documents
 */
export interface RouteRetouchOfferDto {
  /** The retouch can be asked for now */
  available: boolean
  /** Why not. NOT_ALLOWED and ENGINE_UNAVAILABLE: show nothing. NOT_READY: the route is still being analysed (show the action disabled). UNSUPPORTED: show nothing. Absent when available */
  unavailableReason?: RouteRetouchUnavailable
  /** The operations offered; empty when not available */
  operations: RouteRetouchOperation[]
  /** Length of the route's raw track in metres. Absent when not available */
  originalDistanceM?: number
  /** Smallest total distance of a RESIZE, in kilometres, rounded inwards to the tenth */
  minDistanceKm?: number
  /** Largest total distance of a RESIZE, in kilometres, rounded inwards to the tenth */
  maxDistanceKm?: number
  /** Smallest change of a RESIZE, in kilometres, above or below the route's length */
  minChangeKm?: number
  /** Largest change of a RESIZE as a share of the route's length, 0 to 1 */
  maxChangeShare?: number
  /** How far from a way of the ride type the new finish may be, in metres */
  endSnapM?: number
  /** Proposals returned at most */
  proposalsMax?: number
  /** The ride type the engine is asked for, from the route's surface type */
  rideType?: RouteGeneratorType
}
