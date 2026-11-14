import type { RouteGeneratorNetworkDetailsType } from './routeGeneratorNetworkDetailsType.ts'

export interface RouteGeneratorNetworkDetails {
  type: RouteGeneratorNetworkDetailsType
  /** Routes the network is made of */
  routeCount: number
  /** Routes whose roads are still being analysed and are not in the network yet */
  pendingRouteCount: number
  /** Routes ticked "ne pas utiliser pour générer des parcours" */
  excludedRouteCount: number
  /** Length of the whole network of the team, in metres */
  totalLengthM: number
  /** True when pendingRouteCount is above zero: the network may still grow */
  incomplete: boolean
}
