import type { GeoPoint } from './geoPoint.ts'
import type { RouterEngine } from './routerEngine.ts'
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
  /**
   * Propensity to climb, 0 (avoid hills) to 1 (no fear). Absent: the profile's value. Bicycle profiles only; ignored otherwise.
   * @minimum 0
   * @maximum 1
   */
  useHills?: number
  /**
   * Propensity to ride with traffic, 0 (cycleways and paths) to 1 (roads). Absent: the profile's value (1 for FASTBIKE). Bicycle profiles only; ignored otherwise.
   * @minimum 0
   * @maximum 1
   */
  useRoads?: number
  /** Engine that calculates the leg. Absent: STADIA. PEDALONS applies to the profiles BIKE, FASTBIKE, GRAVEL and MTB when GET /api/router/engines offers it; otherwise, and whenever that engine cannot answer, the leg is calculated by STADIA, with useHills and useRoads, and the response does not say so. */
  engine?: RouterEngine
}
