export type RouteGeneratorType = (typeof RouteGeneratorType)[keyof typeof RouteGeneratorType]

export const RouteGeneratorType = {
  ROAD: 'ROAD',
  GRAVEL: 'GRAVEL',
  MTB: 'MTB',
} as const
