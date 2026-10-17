import type { ElevationRefreshKind } from './elevationRefreshKind.ts'

/**
 * Which abandoned HD elevation recomputations to start again: the routes and GPX-tool previews whose request used up its attempts and stay on the fast profile.
 */
export interface ElevationRefreshRetryRequest {
  /** List what would be retried, without changing anything */
  dryRun: boolean
  /**
   * Retry at most this many targets, oldest first (default 100)
   * @minimum 1
   * @maximum 1000
   */
  limit?: number
  /** Only this kind of target (default: both) */
  kind?: ElevationRefreshKind
}
