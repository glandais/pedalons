import type { GeneratedRouteDto } from './generatedRouteDto.ts'
import type { Instant } from './instant.ts'

/**
 * Routes proposed by the route generator
 */
export interface RouteGeneratorResponse {
  /** One to three routes, best first, different from each other */
  candidates: GeneratedRouteDto[]
  /** When the team's roads were last prepared for the generator (the night before at best). Absent when the request did not use them (discovery) */
  networkPreparedAt?: Instant
  /** True when part of the area around the start leaves the region the generator covers: proposals are rarer there */
  partialCoverage: boolean
}
