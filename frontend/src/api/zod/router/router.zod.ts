import * as zod from 'zod'

/**
 * Calculate a route between two points using the Stadia Maps routing API. Each call is billed against a monthly quota, so the checks come first: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled. Otherwise ROUTE_PLANNER_DISABLED. Routing failures have their own codes: ROUTING_SEGMENT_TOO_LONG and ROUTING_NO_ROUTE (400), ROUTING_QUOTA_EXCEEDED and ROUTING_UNAVAILABLE (503).
 * @summary Calculate route
 */
export const routeBodyFromLngMin = -180
export const routeBodyFromLngMax = 180

export const routeBodyFromLatMin = -90
export const routeBodyFromLatMax = 90

export const routeBodyToLngMin = -180
export const routeBodyToLngMax = 180

export const routeBodyToLatMin = -90
export const routeBodyToLatMax = 90

export const routeBodyTeamSlugMax = 250

export const routeBodyUseHillsMin = 0
export const routeBodyUseHillsMax = 1

export const routeBodyUseRoadsMin = 0
export const routeBodyUseRoadsMax = 1

export const RouteBody = zod.object({
  from: zod.object({
    lng: zod.number().min(routeBodyFromLngMin).max(routeBodyFromLngMax),
    lat: zod.number().min(routeBodyFromLatMin).max(routeBodyFromLatMax),
  }),
  to: zod.object({
    lng: zod.number().min(routeBodyToLngMin).max(routeBodyToLngMax),
    lat: zod.number().min(routeBodyToLatMin).max(routeBodyToLatMax),
  }),
  profile: zod.enum(['BIKE', 'FASTBIKE', 'GRAVEL', 'MTB', 'RUN_HIKE', 'MOTORCYCLE']),
  teamSlug: zod
    .string()
    .max(routeBodyTeamSlugMax)
    .optional()
    .describe(
      "Slug of the team the route is being drawn for. When present, the team must have the route planner enabled and the caller must be allowed to create routes in it. When absent, the domain's GPX planner must be enabled."
    ),
  useHills: zod
    .number()
    .min(routeBodyUseHillsMin)
    .max(routeBodyUseHillsMax)
    .optional()
    .describe(
      "Propensity to climb, 0 (avoid hills) to 1 (no fear). Absent: the profile's value. Bicycle profiles only; ignored otherwise."
    ),
  useRoads: zod
    .number()
    .min(routeBodyUseRoadsMin)
    .max(routeBodyUseRoadsMax)
    .optional()
    .describe(
      "Propensity to ride with traffic, 0 (cycleways and paths) to 1 (roads). Absent: the profile's value (1 for FASTBIKE). Bicycle profiles only; ignored otherwise."
    ),
})

export const RouteResponse = zod.object({
  route: zod.object({
    type: zod.enum(['LineString']),
    coordinates: zod.array(zod.array(zod.number())).describe('Array of [lon, lat] coordinates'),
  }),
  dist: zod.number().optional(),
  ascend: zod.number().optional(),
})
