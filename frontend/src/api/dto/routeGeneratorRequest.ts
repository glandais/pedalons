import type { CompassPoint } from './compassPoint.ts'
import type { GeoPoint } from './geoPoint.ts'
import type { RouteGeneratorType } from './routeGeneratorType.ts'

/**
 * What to ask the route generator for
 */
export interface RouteGeneratorRequest {
  /** Start. Absent: the team's location (400 VALIDATION if it has none) */
  start?: GeoPoint
  /** End. Absent: a loop, the route ends where it starts. Present: a one-way route from start to end */
  end?: GeoPoint
  /** Wished direction, only used when the end is closer than half the distance (a loop included) */
  bearing?: CompassPoint
  /**
   * Wished distance in kilometres, 10 to 200
   * @minimum 10
   * @maximum 200
   */
  distanceKm: number
  /**
   * From the team's roads (0, only the roads the team rides) to discovery (1, no preference for them); rounded to the hundredth by the engine. Absent: 0.25
   * @minimum 0
   * @maximum 1
   */
  discovery?: number
  /** What to ride. Absent: ROAD */
  type?: RouteGeneratorType
  /**
   * Makes "other proposals" reproducible: the same seed gives the same routes. Absent: 0
   * @minimum 0
   */
  seed?: number
}
