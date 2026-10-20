import type { GeoPoint } from './geoPoint.ts'
import type { PlannerState } from './plannerState.ts'
import type { WaypointRequest } from './waypointRequest.ts'

/**
 * GPX preview update request
 */
export interface GpxPreviewUpdateRequest {
  /**
   * Preview name
   * @minLength 3
   * @maxLength 250
   * @pattern \S
   */
  name: string
  /**
   * Points from frontend routing
   * @maxItems 100000
   */
  points?: GeoPoint[]
  /** Editing state of the planner; the server derives the track from it. Not with points (400 PLANNER_STATE_INVALID); a gpxFile wins over it */
  plannerState?: PlannerState
  /**
   * The complete list of the waypoints, replacing them. Omitted: they stay as they are (placed again when the track changes)
   * @maxItems 500
   */
  waypoints?: WaypointRequest[]
}
