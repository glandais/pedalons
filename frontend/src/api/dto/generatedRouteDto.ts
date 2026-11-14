import type { BoundsDto } from './boundsDto.ts'

/**
 * A route proposed by the generator, every metre of it on a team road
 */
export interface GeneratedRouteDto {
  /** Geometry as a polyline of precision 6 (latitude then longitude), the encoding of the planner's GPX import */
  polyline: string
  /** Distance in metres */
  distanceM: number
  /** Elevation gain in metres */
  ascentM: number
  /** Elevation loss in metres */
  descentM: number
  /** Angle in degrees between the wished bearing and the route's. Absent when the bearing did not apply */
  bearingDeviationDeg?: number
  /** How often the team rides these roads, 0 to 1 */
  familiarity: number
  /** Share of the distance on unpaved roads, 0 to 1 */
  unpavedShare: number
  /** Metres ridden twice (the way to and from the loop), counted once */
  sharedM: number
  /** Junctions crossed more than once outside the shared part */
  crossings: number
  /** Map frame of the route */
  bounds: BoundsDto
}
