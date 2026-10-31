import type { ClimbDto } from './climbDto.ts'
import type { GeoJsonLineString } from './geoJsonLineString.ts'
import type { SurfaceSpanDto } from './surfaceSpanDto.ts'
import type { TrackSurfaceState } from './trackSurfaceState.ts'

/**
 * GPX track with track points
 */
export interface TrackDto {
  line: GeoJsonLineString
  /** List of climbs on the route */
  climbs: ClimbDto[]
  /** Where the surface of the track stands. Absent: never computed (a track saved before the feature, or the feature off), or not included (bulk endpoint with geometry=false, which carries no track) */
  surfaceState?: TrackSurfaceState
  /** Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL), VersaTiles vector tiles */
  surfaces?: SurfaceSpanDto[]
}
