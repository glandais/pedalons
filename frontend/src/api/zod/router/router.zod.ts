import * as zod from 'zod'

/**
 * Calculate a route between two points using the Stadia Maps routing API
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
})

export const RouteResponse = zod.object({
  route: zod.object({
    type: zod.enum(['LineString']),
    coordinates: zod.array(zod.array(zod.number())).describe('Array of [lon, lat] coordinates'),
  }),
  dist: zod.number().optional(),
  ascend: zod.number().optional(),
})
