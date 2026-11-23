import * as zod from 'zod'

/**
 * Proposes one to three routes, loops or one-way, from the roads a route of the team already rides (prepared every night for the generator) and the rest of the map: the cursor `discovery` goes from the team's roads only (0) to no preference (1), default 0.25. The engine is osm-route-details and covers one region for now (GENERATOR_OUT_OF_COVERAGE elsewhere); each route was checked by an independent checker of the engine and by a geometric sanity check here. Ascent and descent are computed from the fast elevation profile and are absent when it was not ready in time. Same rights as the route planner: the caller must be allowed to create routes in the team and the team must have its route planner on (ROUTE_PLANNER_DISABLED otherwise). Nothing is stored, no routing provider is called and no quota is drawn. Failures have their own codes, all 400: GENERATOR_START_TOO_FAR and GENERATOR_END_TOO_FAR (no suitable road near), GENERATOR_DISTANCE_TOO_SHORT, GENERATOR_NETWORK_TOO_SMALL, GENERATOR_OUT_OF_COVERAGE, GENERATOR_NETWORK_NOT_READY (the team's roads are not prepared yet; discovery needs no preparation) and GENERATOR_NO_ROUTE. At most 30 requests per user in 15 minutes (ROUTE_GENERATOR_RATE_LIMITED, 429 with Retry-After); ROUTE_GENERATOR_BUSY (503) when the engine has no free slot or took too long, GENERATOR_UNAVAILABLE (503) when it is off or unreachable.
 * @summary Propose routes that favour the team's own roads
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
export const generateRoutesBodyDistanceKmMax = 200

export const generateRoutesBodyDiscoveryMin = 0
export const generateRoutesBodyDiscoveryMax = 1

export const generateRoutesBodySeedMin = 0

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
      .describe('Wished distance in kilometres, 10 to 200'),
    discovery: zod
      .number()
      .min(generateRoutesBodyDiscoveryMin)
      .max(generateRoutesBodyDiscoveryMax)
      .optional()
      .describe(
        "From the team's roads (0, only the roads the team rides) to discovery (1, no preference for them); rounded to the hundredth by the engine. Absent: 0.25"
      ),
    type: zod.enum(['ROAD', 'GRAVEL', 'MTB']).optional().describe('What to ride. Absent: ROAD'),
    seed: zod
      .int()
      .min(generateRoutesBodySeedMin)
      .optional()
      .describe(
        'Makes "other proposals" reproducible: the same seed gives the same routes. Absent: 0'
      ),
    unpaved: zod
      .enum(['LOW', 'USUAL', 'HIGH'])
      .optional()
      .describe(
        'How much of the route to ride off pavement: LOW, USUAL or HIGH. Only for GRAVEL and MTB, ignored for ROAD. Absent: USUAL'
      ),
  })
  .describe('What to ask the route generator for')

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
            ascentM: zod
              .number()
              .optional()
              .describe(
                'Elevation gain in metres. Absent when the profile was not ready in time: the editor computes it'
              ),
            descentM: zod
              .number()
              .optional()
              .describe('Elevation loss in metres. Absent like the gain'),
            bearingDeviationDeg: zod
              .number()
              .optional()
              .describe(
                "Angle in degrees between the wished bearing and the route's. Absent when the bearing did not apply"
              ),
            teamShare: zod
              .number()
              .describe(
                "Share of the distance on the team's roads, short gaps between them included, 0 to 1"
              ),
            unpavedShare: zod
              .number()
              .describe(
                'Share of the distance off pavement, 0 to 1, as the route page of a saved route measures it (surface tag, then track type, then road class)'
              ),
            unpavedTarget: zod
              .number()
              .optional()
              .describe(
                'The share of unpaved asked for, 0 to 1. Absent when no target was sent: a road ride, a request without it, or an engine that does not steer'
              ),
            unpavedTargetReached: zod
              .boolean()
              .optional()
              .describe(
                "Whether unpavedShare is within the engine's tolerance of unpavedTarget. Absent like unpavedTarget. False: the area has no better route, compare the two to tell more from less"
              ),
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
          .describe('A route proposed by the generator')
      )
      .describe('One to three routes, best first, different from each other'),
    networkPreparedAt: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        "When the team's roads were last prepared for the generator (the night before at best). Absent when the request did not use them (discovery)"
      ),
    partialCoverage: zod
      .boolean()
      .describe(
        'True when part of the area around the start leaves the region the generator covers: proposals are rarer there'
      ),
  })
  .describe('Routes proposed by the route generator')
