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

export const routeResponseUnpavedItemFromMin = 0

export const RouteResponse = zod.object({
  route: zod.object({
    type: zod.enum(['LineString']),
    coordinates: zod.array(zod.array(zod.number())).describe('Array of [lon, lat] coordinates'),
  }),
  dist: zod.number().optional(),
  ascend: zod.number().optional(),
  unpaved: zod
    .array(
      zod
        .object({
          from: zod.int().min(routeResponseUnpavedItemFromMin),
          to: zod.int().min(1),
        })
        .describe(
          'Half-open run of unpaved edges [from, to) of a line; edge i joins points i and i + 1'
        )
    )
    .optional()
    .describe(
      "Runs of unpaved edges of route (compacted surface or worse, from the router's own maneuvers), half-open, ascending and disjoint; edge i joins route points i and i + 1. Absent when the router gave no surface; empty when all paved"
    ),
})

/**
 * Processes each straight line with the FAST elevations, as a routed leg, and returns its densified track with the ascent accumulated up to each point. Nothing is stored and the routing provider is not called. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled.
 * @summary Read the relief of straight lines
 */
export const lineElevationBodyTeamSlugMax = 250

export const lineElevationBodyLinesItemFromLngMin = -180
export const lineElevationBodyLinesItemFromLngMax = 180

export const lineElevationBodyLinesItemFromLatMin = -90
export const lineElevationBodyLinesItemFromLatMax = 90

export const lineElevationBodyLinesItemToLngMin = -180
export const lineElevationBodyLinesItemToLngMax = 180

export const lineElevationBodyLinesItemToLatMin = -90
export const lineElevationBodyLinesItemToLatMax = 90

export const lineElevationBodyLinesMax = 50

export const LineElevationBody = zod.object({
  teamSlug: zod
    .string()
    .max(lineElevationBodyTeamSlugMax)
    .optional()
    .describe(
      "Slug of the team the route is being drawn for. When present, the team must have the route planner enabled and the caller must be allowed to create routes in it. When absent, the domain's GPX planner must be enabled."
    ),
  lines: zod
    .array(
      zod.object({
        from: zod.object({
          lng: zod
            .number()
            .min(lineElevationBodyLinesItemFromLngMin)
            .max(lineElevationBodyLinesItemFromLngMax),
          lat: zod
            .number()
            .min(lineElevationBodyLinesItemFromLatMin)
            .max(lineElevationBodyLinesItemFromLatMax),
        }),
        to: zod.object({
          lng: zod
            .number()
            .min(lineElevationBodyLinesItemToLngMin)
            .max(lineElevationBodyLinesItemToLngMax),
          lat: zod
            .number()
            .min(lineElevationBodyLinesItemToLatMin)
            .max(lineElevationBodyLinesItemToLatMax),
        }),
      })
    )
    .min(1)
    .max(lineElevationBodyLinesMax)
    .describe(
      'Straight lines to read the relief of, 1 to 50, at most 100 km each and 200 km together'
    ),
})

export const LineElevationResponse = zod
  .object({
    lines: zod
      .array(
        zod
          .object({
            line: zod
              .string()
              .describe(
                'Polyline (precision 6, latitude then longitude) of the processed track, as PlannerSource.line'
              ),
            ele: zod
              .string()
              .optional()
              .describe(
                'One-dimension polyline (tenths of a metre), one value per point of line; absent when an elevation is not finite'
              ),
            climb: zod
              .string()
              .optional()
              .describe(
                'One-dimension polyline (tenths of a metre): the ascent accumulated up to each point of line (dead-band, non-decreasing, first 0, last = ascend); absent when ele is'
              ),
            dist: zod.number().describe('Length in metres'),
            ascend: zod.number().describe('Reported ascent in metres'),
          })
          .describe('A track of an imported GPX file')
      )
      .describe('One track per requested line, in the same order, from its start to its end'),
    elevationFallback: zod
      .boolean()
      .describe('True when part of the elevations could not be read from the elevation source'),
  })
  .describe('The relief of straight lines, processed with the FAST elevations')

/**
 * Processes a GPX file with the FAST elevations and returns its tracks as polylines, with the ascent accumulated up to each point. Nothing is stored and the routing provider is not called. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled.
 * @summary Load a GPX file into the route editor
 */
export const importGpxBodyTeamSlugMax = 250

export const ImportGpxBody = zod.object({
  gpxFile: zod.instanceof(Blob).optional(),
  teamSlug: zod.string().max(importGpxBodyTeamSlugMax).optional(),
})

export const ImportGpxResponse = zod
  .object({
    name: zod
      .string()
      .describe('Name of the file: its metadata, else its first track, else its file name'),
    tracks: zod
      .array(
        zod
          .object({
            line: zod
              .string()
              .describe(
                'Polyline (precision 6, latitude then longitude) of the processed track, as PlannerSource.line'
              ),
            ele: zod
              .string()
              .optional()
              .describe(
                'One-dimension polyline (tenths of a metre), one value per point of line; absent when an elevation is not finite'
              ),
            climb: zod
              .string()
              .optional()
              .describe(
                'One-dimension polyline (tenths of a metre): the ascent accumulated up to each point of line (dead-band, non-decreasing, first 0, last = ascend); absent when ele is'
              ),
            dist: zod.number().describe('Length in metres'),
            ascend: zod.number().describe('Reported ascent in metres'),
          })
          .describe('A track of an imported GPX file')
      )
      .describe('Tracks in the order of the file, 1 to 8'),
    waypointCount: zod
      .int()
      .describe('Number of waypoints of the file, which the editor does not keep'),
    elevationFallback: zod
      .boolean()
      .describe(
        "True when the elevations of a track could not all be read from the elevation source and part of them are the file's own"
      ),
  })
  .describe('A GPX file processed for the route editor')
