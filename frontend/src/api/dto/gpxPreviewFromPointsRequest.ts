import type { EventDateTime } from './eventDateTime.ts'
import type { GeoPoint } from './geoPoint.ts'
import type { PlannerState } from './plannerState.ts'
import type { WaypointRequest } from './waypointRequest.ts'

/**
 * GPX preview creation request from planner points
 */
export interface GpxPreviewFromPointsRequest {
  /**
   * Preview name
   * @minLength 3
   * @maxLength 250
   * @pattern \S
   */
  name: string
  /**
   * Points from frontend routing; points or plannerState, never both (400 PLANNER_STATE_INVALID), and one of them (400 GPX_EMPTY)
   * @maxItems 100000
   */
  points?: GeoPoint[]
  /** Editing state of the planner; the server derives the track from it. Not with points */
  plannerState?: PlannerState
  /**
   * The complete list of the waypoints, replacing them. Omitted: they stay as they are (placed again when the track changes)
   * @maxItems 500
   */
  waypoints?: WaypointRequest[]
  /** Departure date and time, a wall time without offset, in the time zone of the first point of the track (not the device's). Present: the weather is computed when it falls within the next 7 days */
  departure?: EventDateTime
  /**
   * Average speed in km/h, 1 to 100, to estimate the passage times of the weather. Without one, 25 km/h is assumed
   * @minimum 10
   * @maximum 60
   */
  averageSpeed?: number
}
