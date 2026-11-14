/**
 * What the team's generator network is made of. Lengths in metres
 */
export interface RouteGeneratorNetworkDto {
  /** Length of the road the search can reach around the start and the end. Absent when no route was generated */
  lengthM?: number
  /** Length of the whole network of the team */
  totalLengthM: number
  /** Routes the network is made of */
  routeCount: number
  /** Routes whose roads are still being analysed and are not in the network yet */
  pendingRouteCount: number
  /** Routes ticked "ne pas utiliser pour générer des parcours" */
  excludedRouteCount: number
  /** True when pendingRouteCount is above zero: the network may still grow */
  incomplete: boolean
}
