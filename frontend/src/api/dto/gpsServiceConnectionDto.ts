import type { GpsAutoSyncState } from './gpsAutoSyncState.ts'
import type { GpsServiceType } from './gpsServiceType.ts'
import type { Instant } from './instant.ts'

/**
 * GPS service connection information
 */
export interface GpsServiceConnectionDto {
  /** Service type identifier */
  serviceType: GpsServiceType
  /** Display name of the service */
  displayName: string
  /** When the service was connected */
  connectedAt: Instant
  /** Whether the routes of the rides the user is registered in are sent to this service automatically, and kept in sync (new route, corrected GPX, another group), from 7 days before the departure until a day after it */
  autoSync: boolean
  /** Where the automatic sync stands. OFF when autoSync is false; RECONNECT_REQUIRED is only cleared by connecting the service again */
  autoSyncState: GpsAutoSyncState
  /** How many routes the automatic sync currently has at the service (removed after the ride, or when the sync is turned off) */
  autoSyncRouteCount: number
  /** When the automatic sync last sent a route to this service */
  lastAutoSyncAt?: Instant
}
