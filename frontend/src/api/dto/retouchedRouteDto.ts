import type { BoundsDto } from './boundsDto.ts'
import type { RetouchedSpanDto } from './retouchedSpanDto.ts'
import type { RetouchKind } from './retouchKind.ts'
import type { RetouchVariant } from './retouchVariant.ts'

/**
 * A route retouched by the generator's engine
 */
export interface RetouchedRouteDto {
  /** The WHOLE retouched route as a polyline of precision 6 (latitude then longitude), the encoding of the planner's GPX import */
  polyline: string
  /** Distance in metres */
  distanceM: number
  /** Elevation gain in metres, measured as the original's (originalAscentM). Absent when the profile was not ready in time */
  ascentM?: number
  /** Elevation loss in metres. Absent like the gain */
  descentM?: number
  /** What changed */
  kind: RetouchKind
  /** Which choice a MOVE_END route makes. Absent for the others */
  variant?: RetouchVariant
  /** Share of the original route kept as it was drawn, 0 to 1 */
  keptShare: number
  /** Metres of the kept parts that the engine could not match to its map: there, the route may ride a road twice and nothing was checked */
  unmatchedM: number
  /** MOVE_END and TRUNCATE: distance in metres from the asked finish to the last point of the route */
  endSnapM?: number
  /** The stretch that changed */
  changed: RetouchedSpanDto
  /** Map frame of the whole route */
  bounds: BoundsDto
}
