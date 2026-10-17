import type { ElevationRefreshRetryItem } from './elevationRefreshRetryItem.ts'

/**
 * Outcome of an HD elevation retry, one entry per target
 */
export interface ElevationRefreshRetryResponse {
  /** Whether this was a dry run (nothing changed) */
  dryRun: boolean
  /** Number of abandoned targets in the domain, before the limit */
  matched: number
  /** Targets listed, and retried unless dry run; at most the limit */
  items: ElevationRefreshRetryItem[]
}
