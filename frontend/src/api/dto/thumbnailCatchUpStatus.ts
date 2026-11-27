/**
 * State of the automatic catch-up that redraws outdated map thumbnails
 */
export interface ThumbnailCatchUpStatus {
  /** Current version of the thumbnail drawing */
  version: number
  /** Whether the scheduled catch-up is switched on */
  enabled: boolean
  /** Entities the catch-up redraws per hour, per backend */
  perHour: number
  /** Entities with thumbnails drawn before the current version that the catch-up still has to redraw, those waiting for a retry included */
  behind: number
  /** Among the entities behind, those waiting for the next attempt */
  waiting: number
  /** Entities the catch-up gave up on after repeated failures */
  givenUp: number
}
