import type { StraightLine } from './straightLine.ts'

export interface LineElevationRequest {
  /**
   * Slug of the team the route is being drawn for. When present, the team must have the route planner enabled and the caller must be allowed to create routes in it. When absent, the domain's GPX planner must be enabled.
   * @maxLength 250
   */
  teamSlug?: string
  /**
   * Straight lines to read the relief of, 1 to 50, at most 100 km each and 200 km together
   * @minItems 1
   * @maxItems 50
   */
  lines: StraightLine[]
}
