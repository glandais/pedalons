import type { AdSortBy } from './adSortBy.ts'
import type { AdType } from './adType.ts'
import type { ListViewMode } from './listViewMode.ts'
import type { SortDirection } from './sortDirection.ts'

export type ListAdsParams = {
  /** Filter by ad type */
  adType?: AdType
  /** Start date filter (ISO format) */
  from?: string
  /** Highest asking price to include */
  maxPrice?: number
  /** Lowest asking price to include. Ads with no price ('à négocier') are excluded by either price bound. */
  minPrice?: number
  /** Latitude for proximity search */
  nearLat?: number
  /** Longitude for proximity search */
  nearLon?: number
  /** Search radius in metres around nearLat/nearLon (default 25000, capped at 500000). Ads with no location are excluded when a centre is given. */
  nearRadius?: number
  /** Page number */
  page?: number
  /** Search by name/description */
  search?: string
  /** Page size */
  size?: number
  /** Sort column (default: publication date) */
  sortBy?: AdSortBy
  /** Sort direction (default: DESC) */
  sortDir?: SortDirection
  /** Only the ads carrying at least one of these tags — ids (TSID) of the team's AD tags, comma-separated or repeated. Unknown ids are ignored; a filter left with no known id filters nothing. */
  tags?: string[]
  /** End date filter (ISO format) */
  to?: string
  /** How much of each row to send. COMPACT (case-insensitive) returns media.markdown empty and media.assets trimmed to the logo, the first image and the themed thumbnails — read 'excerpt', 'thumbnailUrl' and 'images' instead, all of which are present either way. The markdown body, the attachments, the GPX and FIT files and every image past the first are dropped. Omitted, or FULL, is the previous behaviour, byte for byte. */
  view?: ListViewMode
}
