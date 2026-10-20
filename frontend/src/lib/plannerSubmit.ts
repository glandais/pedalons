import type { GeoPoint, PlannerState, WaypointRequest } from '@/api/dto'
import type { PlannerSnapshot } from '@/hooks/useRoutePlanner'

/** What a form sends of the planner's track: the state, or the points, never both. */
export interface PlannerTrackPayload {
  points?: GeoPoint[]
  plannerState?: PlannerState
  /** The route is exactly the file the user imported: the file alone is sent, as an upload of it. */
  file?: File
  /** The state was past the bounds: the points are sent and the saved track loses its control points. */
  tooLarge?: boolean
  /**
   * The complete list of the route points (WEB-100, C3e), present only when the user touched them:
   * absent, the server keeps them as they are (and places them again if the track changes).
   */
  waypoints?: WaypointRequest[]
}

/**
 * The one rule of what a form sends when its source is the planner:
 *  - the route is, untouched, the file imported in place of the track: the file alone (the server
 *    processes it as an upload: waypoints, tracks and original are kept);
 *  - creation: the state, the points when the state is past the bounds;
 *  - modification, route untouched: nothing (the track and its saved state stay, a rename does not
 *    send the track through the GPX chain again);
 *  - modification, route emptied below two points: nothing (a cleared route replaces nothing);
 *  - modification, route changed: the state, the points (and a notice) past the bounds.
 *
 * The route points ride along each of these, but only when the user touched them. Alone (a route
 * left as it is, its points edited) they are the whole payload: the server then keeps the track.
 * Nothing at all is sent below two points of track, route points included.
 */
export function plannerPayload(
  snapshot: PlannerSnapshot | undefined,
  create: boolean
): PlannerTrackPayload {
  if (!snapshot || snapshot.points.length < 2) return {}
  const waypoints = snapshot.waypoints ? { waypoints: snapshot.waypoints } : {}
  if (snapshot.file) return { file: snapshot.file, ...waypoints }
  if (!create && !snapshot.dirty) return waypoints
  if (snapshot.plannerState) return { plannerState: snapshot.plannerState, ...waypoints }
  return { points: snapshot.points, tooLarge: !create, ...waypoints }
}
