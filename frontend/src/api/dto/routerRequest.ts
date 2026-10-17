import type { GeoPoint } from './geoPoint.ts'
import type { RouterProfile } from './routerProfile.ts'

export interface RouterRequest {
  from: GeoPoint
  to: GeoPoint
  profile: RouterProfile
  /**
   * Slug of the team the route is being drawn for. When present, the team must have the route planner enabled and the caller must be allowed to create routes in it. When absent, the domain's GPX planner must be enabled.
   * @maxLength 250
   */
  teamSlug?: string
}
