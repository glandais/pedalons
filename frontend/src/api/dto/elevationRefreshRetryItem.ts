import type { ElevationRefreshKind } from './elevationRefreshKind.ts'
import type { Instant } from './instant.ts'

/**
 * One abandoned recomputation
 */
export interface ElevationRefreshRetryItem {
  /** Kind of target */
  kind: ElevationRefreshKind
  /** ID of the route or preview */
  targetId: string
  /** Team slug (routes) */
  teamSlug?: string
  /** Route slug (routes) */
  routeSlug?: string
  /** Public identifier (previews) */
  previewPublicId?: string
  /** Failed attempts before the retry */
  attempts: number
  /** Last error recorded, before the retry */
  lastError?: string
  /** When the recomputation was first requested */
  firstRequestedAt: Instant
}
