import type { GeoPoint } from './geoPoint.ts'
import type { MediaDto } from './mediaDto.ts'
import type { PlannerState } from './plannerState.ts'
import type { SurfaceType } from './surfaceType.ts'
import type { Visibility } from './visibility.ts'
import type { WaypointRequest } from './waypointRequest.ts'

/**
 * Route update request
 */
export interface RouteRequest {
  /**
   * Route name
   * @minLength 3
   * @maxLength 200
   * @pattern \S
   */
  name: string
  /** Media */
  media: MediaDto
  /** Surface type */
  surfaceType: SurfaceType
  /** Whether the route is publicly visible */
  visibility: Visibility
  /**
   * Points from frontend routing
   * @maxItems 100000
   */
  points?: GeoPoint[]
  /** IDs (TSID) of the team's ROUTE tags the route carries, replacing the whole set — at most 10, each a tag of this team and of kind ROUTE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update. */
  tagIds?: string[]
  /** Editing state of the planner; the server derives the track from it. Not with points (400 PLANNER_STATE_INVALID); a gpxFile wins over it */
  plannerState?: PlannerState
  /**
   * The complete list of the route's waypoints, replacing them. Omitted: they stay as they are (placed again on the new track when the track changes, and a new GPX file replaces the imported ones and keeps the author's). When present it wins over the waypoints of a GPX file sent with it
   * @maxItems 500
   */
  waypoints?: WaypointRequest[]
}
