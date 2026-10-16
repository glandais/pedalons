import type { GpsRouteSyncState } from './gpsRouteSyncState.ts'
import type { GpsServiceType } from './gpsServiceType.ts'

/**
 * Where the route stands at one of the user's GPS services
 */
export interface DeviceRouteSyncStatusDto {
  /** GPS service */
  serviceType: GpsServiceType
  /** SENT: at the service, up to date; OUTDATED: at the service in an older version that nothing will update, send it again; PENDING: to be sent or updated shortly; FAILING: the last attempt failed (a few retries, then it waits for the route to change); RECONNECT_REQUIRED: the connection must be renewed */
  state: GpsRouteSyncState
}
