import type { AdType } from './adType.ts'

export type CountAdsParams = {
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
  /** Search by name/description */
  search?: string
  /** Only the ads carrying at least one of these tags — ids (TSID) of the team's AD tags, comma-separated or repeated. Unknown ids are ignored; a filter left with no known id filters nothing. */
  tags?: string[]
  /** End date filter (ISO format) */
  to?: string
}
