import type { PlannerJunctionKind } from './plannerJunctionKind.ts'

export interface PlannerJunction {
  kind: PlannerJunctionKind
  lng: number
  lat: number
  ele?: number
  /** Index of the source track this point comes from; with idx or not at all */
  source?: number
  /** Index of this point in that source track */
  idx?: number
}
