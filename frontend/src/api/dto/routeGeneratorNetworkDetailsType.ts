export type RouteGeneratorNetworkDetailsType =
  (typeof RouteGeneratorNetworkDetailsType)[keyof typeof RouteGeneratorNetworkDetailsType]

export const RouteGeneratorNetworkDetailsType = {
  GENERATOR_NETWORK_TOO_SMALL: 'GENERATOR_NETWORK_TOO_SMALL',
} as const
