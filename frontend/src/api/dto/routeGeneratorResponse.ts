import type { GeneratedRouteDto } from './generatedRouteDto.ts'
import type { RouteGeneratorNetworkDto } from './routeGeneratorNetworkDto.ts'

/**
 * Routes proposed by the team's route generator
 */
export interface RouteGeneratorResponse {
  /** One to three routes, best first, different from each other */
  candidates: GeneratedRouteDto[]
  /** What the team's network is made of */
  network: RouteGeneratorNetworkDto
  /** True when the team rides too few routes of the requested type nearby, so the familiarity of all kinds was used instead */
  familiarityFallback: boolean
}
