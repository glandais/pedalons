import type { GeoJsonLineString } from './geoJsonLineString.ts'
import type { UnpavedSpan } from './unpavedSpan.ts'

export interface RouterResponse {
  route: GeoJsonLineString
  dist?: number
  ascend?: number
  /** Runs of unpaved edges of route (compacted surface or worse, from the router's own maneuvers), half-open, ascending and disjoint; edge i joins route points i and i + 1. Absent when the router gave no surface; empty when all paved */
  unpaved?: UnpavedSpan[]
  /** Polyline (precision 6, latitude then longitude) of the router's raw geometry, 2D: the leg shapes concatenated as decoded, neither resampled nor simplified; its first and last points are the ends of route. Opaque to the client, which carries it into PlannerPiece.shape. Absent when there is no route */
  shape?: string
}
