import type { PlannerSnapshot } from '@/hooks/useRoutePlanner'
import { plannerPayload } from '@/lib/plannerSubmit'
import { encode2 } from '@/lib/polyline'
import type { DonePayload, Outgoing } from './bridge'

interface DoneInput {
  snapshot: PlannerSnapshot
  /** Whether the route does not exist yet (`PlannerLoad.create`). */
  create: boolean
  /** Metres and metres of climb of the route as drawn. */
  distance: number
  ascend: number
  pointCount: number
  /** Whether anything changed since the planner opened (track or route points). */
  dirty: boolean
  nameSuggestion?: string
}

/**
 * The `done` message: what the app's form sends of the track, decided by the one rule of the
 * site's form (`plannerPayload`, never re-derived here or in Dart), and what its preview card
 * shows. The file of an untouched import does not cross the bridge again: the app kept it, and
 * `file: true` tells it to upload that one.
 */
export function doneMessage({
  snapshot,
  create,
  distance,
  ascend,
  pointCount,
  dirty,
  nameSuggestion,
}: DoneInput): Extract<Outgoing, { type: 'done' }> {
  const track = plannerPayload(snapshot, create)
  const payload: DonePayload = {
    ...(track.points && { points: track.points }),
    ...(track.plannerState && { plannerState: track.plannerState }),
    ...(track.file && { file: true as const }),
    ...(track.waypoints && { waypoints: track.waypoints }),
  }
  return {
    type: 'done',
    payload,
    stats: {
      distance,
      ascend,
      pointCount,
      line: encode2(snapshot.points.map((p) => [p.lng, p.lat])),
    },
    dirty,
    ...(nameSuggestion && { nameSuggestion }),
    ...(track.tooLarge && { notice: 'tooLarge' as const }),
  }
}
