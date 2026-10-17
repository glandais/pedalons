export type ElevationState = (typeof ElevationState)[keyof typeof ElevationState]

export const ElevationState = {
  PENDING: 'PENDING',
  HD: 'HD',
  FAST: 'FAST',
} as const
