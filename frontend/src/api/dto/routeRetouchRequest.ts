import type { RouteRetouchEnd } from './routeRetouchEnd.ts'

/**
 * What to change in a saved route: exactly one of targetDistanceKm (aim at a total distance) and end (move the finish)
 */
export interface RouteRetouchRequest {
  /**
   * The total distance aimed at, in kilometres (not the change). The bounds of the field are the offer's (GET .../retouch): minDistanceKm to maxDistanceKm
   * @minimum 1
   * @maximum 1000
   */
  targetDistanceKm?: number
  /** The new finish */
  end?: RouteRetouchEnd
  /**
   * From the team's roads (0) to discovery (1); rounded to the hundredth by the engine. Absent: 0.25
   * @minimum 0
   * @maximum 1
   */
  discovery?: number
  /**
   * Makes "other proposals" reproducible: the same seed gives the same routes. Absent: 0
   * @minimum 0
   */
  seed?: number
}
