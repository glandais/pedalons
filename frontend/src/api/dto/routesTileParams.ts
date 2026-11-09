import type { Hilliness } from './hilliness.ts'
import type { NearType } from './nearType.ts'
import type { SurfaceType } from './surfaceType.ts'
import type { WindDirection } from './windDirection.ts'

export type RoutesTileParams = {
  /** Hilliness preset (FLAT, HILLY, MOUNTAINOUS) */
  hilliness?: Hilliness
  /** Maximum distance in meters */
  maxDistance?: number
  /** Maximum elevation gain in meters */
  maxElevationGain?: number
  /** Minimum distance in meters */
  minDistance?: number
  /** Minimum elevation gain in meters */
  minElevationGain?: number
  /** Latitude for proximity search */
  nearLat?: number
  /** Longitude for proximity search */
  nearLon?: number
  /** Search radius in meters (default: 25000) */
  nearRadius?: number
  /** Search near START, END, or START_OR_END (default) */
  nearType?: NearType
  /** Search by name/markdown */
  search?: string
  /** Filter by surface type */
  surfaceType?: SurfaceType
  /** Tile token from POST /api/tiles/token, for clients whose map renderer cannot carry an Authorization header. Omitted, the request falls back to the session cookie and then to the anonymous visitor. */
  t?: string
  /** Only the routes carrying at least one of these tags — ids (TSID) of the team's ROUTE tags, comma-separated or repeated. Unknown ids are ignored; a filter left with no known id filters nothing. */
  tags?: string[]
  /** Filter by wind direction */
  windDirection?: WindDirection
}
