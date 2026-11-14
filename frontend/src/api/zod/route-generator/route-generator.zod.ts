import * as zod from 'zod'

/**
 * Proposes one to three routes, loops or one-way, whose every metre lies on a road that a route of the team already rides. Same rights as the route planner: the caller must be allowed to create routes in the team and the team must have its route planner on (ROUTE_PLANNER_DISABLED otherwise). Nothing is stored, no routing provider is called and no quota is drawn. Failures have their own codes, all 400: GENERATOR_START_TOO_FAR and GENERATOR_END_TOO_FAR (no road of the team within 2 km), GENERATOR_DISTANCE_TOO_SHORT, GENERATOR_NETWORK_TOO_SMALL (with RouteGeneratorNetworkDetails: also sent while the team's routes are still being analysed), GENERATOR_NETWORK_TOO_LARGE (the team's routes are more than the generator can hold in memory; no request succeeds until the limit is raised) and GENERATOR_NO_ROUTE. At most 30 requests per user in 15 minutes (ROUTE_GENERATOR_RATE_LIMITED, 429 with Retry-After); ROUTE_GENERATOR_BUSY (503) when the server has no free slot or the run took too long.
 * @summary Propose routes made of the team's own roads
 */
export const GenerateRoutesParams = zod.object({
  teamSlug: zod.string(),
})

export const generateRoutesBodyStartLngMin = -180
export const generateRoutesBodyStartLngMax = 180

export const generateRoutesBodyStartLatMin = -90
export const generateRoutesBodyStartLatMax = 90

export const generateRoutesBodyEndLngMin = -180
export const generateRoutesBodyEndLngMax = 180

export const generateRoutesBodyEndLatMin = -90
export const generateRoutesBodyEndLatMax = 90

export const generateRoutesBodyDistanceKmMin = 10
export const generateRoutesBodyDistanceKmMax = 300

export const generateRoutesBodyFamiliarityMin = 0
export const generateRoutesBodyFamiliarityMax = 1

export const GenerateRoutesBody = zod
  .object({
    start: zod
      .object({
        lng: zod.number().min(generateRoutesBodyStartLngMin).max(generateRoutesBodyStartLngMax),
        lat: zod.number().min(generateRoutesBodyStartLatMin).max(generateRoutesBodyStartLatMax),
      })
      .optional()
      .describe("Start. Absent: the team's location (400 VALIDATION if it has none)"),
    end: zod
      .object({
        lng: zod.number().min(generateRoutesBodyEndLngMin).max(generateRoutesBodyEndLngMax),
        lat: zod.number().min(generateRoutesBodyEndLatMin).max(generateRoutesBodyEndLatMax),
      })
      .optional()
      .describe(
        'End. Absent: a loop, the route ends where it starts. Present: a one-way route from start to end'
      ),
    bearing: zod
      .enum(['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'])
      .optional()
      .describe(
        'Wished direction, only used when the end is closer than half the distance (a loop included)'
      ),
    distanceKm: zod
      .number()
      .min(generateRoutesBodyDistanceKmMin)
      .max(generateRoutesBodyDistanceKmMax)
      .describe('Wished distance in kilometres, 10 to 300'),
    familiarity: zod
      .number()
      .min(generateRoutesBodyFamiliarityMin)
      .max(generateRoutesBodyFamiliarityMax)
      .optional()
      .describe('0 prefers roads the team rides rarely, 1 the ones it rides often. Absent: 0.5'),
    type: zod.enum(['ROAD', 'GRAVEL', 'MTB']).optional().describe('What to ride. Absent: ROAD'),
    seed: zod
      .int()
      .optional()
      .describe(
        'Makes "other proposals" reproducible: the same seed gives the same routes. Absent: 0'
      ),
  })
  .describe("What to ask the team's route generator for")

export const GenerateRoutesResponse = zod
  .object({
    candidates: zod
      .array(
        zod
          .object({
            polyline: zod
              .string()
              .describe(
                "Geometry as a polyline of precision 6 (latitude then longitude), the encoding of the planner's GPX import"
              ),
            distanceM: zod.number().describe('Distance in metres'),
            ascentM: zod.number().describe('Elevation gain in metres'),
            descentM: zod.number().describe('Elevation loss in metres'),
            bearingDeviationDeg: zod
              .number()
              .optional()
              .describe(
                "Angle in degrees between the wished bearing and the route's. Absent when the bearing did not apply"
              ),
            familiarity: zod.number().describe('How often the team rides these roads, 0 to 1'),
            unpavedShare: zod.number().describe('Share of the distance on unpaved roads, 0 to 1'),
            sharedM: zod
              .number()
              .describe('Metres ridden twice (the way to and from the loop), counted once'),
            crossings: zod
              .int()
              .describe('Junctions crossed more than once outside the shared part'),
            bounds: zod
              .object({
                minLon: zod.number().describe('Western edge'),
                minLat: zod.number().describe('Southern edge'),
                maxLon: zod.number().describe('Eastern edge'),
                maxLat: zod.number().describe('Northern edge'),
              })
              .describe('Map frame of the route'),
          })
          .describe('A route proposed by the generator, every metre of it on a team road')
      )
      .describe('One to three routes, best first, different from each other'),
    network: zod
      .object({
        lengthM: zod
          .number()
          .optional()
          .describe(
            'Length of the road the search can reach around the start and the end. Absent when no route was generated'
          ),
        totalLengthM: zod.number().describe('Length of the whole network of the team'),
        routeCount: zod.int().describe('Routes the network is made of'),
        pendingRouteCount: zod
          .int()
          .describe('Routes whose roads are still being analysed and are not in the network yet'),
        excludedRouteCount: zod
          .int()
          .describe('Routes ticked "ne pas utiliser pour générer des parcours"'),
        incomplete: zod
          .boolean()
          .describe('True when pendingRouteCount is above zero: the network may still grow'),
      })
      .describe("What the team's network is made of"),
    familiarityFallback: zod
      .boolean()
      .describe(
        'True when the team rides too few routes of the requested type nearby, so the familiarity of all kinds was used instead'
      ),
  })
  .describe("Routes proposed by the team's route generator")
