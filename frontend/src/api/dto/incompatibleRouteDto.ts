import type { Visibility } from './visibility.ts'

/**
 * A route whose visibility does not fit the ride or trip being saved
 */
export interface IncompatibleRouteDto {
  /** Route URL slug */
  slug: string
  /** Route name */
  name: string
  /** The route's visibility today (TEAM) */
  visibility: Visibility
  /** The visibility the route takes when the same request is replayed with alignVisibility = true: always PUBLIC_UNLISTED, even under a PUBLIC ride or trip — a route never becomes PUBLIC without an explicit decision. */
  proposedVisibility: Visibility
}
