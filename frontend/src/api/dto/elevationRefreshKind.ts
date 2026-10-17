export type ElevationRefreshKind = (typeof ElevationRefreshKind)[keyof typeof ElevationRefreshKind]

export const ElevationRefreshKind = {
  ROUTE: 'ROUTE',
  PREVIEW: 'PREVIEW',
} as const
