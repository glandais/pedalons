import type { Hilliness } from './hilliness.ts'
import type { ListViewMode } from './listViewMode.ts'
import type { NearType } from './nearType.ts'
import type { RouteSortBy } from './routeSortBy.ts'
import type { SortDirection } from './sortDirection.ts'
import type { SurfaceType } from './surfaceType.ts'
import type { WindDirection } from './windDirection.ts'

export type ListRoutesParams = {
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
  /** Page number (0-indexed) */
  page?: number
  /** Search by name/markdown */
  search?: string
  /** Page size */
  size?: number
  /** Sort by field (DISTANCE, ELEVATION_GAIN, HILLINESS, DATE_TIME) */
  sortBy?: RouteSortBy
  /** Sort direction (ASC, DESC) */
  sortDir?: SortDirection
  /** Filter by surface type */
  surfaceType?: SurfaceType
  /** Only the routes carrying at least one of these tags — ids (TSID) of the team's ROUTE tags, comma-separated or repeated. Unknown ids are ignored; a filter left with no known id filters nothing. */
  tags?: string[]
  /** How much of each row to send. COMPACT (case-insensitive) returns media.markdown empty and media.assets trimmed to the logo, the first image and the themed thumbnails — read 'excerpt' and 'thumbnailUrl' instead, both of which are present either way. The markdown body, the attachments, the GPX and FIT files and every image past the first are dropped. Omitted, or FULL, is the previous behaviour, byte for byte. */
  view?: ListViewMode
  /** Filter by wind direction */
  windDirection?: WindDirection
}
