import type { PlannerJunction } from './plannerJunction.ts'
import type { PlannerPiece } from './plannerPiece.ts'
import type { PlannerSource } from './plannerSource.ts'
import type { RouterProfile } from './routerProfile.ts'

/**
 * Editing state of the route planner
 */
export interface PlannerState {
  version: number
  profile: RouterProfile
  /** @maxItems 8 */
  sources: PlannerSource[]
  /** @maxItems 2001 */
  junctions: PlannerJunction[]
  /** @maxItems 2000 */
  pieces: PlannerPiece[]
}
