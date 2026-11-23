export type RouteGeneratorUnpaved =
  (typeof RouteGeneratorUnpaved)[keyof typeof RouteGeneratorUnpaved]

export const RouteGeneratorUnpaved = {
  LOW: 'LOW',
  USUAL: 'USUAL',
  HIGH: 'HIGH',
} as const
