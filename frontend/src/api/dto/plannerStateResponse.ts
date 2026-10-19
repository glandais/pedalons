import type { PlannerState } from './plannerState.ts'

/**
 * Editing state of the planner of a route or a preview, if any
 */
export interface PlannerStateResponse {
  /** The state; absent when there is none to read back */
  state?: PlannerState
}
