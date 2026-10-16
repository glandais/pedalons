export type GpsRouteSyncState = (typeof GpsRouteSyncState)[keyof typeof GpsRouteSyncState]

export const GpsRouteSyncState = {
  SENT: 'SENT',
  OUTDATED: 'OUTDATED',
  PENDING: 'PENDING',
  FAILING: 'FAILING',
  RECONNECT_REQUIRED: 'RECONNECT_REQUIRED',
} as const
