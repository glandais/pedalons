export type GpsAutoSyncState = (typeof GpsAutoSyncState)[keyof typeof GpsAutoSyncState]

export const GpsAutoSyncState = {
  OFF: 'OFF',
  UP_TO_DATE: 'UP_TO_DATE',
  PENDING: 'PENDING',
  FAILING: 'FAILING',
  RECONNECT_REQUIRED: 'RECONNECT_REQUIRED',
} as const
