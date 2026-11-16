import type { Action } from './action.ts'
import type { Instant } from './instant.ts'
import type { Reason } from './reason.ts'

/**
 * One team's overlay
 */
export interface RouteGeneratorOverlayRefreshItem {
  /** ID of the team */
  teamId: string
  /** Slug of the team */
  teamSlug: string
  /** What is done */
  action: Action
  /** Why */
  reason: Reason
  /** State of the overlay at the engine: absent, ready or stale */
  state?: string
  /** When it was deposited */
  depositedAt?: Instant
  /** When the engine drops it if it is not deposited again */
  expiresAt?: Instant
}
