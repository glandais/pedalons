import type { Hilliness } from './hilliness.ts'
import type { MinRole } from './minRole.ts'
import type { NearType } from './nearType.ts'
import type { SurfaceType } from './surfaceType.ts'
import type { WindDirection } from './windDirection.ts'

export type GetAllRoutesBoundsParams = {
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
  /** Only routes from teams where the user has at least this role. Yields a null box for an anonymous visitor. */
  minRole?: MinRole
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
  /** Filter by wind direction */
  windDirection?: WindDirection
}
