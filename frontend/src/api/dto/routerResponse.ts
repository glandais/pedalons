import type { GeoJsonLineString } from './geoJsonLineString.ts'
import type { UnpavedSpan } from './unpavedSpan.ts'

export interface RouterResponse {
  route: GeoJsonLineString
  dist?: number
  ascend?: number
  /** Runs of unpaved edges of route (compacted surface or worse, from the router's own maneuvers), half-open, ascending and disjoint; edge i joins route points i and i + 1. Absent when the router gave no surface; empty when all paved */
  unpaved?: UnpavedSpan[]
}
