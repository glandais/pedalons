/**
 * Connections to one GPS service and the routes sent through them
 */
export interface AdminGpsServiceStatsDto {
  /** The service (GARMIN, HAMMERHEAD) */
  service: string
  /** Connections */
  connections: number
  /** Accounts with at least one connection */
  users: number
  /** Connections with automatic sending on */
  autoSync: number
  /** Connections that must be reconnected */
  reconnectRequired: number
  /** Connections used during the last 30 days */
  usedLast30Days: number
  /** Routes sent or to send through these connections */
  routeSyncs: number
  /** Of which delivered */
  routeSyncsSucceeded: number
  /** Of which in error */
  routeSyncsFailed: number
}
