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
  /** Share of the distance off pavement, 0 to 1, as the route page of a saved route measures it (surface tag, then track type, then road class) */
  unpavedShare: number
  /** The share of unpaved asked for, 0 to 1. Absent when no target was sent: a road ride, a request without it, or an engine that does not steer */
  unpavedTarget?: number
  /** Whether unpavedShare is within the engine's tolerance of unpavedTarget. Absent like unpavedTarget. False: the area has no better route, compare the two to tell more from less */
  unpavedTargetReached?: boolean
  /** Metres ridden twice (the way to and from the loop), counted once */
  sharedM: number
  /** Junctions crossed more than once outside the shared part */
  crossings: number
  /** Map frame of the route */
  bounds: BoundsDto
}
