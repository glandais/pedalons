import type { GpsRouteSyncState } from './gpsRouteSyncState.ts'
import type { GpsServiceType } from './gpsServiceType.ts'
import type { Instant } from './instant.ts'

/**
 * Where the route stands at one of the caller's automatically synced services
 */
export interface RouteGpsSyncStatusDto {
  /** GPS service */
  serviceType: GpsServiceType
  /** SENT: at the service, up to date; OUTDATED: at the service in an older version that nothing will update, send it again; PENDING: to be sent or updated shortly; FAILING: the last attempt failed (a few retries, then it waits for the route to change); RECONNECT_REQUIRED: the connection must be renewed */
  state: GpsRouteSyncState
  /** When the route was last sent to the service successfully. Absent while it never was. */
  syncedAt?: Instant
}
