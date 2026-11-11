import type { PublicationType } from './publicationType.ts'
import type { Visibility } from './visibility.ts'

/**
 * A ride or trip visible outside the team that uses the route
 */
export interface IncompatibleRouteUsageDto {
  /** RIDE or TRIP */
  type: PublicationType
  /** Ride or trip URL slug, in the route's team */
  slug: string
  /** Ride or trip name */
  name: string
  /** Its visibility: PUBLIC or PUBLIC_UNLISTED */
  visibility: Visibility
}
