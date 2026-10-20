import type { GeoPoint } from './geoPoint.ts'
import type { WaypointOrigin } from './waypointOrigin.ts'
import type { WaypointType } from './waypointType.ts'

/**
 * A waypoint of a route, as sent by the editor
 */
export interface WaypointRequest {
  /** Identifier of an existing waypoint, as returned by the API: it keeps its origin. Omitted or unknown: a new waypoint. Malformed or repeated: 400 */
  id?: string
  /** Where the waypoint is */
  position: GeoPoint
  /** What the waypoint is */
  type: WaypointType
  /**
   * Name, possibly empty (the type's label then shows on a device). The editor limits it to 40 characters; the API accepts what an import can bring, up to 250
   * @maxLength 250
   */
  name: string
  /**
   * Free text, at most 500 characters
   * @maxLength 500
   */
  description?: string
  /**
   * The distance in metres the editor shows the waypoint at. Only used to pick which passage of a route that goes by twice the waypoint belongs to: the server recomputes the distance itself
   * @minimum 0
   */
  distance?: number
  /** Origin of a new waypoint, AUTHOR by default. Ignored for a waypoint that exists: it keeps its own */
  origin?: WaypointOrigin
}
