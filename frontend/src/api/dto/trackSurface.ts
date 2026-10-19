export type TrackSurface = (typeof TrackSurface)[keyof typeof TrackSurface]

export const TrackSurface = {
  PAVED: 'PAVED',
  PAVED_ROUGH: 'PAVED_ROUGH',
  GRAVEL: 'GRAVEL',
  DIRT: 'DIRT',
  PATH: 'PATH',
  UNKNOWN: 'UNKNOWN',
  OFF_NETWORK: 'OFF_NETWORK',
} as const
