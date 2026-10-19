export type TrackSurfaceState = (typeof TrackSurfaceState)[keyof typeof TrackSurfaceState]

export const TrackSurfaceState = {
  PENDING: 'PENDING',
  READY: 'READY',
  UNAVAILABLE: 'UNAVAILABLE',
} as const
