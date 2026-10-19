import type { GeoPoint, PlannerState } from '@/api/dto'
import type { PlannerSnapshot } from '@/hooks/useRoutePlanner'

/** What a form sends of the planner's track: the state, or the points, never both. */
export interface PlannerTrackPayload {
  points?: GeoPoint[]
  plannerState?: PlannerState
  /** The state was past the bounds: the points are sent and the saved track loses its control points. */
  tooLarge?: boolean
}

/**
 * The one rule of what a form sends when its source is the planner:
 *  - creation: the state, the points when the state is past the bounds;
 *  - modification, route untouched: nothing (the track and its saved state stay, a rename does not
 *    send the track through the GPX chain again);
 *  - modification, route emptied below two points: nothing (a cleared route replaces nothing);
 *  - modification, route changed: the state, the points (and a notice) past the bounds.
 */
export function plannerPayload(
  snapshot: PlannerSnapshot | undefined,
  create: boolean
): PlannerTrackPayload {
  if (!snapshot || snapshot.points.length < 2) return {}
  if (!create && !snapshot.dirty) return {}
  if (snapshot.plannerState) return { plannerState: snapshot.plannerState }
  return { points: snapshot.points, tooLarge: !create }
}
