import type { BoundsDto } from './boundsDto.ts'

/**
 * A route proposed by the generator
 */
export interface GeneratedRouteDto {
  /** Geometry as a polyline of precision 6 (latitude then longitude), the encoding of the planner's GPX import */
  polyline: string
  /** Distance in metres */
  distanceM: number
  /** Elevation gain in metres. Absent when the profile was not ready in time: the editor computes it */
  ascentM?: number
  /** Elevation loss in metres. Absent like the gain */
  descentM?: number
  /** Angle in degrees between the wished bearing and the route's. Absent when the bearing did not apply */
  bearingDeviationDeg?: number
  /** Share of the distance on the team's roads, short gaps between them included, 0 to 1 */
  teamShare: number
  /** Share of the distance on unpaved roads, 0 to 1 */
  unpavedShare: number
  /** Metres ridden twice (the way to and from the loop), counted once */
  sharedM: number
  /** Junctions crossed more than once outside the shared part */
  crossings: number
  /** Map frame of the route */
  bounds: BoundsDto
}
