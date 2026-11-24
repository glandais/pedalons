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

/**
 * Proposes one to three routes that change ONE stretch of the saved route and keep the rest as it was drawn, by asking the route generator's engine (osm-route-details): `targetDistanceKm` aims at a total distance (within the offer's bounds, 30 percent of the route at most), `end` moves the finish (a point, or a place of the team); exactly one of the two. Each proposal carries the whole polyline and the indices of the stretch that changed. Ascent and descent come from the same profile for the original (`originalAscentM`) and the proposals. Nothing is stored, no quota is drawn: the proposal is opened in the planner as a new route. Same rights as the route planner plus reading the route; the route's street edges must be computed for its current track (ROUTE_RETOUCH_NOT_READY otherwise: nothing is computed on the fly). Refusals are answers, all 400: ROUTE_RETOUCH_NO_SHORTER (shortening fails about four times in ten, a normal case), ROUTE_RETOUCH_NO_PROPOSAL, ROUTE_RETOUCH_ORDER_ANOMALY (about one track in twenty), ROUTE_RETOUCH_CHANGE_TOO_SMALL, ROUTE_RETOUCH_CHANGE_TOO_LARGE, ROUTE_RETOUCH_END_UNREACHABLE, ROUTE_RETOUCH_UNSUPPORTED, ROUTE_RETOUCH_NOT_READY, GENERATOR_END_TOO_FAR, GENERATOR_OUT_OF_COVERAGE. The 30 requests per 15 minutes of the route generator are shared (ROUTE_GENERATOR_RATE_LIMITED, 429 with Retry-After); ROUTE_GENERATOR_BUSY (503), GENERATOR_UNAVAILABLE (503, also when the engine does not announce route edits: nothing is sent to it).
 * @summary Propose changes to a saved route: a total distance, or a new finish
 */
export const RetouchRouteParams = zod.object({
  routeSlug: zod.string(),
  teamSlug: zod.string(),
})

export const retouchRouteBodyTargetDistanceKmMax = 1000

export const retouchRouteBodyEndPointLngMin = -180
export const retouchRouteBodyEndPointLngMax = 180

export const retouchRouteBodyEndPointLatMin = -90
export const retouchRouteBodyEndPointLatMax = 90

export const retouchRouteBodyDiscoveryMin = 0
export const retouchRouteBodyDiscoveryMax = 1

export const retouchRouteBodySeedMin = 0

export const RetouchRouteBody = zod
  .object({
    targetDistanceKm: zod
      .number()
      .min(1)
      .max(retouchRouteBodyTargetDistanceKmMax)
      .optional()
      .describe(
        "The total distance aimed at, in kilometres (not the change). The bounds of the field are the offer's (GET .../retouch): minDistanceKm to maxDistanceKm"
      ),
    end: zod
      .object({
        point: zod
          .object({
            lng: zod
              .number()
              .min(retouchRouteBodyEndPointLngMin)
              .max(retouchRouteBodyEndPointLngMax),
            lat: zod
              .number()
              .min(retouchRouteBodyEndPointLatMin)
              .max(retouchRouteBodyEndPointLatMax),
          })
          .optional()
          .describe('A position, e.g. a tap on the map'),
        placeId: zod
          .string()
          .optional()
          .describe(
            "A place of the route's team, by id: its position is the finish (400 VALIDATION on end.placeId when it is not one of the team's)"
          ),
      })
      .optional()
      .describe('The new finish'),
    discovery: zod
      .number()
      .min(retouchRouteBodyDiscoveryMin)
      .max(retouchRouteBodyDiscoveryMax)
      .optional()
      .describe(
        "From the team's roads (0) to discovery (1); rounded to the hundredth by the engine. Absent: 0.25"
      ),
    seed: zod
      .int()
      .min(retouchRouteBodySeedMin)
      .optional()
      .describe(
        'Makes "other proposals" reproducible: the same seed gives the same routes. Absent: 0'
      ),
  })
  .describe(
    'What to change in a saved route: exactly one of targetDistanceKm (aim at a total distance) and end (move the finish)'
  )

export const RetouchRouteResponse = zod
  .object({
    operation: zod.enum(['RESIZE', 'MOVE_END']).describe('The operation answered'),
    originalDistanceM: zod
      .number()
      .describe("Length of the original route's raw track in metres, the engine's own"),
    originalAscentM: zod
      .number()
      .optional()
      .describe(
        "Elevation gain of the original track, computed in the same batch as the proposals' so that before and after compare like with like"
      ),
    originalDescentM: zod.number().optional().describe('Elevation loss of the original track'),
    targetDistanceM: zod
      .number()
      .optional()
      .describe('RESIZE: the total distance asked, in metres'),
    candidates: zod
      .array(
        zod
          .object({
            polyline: zod
              .string()
              .describe(
                "The WHOLE retouched route as a polyline of precision 6 (latitude then longitude), the encoding of the planner's GPX import"
              ),
            distanceM: zod.number().describe('Distance in metres'),
            ascentM: zod
              .number()
              .optional()
              .describe(
                "Elevation gain in metres, measured as the original's (originalAscentM). Absent when the profile was not ready in time"
              ),
            descentM: zod
              .number()
              .optional()
              .describe('Elevation loss in metres. Absent like the gain'),
            kind: zod
              .enum(['SHORTEN', 'LENGTHEN', 'MOVE_END', 'TRUNCATE'])
              .describe('What changed'),
            variant: zod
              .enum(['BEST', 'KEEP_ALL', 'NEAREST'])
              .optional()
              .describe('Which choice a MOVE_END route makes. Absent for the others'),
            keptShare: zod
              .number()
              .describe('Share of the original route kept as it was drawn, 0 to 1'),
            unmatchedM: zod
              .number()
              .describe(
                'Metres of the kept parts that the engine could not match to its map: there, the route may ride a road twice and nothing was checked'
              ),
            endSnapM: zod
              .number()
              .optional()
              .describe(
                'MOVE_END and TRUNCATE: distance in metres from the asked finish to the last point of the route'
              ),
            changed: zod
              .object({
                fromM: zod
                  .number()
                  .describe(
                    'Where on the ORIGINAL route, in metres from its start, the replaced stretch begins'
                  ),
                toM: zod
                  .number()
                  .describe(
                    'Where on the original route the replaced stretch ends; its length for MOVE_END and TRUNCATE (the rest is dropped)'
                  ),
                newM: zod.number().describe('Length of the new stretch in metres, 0 for TRUNCATE'),
                startIndex: zod
                  .int()
                  .describe(
                    'Index in the polyline of the first point of the new stretch (up to it the polyline is the original route)'
                  ),
                endIndex: zod
                  .int()
                  .describe('Index in the polyline of the last point of the new stretch'),
                teamShare: zod
                  .number()
                  .describe(
                    "Share of the new stretch on the team's roads, 0 to 1 (measured on that stretch alone)"
                  ),
                unpavedShare: zod
                  .number()
                  .describe('Share of the new stretch off pavement, 0 to 1 (as the route page)'),
                crossings: zod.int().describe('Junctions the new stretch crosses more than once'),
              })
              .describe('The stretch that changed'),
            bounds: zod
              .object({
                minLon: zod.number().describe('Western edge'),
                minLat: zod.number().describe('Southern edge'),
                maxLon: zod.number().describe('Eastern edge'),
                maxLat: zod.number().describe('Northern edge'),
              })
              .describe('Map frame of the whole route'),
          })
          .describe("A route retouched by the generator's engine")
      )
      .describe('One to three proposals, best first'),
    networkPreparedAt: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        "When the team's roads were last prepared for the generator. Absent when the request did not use them (discovery)"
      ),
  })
  .describe('Proposals to retouch a saved route')

/**
 * Answers 200 whatever the outcome: `available` and, when not, `unavailableReason` (NOT_ALLOWED and ENGINE_UNAVAILABLE and UNSUPPORTED: show nothing; NOT_READY: the route's analysis is not finished, show the action disabled). The offer comes from the engine's capabilities (a generator engine that cannot edit offers nothing) and from the head of the route's stored documents: nothing is computed, the engine is not called and no request is counted. The route must be readable by the caller (404 otherwise).
 * @summary Whether a route can be retouched by the caller, and within which bounds
 */
export const GetRouteRetouchOfferParams = zod.object({
  routeSlug: zod.string(),
  teamSlug: zod.string(),
})

export const GetRouteRetouchOfferResponse = zod
  .object({
    available: zod.boolean().describe('The retouch can be asked for now'),
    unavailableReason: zod
      .enum(['NOT_ALLOWED', 'ENGINE_UNAVAILABLE', 'NOT_READY', 'UNSUPPORTED'])
      .optional()
      .describe(
        'Why not. NOT_ALLOWED and ENGINE_UNAVAILABLE: show nothing. NOT_READY: the route is still being analysed (show the action disabled). UNSUPPORTED: show nothing. Absent when available'
      ),
    operations: zod
      .array(zod.enum(['RESIZE', 'MOVE_END']))
      .describe('The operations offered; empty when not available'),
    originalDistanceM: zod
      .number()
      .optional()
      .describe("Length of the route's raw track in metres. Absent when not available"),
    minDistanceKm: zod
      .number()
      .optional()
      .describe('Smallest total distance of a RESIZE, in kilometres, rounded inwards to the tenth'),
    maxDistanceKm: zod
      .number()
      .optional()
      .describe('Largest total distance of a RESIZE, in kilometres, rounded inwards to the tenth'),
    minChangeKm: zod
      .number()
      .optional()
      .describe("Smallest change of a RESIZE, in kilometres, above or below the route's length"),
    maxChangeShare: zod
      .number()
      .optional()
      .describe("Largest change of a RESIZE as a share of the route's length, 0 to 1"),
    endSnapM: zod
      .number()
      .optional()
      .describe('How far from a way of the ride type the new finish may be, in metres'),
    proposalsMax: zod.int().optional().describe('Proposals returned at most'),
    rideType: zod
      .enum(['ROAD', 'GRAVEL', 'MTB'])
      .optional()
      .describe("The ride type the engine is asked for, from the route's surface type"),
  })
  .describe(
    "Whether a route can be retouched by the caller now, and within which bounds. Nothing is computed to answer: the engine's capabilities and the heads of the route's stored documents"
  )
