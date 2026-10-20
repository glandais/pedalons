import type { GeoJsonPoint } from './geoJsonPoint.ts'
import type { WaypointOrigin } from './waypointOrigin.ts'
import type { WaypointType } from './waypointType.ts'

/**
 * A waypoint of a route. Its geometry is where the author put it: its own position, never its projection on the track
 */
export interface WaypointDto {
  geometry: GeoJsonPoint
  /** Name, possibly empty */
  name: string
  /** Identifier (TSID) of the waypoint, to send back in the request so that it keeps its origin. Null for a waypoint of a GPX file not saved yet */
  id?: string
  /** What the waypoint is */
  type: WaypointType
  /** Free text, at most 500 characters */
  description?: string
  /** Metres from the start along the tracks in order (cumulated from one track to the next, in the order of their ids). Null for a waypoint more than 50 m from the track */
  distance?: number
  /** Who put the waypoint: its AUTHOR in the editor, or a GPX file it was IMPORTED from. A new GPX file replaces the imported ones and keeps the author's */
  origin: WaypointOrigin
}
