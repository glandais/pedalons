import type { GeoPoint } from './geoPoint.ts'
import type { PlannerState } from './plannerState.ts'

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
}
