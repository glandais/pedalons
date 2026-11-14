import type { CompassPoint } from './compassPoint.ts'
import type { GeoPoint } from './geoPoint.ts'
import type { RouteGeneratorType } from './routeGeneratorType.ts'

/**
 * What to ask the team's route generator for
 */
export interface RouteGeneratorRequest {
  /** Start. Absent: the team's location (400 VALIDATION if it has none) */
  start?: GeoPoint
  /** End. Absent: a loop, the route ends where it starts. Present: a one-way route from start to end */
  end?: GeoPoint
  /** Wished direction, only used when the end is closer than half the distance (a loop included) */
  bearing?: CompassPoint
  /**
   * Wished distance in kilometres, 10 to 300
   * @minimum 10
   * @maximum 300
   */
  distanceKm: number
  /**
   * 0 prefers roads the team rides rarely, 1 the ones it rides often. Absent: 0.5
   * @minimum 0
   * @maximum 1
   */
  familiarity?: number
  /** What to ride. Absent: ROAD */
  type?: RouteGeneratorType
  /** Makes "other proposals" reproducible: the same seed gives the same routes. Absent: 0 */
  seed?: number
}
