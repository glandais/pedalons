/** What a control point is on the route: where it starts, where it ends, or a via point. */
export type MarkerRole = 'start' | 'via' | 'end'

/**
 * Role of the control point at `index` among `total`. A route of one point only has a start; the
 * last point is the finish as soon as there are two.
 */
export function markerRole(index: number, total: number): MarkerRole {
  if (index === 0) return 'start'
  if (total > 1 && index === total - 1) return 'end'
  return 'via'
}
