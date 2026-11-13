import * as zod from 'zod'

/**
 * Returns the current user's previews still within the 30-day retention window, most recent first
 * @summary List the current user's analysed GPX files
 */
export const listMyPreviewsQueryPageDefault = 0
export const listMyPreviewsQuerySizeDefault = 20

export const ListMyPreviewsQueryParams = zod.object({
  page: zod.int().default(listMyPreviewsQueryPageDefault).describe('Zero-based page number'),
  size: zod.int().default(listMyPreviewsQuerySizeDefault).describe('Page size'),
})

export const ListMyPreviewsResponse = zod
  .object({
    previews: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Public identifier used in URLs'),
            name: zod.string().describe('Track name'),
            distance: zod.number().describe('Distance in meters'),
            elevationGain: zod.number().describe('Total elevation gain in meters'),
            elevationLoss: zod.number().describe('Total elevation loss in meters'),
            hilliness: zod.number().describe('Elevation gain per kilometer'),
            createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
            departureTime: zod.iso
              .datetime({ offset: true })
              .optional()
              .describe(
                'Departure instant, when the person gave a date. The wall time at the start of the track is this instant in departureTimezone. Present together with departureTimezone'
              ),
            departureTimezone: zod
              .string()
              .optional()
              .describe(
                'IANA time zone of the first point of the track, the one the departure was entered in'
              ),
          })
          .describe('Summary of an analysed GPX file, for listing')
      )
      .describe('List of GPX previews'),
    total: zod.int().describe('Total number of previews'),
    page: zod.int().describe('Current page number'),
    size: zod.int().describe('Page size'),
  })
  .describe('Paginated GPX preview list response')

/**
 * Uploads a GPX file, runs the elevation and climb pipeline, and stores the result under an unguessable identifier for 30 days
 * @summary Analyse a GPX file
 */
export const CreatePreviewBody = zod.object({
  gpxFile: zod.instanceof(Blob).optional(),
  departure: zod.string().optional(),
  averageSpeed: zod.string().optional(),
})

export const CreatePreviewResponse = zod
  .object({
    id: zod.string().describe('Public identifier used in URLs'),
    name: zod.string().describe('Track name'),
    distance: zod.number().describe('Distance in meters'),
    elevationGain: zod.number().describe('Total elevation gain in meters'),
    elevationLoss: zod.number().describe('Total elevation loss in meters'),
    hilliness: zod.number().describe('Elevation gain per kilometer'),
    elevationState: zod
      .enum(['PENDING', 'HD', 'FAST'])
      .describe(
        'Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed.'
      ),
    owned: zod.boolean().describe('Whether the current user created this preview'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    thumbnailUrl: zod
      .string()
      .optional()
      .describe(
        'Rendered map thumbnail template URL (with a {size} placeholder), used for link previews; null when no thumbnail was generated. Opaque URL: may carry a query string; substitute {size} only.'
      ),
    gpxUrl: zod.string().describe('URL to download the analysed GPX file'),
    fitUrl: zod.string().describe('URL to download the analysed track as a FIT file'),
    drawn: zod
      .boolean()
      .describe(
        'Whether the track was drawn in the route planner (true) rather than imported from a GPX file. A drawn preview can only become a route of a team whose route planner is enabled; false when the origin is unknown'
      ),
    tracks: zod
      .array(
        zod
          .object({
            line: zod.object({
              type: zod.enum(['LineString']),
              coordinates: zod
                .array(zod.array(zod.number()))
                .describe(
                  "Array of [lon, lat] coordinates, followed by the elevation in metres when the line carries one ([lon, lat, ele]). A route track's geometry (TrackDto.line) adds a 4th component, [lon, lat, ele, dist]: the distance in metres from the start of THAT track, monotonic, restarting at 0 on each track of the route; it is not the distance along the whole route."
                ),
            }),
            climbs: zod
              .array(
                zod
                  .object({
                    startDistance: zod.int().describe('Start distance from route start in meters'),
                    endDistance: zod.int().describe('End distance from route start in meters'),
                    elevationGain: zod.int().describe('Elevation gain in meters'),
                    averageGradient: zod.number().describe('Average gradient percentage'),
                    maxGradient: zod.number().describe('Maximum gradient percentage'),
                    category: zod
                      .enum(['HC', 'CAT1', 'CAT2', 'CAT3', 'CAT4'])
                      .optional()
                      .describe('Climb category (HC, 1, 2, 3, 4)'),
                    parts: zod
                      .array(
                        zod
                          .object({
                            startDistance: zod
                              .int()
                              .describe('Start distance from route start in meters'),
                            endDistance: zod
                              .int()
                              .describe('End distance from route start in meters'),
                            elevationGain: zod.int().describe('Elevation gain in meters'),
                            grade: zod.number().describe('Gradient percentage'),
                          })
                          .describe('Climb part information')
                      )
                      .describe('Gradient segments making up the climb'),
                    name: zod
                      .string()
                      .optional()
                      .describe(
                        'Name of the climb: the route waypoint lying near its top (within 300 m), as the route\'s author named it in the GPX. Null when no waypoint marks the summit — clients then number the climb ("Climb N"). Never a geocoded guess.'
                      ),
                  })
                  .describe('Climb segment information')
              )
              .describe('List of climbs on the route'),
            surfaceState: zod
              .enum(['PENDING', 'READY', 'UNAVAILABLE'])
              .optional()
              .describe(
                'Where the surface of the track stands. Absent: never computed (a track saved before the feature, or the feature off), or not included (bulk endpoint with geometry=false, which carries no track)'
              ),
            surfaces: zod
              .array(
                zod
                  .object({
                    from: zod.number().describe('Start, metres along the track'),
                    to: zod.number().describe('End, metres along the track'),
                    surface: zod.enum([
                      'PAVED',
                      'PAVED_ROUGH',
                      'GRAVEL',
                      'DIRT',
                      'PATH',
                      'UNKNOWN',
                      'OFF_NETWORK',
                    ]),
                  })
                  .describe(
                    'A stretch of a track with one surface class, in metres along the track (the M of its line)'
                  )
              )
              .optional()
              .describe(
                "Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL), VersaTiles vector tiles"
              ),
          })
          .describe('GPX track with track points')
      )
      .describe('Tracks'),
    waypoints: zod
      .array(
        zod
          .object({
            geometry: zod
              .object({
                type: zod.enum(['Point']),
                coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
              })
              .describe('Location coordinates [longitude, latitude]'),
            name: zod.string().describe('Name, possibly empty'),
            id: zod
              .string()
              .optional()
              .describe(
                'Identifier (TSID) of the waypoint, to send back in the request so that it keeps its origin. Null for a waypoint of a GPX file not saved yet'
              ),
            type: zod
              .enum([
                'REGROUP',
                'SUPPLY',
                'WATER',
                'CAFE',
                'TOILETS',
                'DANGER',
                'SUMMIT',
                'VIEWPOINT',
                'BIKE_SHOP',
                'REAL_START',
                'SPLIT',
                'INFO',
              ])
              .describe('What the waypoint is'),
            description: zod.string().optional().describe('Free text, at most 500 characters'),
            distance: zod
              .number()
              .optional()
              .describe(
                'Metres from the start along the tracks in order (cumulated from one track to the next, in the order of their ids). Null for a waypoint more than 50 m from the track'
              ),
            origin: zod
              .enum(['AUTHOR', 'IMPORTED'])
              .describe(
                "Who put the waypoint: its AUTHOR in the editor, or a GPX file it was IMPORTED from. A new GPX file replaces the imported ones and keeps the author's"
              ),
          })
          .describe(
            'A waypoint of a route. Its geometry is where the author put it: its own position, never its projection on the track'
          )
      )
      .describe('Waypoints'),
    departureTime: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        'Departure instant, when the person gave a date. The wall time at the start of the track is this instant in departureTimezone. Present together with departureTimezone'
      ),
    departureTimezone: zod
      .string()
      .optional()
      .describe(
        'IANA time zone of the first point of the track, the one the departure was entered in'
      ),
    averageSpeed: zod
      .number()
      .optional()
      .describe(
        'Average speed in km/h the person gave, null when none (the weather then assumes 25 km/h)'
      ),
  })
  .describe('Analysed GPX file, not attached to any team')

/**
 * Builds a preview from a route drawn with the planner (no GPX file; drawn = true), runs the elevation and climb pipeline, and stores the result under an unguessable identifier for 30 days
 * @summary Create an analysed GPX file from planner points
 */
export const createPreviewFromPointsBodyNameMin = 3
export const createPreviewFromPointsBodyNameMax = 250

export const createPreviewFromPointsBodyNameRegExp = new RegExp('\\S')
export const createPreviewFromPointsBodyPointsItemLngMin = -180
export const createPreviewFromPointsBodyPointsItemLngMax = 180

export const createPreviewFromPointsBodyPointsItemLatMin = -90
export const createPreviewFromPointsBodyPointsItemLatMax = 90

export const createPreviewFromPointsBodyPointsMax = 100000

export const createPreviewFromPointsBodyPlannerStateSourcesItemLineMax = 2000000

export const createPreviewFromPointsBodyPlannerStateSourcesItemEleMax = 2000000

export const createPreviewFromPointsBodyPlannerStateSourcesItemClimbMax = 2000000

export const createPreviewFromPointsBodyPlannerStateSourcesItemShapeMax = 2000000

export const createPreviewFromPointsBodyPlannerStateSourcesMax = 8

export const createPreviewFromPointsBodyPlannerStateJunctionsMax = 2001

export const createPreviewFromPointsBodyPlannerStatePiecesItemLineMax = 2000000

export const createPreviewFromPointsBodyPlannerStatePiecesItemEleMax = 2000000

export const createPreviewFromPointsBodyPlannerStatePiecesItemUnpavedItemFromMin = 0

export const createPreviewFromPointsBodyPlannerStatePiecesItemUnpavedMax = 50000

export const createPreviewFromPointsBodyPlannerStatePiecesItemShapeMax = 2000000

export const createPreviewFromPointsBodyPlannerStatePiecesMax = 2000

export const createPreviewFromPointsBodyWaypointsItemPositionLngMin = -180
export const createPreviewFromPointsBodyWaypointsItemPositionLngMax = 180

export const createPreviewFromPointsBodyWaypointsItemPositionLatMin = -90
export const createPreviewFromPointsBodyWaypointsItemPositionLatMax = 90

export const createPreviewFromPointsBodyWaypointsItemNameMax = 250

export const createPreviewFromPointsBodyWaypointsItemDescriptionMax = 500

export const createPreviewFromPointsBodyWaypointsItemDistanceMin = 0

export const createPreviewFromPointsBodyWaypointsMax = 500

export const createPreviewFromPointsBodyAverageSpeedMin = 10
export const createPreviewFromPointsBodyAverageSpeedMax = 60

export const CreatePreviewFromPointsBody = zod
  .object({
    name: zod
      .string()
      .min(createPreviewFromPointsBodyNameMin)
      .max(createPreviewFromPointsBodyNameMax)
      .regex(createPreviewFromPointsBodyNameRegExp)
      .describe('Preview name'),
    points: zod
      .array(
        zod.object({
          lng: zod
            .number()
            .min(createPreviewFromPointsBodyPointsItemLngMin)
            .max(createPreviewFromPointsBodyPointsItemLngMax),
          lat: zod
            .number()
            .min(createPreviewFromPointsBodyPointsItemLatMin)
            .max(createPreviewFromPointsBodyPointsItemLatMax),
        })
      )
      .max(createPreviewFromPointsBodyPointsMax)
      .optional()
      .describe(
        'Points from frontend routing; points or plannerState, never both (400 PLANNER_STATE_INVALID), and one of them (400 GPX_EMPTY)'
      ),
    plannerState: zod
      .object({
        version: zod.int(),
        profile: zod.enum(['BIKE', 'FASTBIKE', 'GRAVEL', 'MTB', 'RUN_HIKE', 'MOTORCYCLE']),
        sources: zod
          .array(
            zod.object({
              line: zod
                .string()
                .max(createPreviewFromPointsBodyPlannerStateSourcesItemLineMax)
                .describe('Polyline (precision 6, latitude then longitude) of the source track'),
              ele: zod
                .string()
                .max(createPreviewFromPointsBodyPlannerStateSourcesItemEleMax)
                .optional()
                .describe(
                  'One-dimension polyline (tenths of a metre), one value per point of line; absent: no elevation'
                ),
              ascendScale: zod
                .number()
                .describe(
                  'Factor that recalibrates the raw climb of the source on a reference ascent (1 without reference); in ]0, 100]'
                ),
              climb: zod
                .string()
                .max(createPreviewFromPointsBodyPlannerStateSourcesItemClimbMax)
                .optional()
                .describe(
                  'One-dimension polyline (tenths of a metre), one value per point of line: the ascent accumulated up to each point, as the server measured it (dead-band, non-decreasing, within [0, 100 000 m]). Absent: the client derives it from ele. Requires ele'
                ),
              shape: zod
                .string()
                .max(createPreviewFromPointsBodyPlannerStateSourcesItemShapeMax)
                .optional()
                .describe(
                  'Polyline (precision 6, latitude then longitude) of the raw track of the file, as GpxImportTrack.shape gave it, never edited. An imported piece is cut out of it by projecting its junctions (from and to still index line); absent or inconsistent with line: line'
                ),
            })
          )
          .max(createPreviewFromPointsBodyPlannerStateSourcesMax),
        junctions: zod
          .array(
            zod.object({
              kind: zod.enum(['CONTROL', 'JOIN']),
              lng: zod.number(),
              lat: zod.number(),
              ele: zod.number().optional(),
              source: zod
                .int()
                .optional()
                .describe(
                  'Index of the source track this point comes from; with idx or not at all'
                ),
              idx: zod.int().optional().describe('Index of this point in that source track'),
            })
          )
          .max(createPreviewFromPointsBodyPlannerStateJunctionsMax),
        pieces: zod
          .array(
            zod.object({
              mode: zod.enum(['ROUTED', 'DIRECT', 'IMPORTED']),
              line: zod
                .string()
                .max(createPreviewFromPointsBodyPlannerStatePiecesItemLineMax)
                .optional()
                .describe('ROUTED and DIRECT: polyline6 of the points strictly inside the piece'),
              ele: zod
                .string()
                .max(createPreviewFromPointsBodyPlannerStatePiecesItemEleMax)
                .optional()
                .describe('ROUTED and DIRECT: one-dimension polyline of their elevations'),
              ascend: zod.number().optional().describe('ROUTED: climb of the piece in metres'),
              source: zod.int().optional().describe('IMPORTED: index of the source track'),
              from: zod
                .int()
                .optional()
                .describe('IMPORTED: index in the source of the first junction'),
              to: zod
                .int()
                .optional()
                .describe('IMPORTED: index in the source of the last junction'),
              unpaved: zod
                .array(
                  zod
                    .object({
                      from: zod
                        .int()
                        .min(createPreviewFromPointsBodyPlannerStatePiecesItemUnpavedItemFromMin),
                      to: zod.int().min(1),
                    })
                    .describe(
                      'Half-open run of unpaved edges [from, to) of a line; edge i joins points i and i + 1'
                    )
                )
                .max(createPreviewFromPointsBodyPlannerStatePiecesItemUnpavedMax)
                .optional()
                .describe(
                  'ROUTED: runs of unpaved edges of the piece, half-open, ascending and disjoint; edge 0 joins the first junction to the first interior point, the last edge ends at the last junction. Absent: surface unknown'
                ),
              shape: zod
                .string()
                .max(createPreviewFromPointsBodyPlannerStatePiecesItemShapeMax)
                .optional()
                .describe(
                  "ROUTED: polyline6 of the router's raw geometry of the piece, RouterResponse.shape as the router answered it, never edited (its two ends may be kept: a point within 1 m of a junction is dropped). The saved track is derived from it rather than from line; absent or inconsistent with line (ends over 50 m from the junctions, length off by over 20 % + 200 m): line. Unpaved spans keep indexing the edges of line"
                ),
            })
          )
          .max(createPreviewFromPointsBodyPlannerStatePiecesMax),
      })
      .optional()
      .describe(
        'Editing state of the planner; the server derives the track from it. Not with points'
      ),
    waypoints: zod
      .array(
        zod
          .object({
            id: zod
              .string()
              .optional()
              .describe(
                'Identifier of an existing waypoint, as returned by the API: it keeps its origin. Omitted or unknown: a new waypoint. Malformed or repeated: 400'
              ),
            position: zod
              .object({
                lng: zod
                  .number()
                  .min(createPreviewFromPointsBodyWaypointsItemPositionLngMin)
                  .max(createPreviewFromPointsBodyWaypointsItemPositionLngMax),
                lat: zod
                  .number()
                  .min(createPreviewFromPointsBodyWaypointsItemPositionLatMin)
                  .max(createPreviewFromPointsBodyWaypointsItemPositionLatMax),
              })
              .describe('Where the waypoint is'),
            type: zod
              .enum([
                'REGROUP',
                'SUPPLY',
                'WATER',
                'CAFE',
                'TOILETS',
                'DANGER',
                'SUMMIT',
                'VIEWPOINT',
                'BIKE_SHOP',
                'REAL_START',
                'SPLIT',
                'INFO',
              ])
              .describe('What the waypoint is'),
            name: zod
              .string()
              .max(createPreviewFromPointsBodyWaypointsItemNameMax)
              .describe(
                "Name, possibly empty (the type's label then shows on a device). The editor limits it to 40 characters; the API accepts what an import can bring, up to 250"
              ),
            description: zod
              .string()
              .max(createPreviewFromPointsBodyWaypointsItemDescriptionMax)
              .optional()
              .describe('Free text, at most 500 characters'),
            distance: zod
              .number()
              .min(createPreviewFromPointsBodyWaypointsItemDistanceMin)
              .optional()
              .describe(
                'The distance in metres the editor shows the waypoint at. Only used to pick which passage of a route that goes by twice the waypoint belongs to: the server recomputes the distance itself'
              ),
            origin: zod
              .enum(['AUTHOR', 'IMPORTED'])
              .optional()
              .describe(
                'Origin of a new waypoint, AUTHOR by default. Ignored for a waypoint that exists: it keeps its own'
              ),
          })
          .describe('A waypoint of a route, as sent by the editor')
      )
      .max(createPreviewFromPointsBodyWaypointsMax)
      .optional()
      .describe(
        'The complete list of the waypoints, replacing them. Omitted: they stay as they are (placed again when the track changes)'
      ),
    departure: zod
      .string()
      .optional()
      .describe(
        "Departure date and time, a wall time without offset, in the time zone of the first point of the track (not the device's). Present: the weather is computed when it falls within the next 7 days"
      ),
    averageSpeed: zod
      .number()
      .min(createPreviewFromPointsBodyAverageSpeedMin)
      .max(createPreviewFromPointsBodyAverageSpeedMax)
      .optional()
      .describe(
        'Average speed in km/h, 1 to 100, to estimate the passage times of the weather. Without one, 25 km/h is assumed'
      ),
  })
  .describe('GPX preview creation request from planner points')

export const CreatePreviewFromPointsResponse = zod
  .object({
    id: zod.string().describe('Public identifier used in URLs'),
    name: zod.string().describe('Track name'),
    distance: zod.number().describe('Distance in meters'),
    elevationGain: zod.number().describe('Total elevation gain in meters'),
    elevationLoss: zod.number().describe('Total elevation loss in meters'),
    hilliness: zod.number().describe('Elevation gain per kilometer'),
    elevationState: zod
      .enum(['PENDING', 'HD', 'FAST'])
      .describe(
        'Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed.'
      ),
    owned: zod.boolean().describe('Whether the current user created this preview'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    thumbnailUrl: zod
      .string()
      .optional()
      .describe(
        'Rendered map thumbnail template URL (with a {size} placeholder), used for link previews; null when no thumbnail was generated. Opaque URL: may carry a query string; substitute {size} only.'
      ),
    gpxUrl: zod.string().describe('URL to download the analysed GPX file'),
    fitUrl: zod.string().describe('URL to download the analysed track as a FIT file'),
    drawn: zod
      .boolean()
      .describe(
        'Whether the track was drawn in the route planner (true) rather than imported from a GPX file. A drawn preview can only become a route of a team whose route planner is enabled; false when the origin is unknown'
      ),
    tracks: zod
      .array(
        zod
          .object({
            line: zod.object({
              type: zod.enum(['LineString']),
              coordinates: zod
                .array(zod.array(zod.number()))
                .describe(
                  "Array of [lon, lat] coordinates, followed by the elevation in metres when the line carries one ([lon, lat, ele]). A route track's geometry (TrackDto.line) adds a 4th component, [lon, lat, ele, dist]: the distance in metres from the start of THAT track, monotonic, restarting at 0 on each track of the route; it is not the distance along the whole route."
                ),
            }),
            climbs: zod
              .array(
                zod
                  .object({
                    startDistance: zod.int().describe('Start distance from route start in meters'),
                    endDistance: zod.int().describe('End distance from route start in meters'),
                    elevationGain: zod.int().describe('Elevation gain in meters'),
                    averageGradient: zod.number().describe('Average gradient percentage'),
                    maxGradient: zod.number().describe('Maximum gradient percentage'),
                    category: zod
                      .enum(['HC', 'CAT1', 'CAT2', 'CAT3', 'CAT4'])
                      .optional()
                      .describe('Climb category (HC, 1, 2, 3, 4)'),
                    parts: zod
                      .array(
                        zod
                          .object({
                            startDistance: zod
                              .int()
                              .describe('Start distance from route start in meters'),
                            endDistance: zod
                              .int()
                              .describe('End distance from route start in meters'),
                            elevationGain: zod.int().describe('Elevation gain in meters'),
                            grade: zod.number().describe('Gradient percentage'),
                          })
                          .describe('Climb part information')
                      )
                      .describe('Gradient segments making up the climb'),
                    name: zod
                      .string()
                      .optional()
                      .describe(
                        'Name of the climb: the route waypoint lying near its top (within 300 m), as the route\'s author named it in the GPX. Null when no waypoint marks the summit — clients then number the climb ("Climb N"). Never a geocoded guess.'
                      ),
                  })
                  .describe('Climb segment information')
              )
              .describe('List of climbs on the route'),
            surfaceState: zod
              .enum(['PENDING', 'READY', 'UNAVAILABLE'])
              .optional()
              .describe(
                'Where the surface of the track stands. Absent: never computed (a track saved before the feature, or the feature off), or not included (bulk endpoint with geometry=false, which carries no track)'
              ),
            surfaces: zod
              .array(
                zod
                  .object({
                    from: zod.number().describe('Start, metres along the track'),
                    to: zod.number().describe('End, metres along the track'),
                    surface: zod.enum([
                      'PAVED',
                      'PAVED_ROUGH',
                      'GRAVEL',
                      'DIRT',
                      'PATH',
                      'UNKNOWN',
                      'OFF_NETWORK',
                    ]),
                  })
                  .describe(
                    'A stretch of a track with one surface class, in metres along the track (the M of its line)'
                  )
              )
              .optional()
              .describe(
                "Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL), VersaTiles vector tiles"
              ),
          })
          .describe('GPX track with track points')
      )
      .describe('Tracks'),
    waypoints: zod
      .array(
        zod
          .object({
            geometry: zod
              .object({
                type: zod.enum(['Point']),
                coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
              })
              .describe('Location coordinates [longitude, latitude]'),
            name: zod.string().describe('Name, possibly empty'),
            id: zod
              .string()
              .optional()
              .describe(
                'Identifier (TSID) of the waypoint, to send back in the request so that it keeps its origin. Null for a waypoint of a GPX file not saved yet'
              ),
            type: zod
              .enum([
                'REGROUP',
                'SUPPLY',
                'WATER',
                'CAFE',
                'TOILETS',
                'DANGER',
                'SUMMIT',
                'VIEWPOINT',
                'BIKE_SHOP',
                'REAL_START',
                'SPLIT',
                'INFO',
              ])
              .describe('What the waypoint is'),
            description: zod.string().optional().describe('Free text, at most 500 characters'),
            distance: zod
              .number()
              .optional()
              .describe(
                'Metres from the start along the tracks in order (cumulated from one track to the next, in the order of their ids). Null for a waypoint more than 50 m from the track'
              ),
            origin: zod
              .enum(['AUTHOR', 'IMPORTED'])
              .describe(
                "Who put the waypoint: its AUTHOR in the editor, or a GPX file it was IMPORTED from. A new GPX file replaces the imported ones and keeps the author's"
              ),
          })
          .describe(
            'A waypoint of a route. Its geometry is where the author put it: its own position, never its projection on the track'
          )
      )
      .describe('Waypoints'),
    departureTime: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        'Departure instant, when the person gave a date. The wall time at the start of the track is this instant in departureTimezone. Present together with departureTimezone'
      ),
    departureTimezone: zod
      .string()
      .optional()
      .describe(
        'IANA time zone of the first point of the track, the one the departure was entered in'
      ),
    averageSpeed: zod
      .number()
      .optional()
      .describe(
        'Average speed in km/h the person gave, null when none (the weather then assumes 25 km/h)'
      ),
  })
  .describe('Analysed GPX file, not attached to any team')

/**
 * Uploads 2 to 10 GPX files (10 MB together at most) and merges all their tracks into a single track, choosing the order of the tracks and the direction each one is ridden in so that the summed straight-line gaps between them are as short as possible. The result then runs the same pipeline as a single upload and is stored the same way, for 30 days
 * @summary Merge several GPX files into one analysed GPX file
 */
export const MergePreviewsBody = zod.object({
  gpxFiles: zod.array(zod.instanceof(Blob)).optional(),
  departure: zod.string().optional(),
  averageSpeed: zod.string().optional(),
})

export const MergePreviewsResponse = zod
  .object({
    id: zod.string().describe('Public identifier used in URLs'),
    name: zod.string().describe('Track name'),
    distance: zod.number().describe('Distance in meters'),
    elevationGain: zod.number().describe('Total elevation gain in meters'),
    elevationLoss: zod.number().describe('Total elevation loss in meters'),
    hilliness: zod.number().describe('Elevation gain per kilometer'),
    elevationState: zod
      .enum(['PENDING', 'HD', 'FAST'])
      .describe(
        'Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed.'
      ),
    owned: zod.boolean().describe('Whether the current user created this preview'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    thumbnailUrl: zod
      .string()
      .optional()
      .describe(
        'Rendered map thumbnail template URL (with a {size} placeholder), used for link previews; null when no thumbnail was generated. Opaque URL: may carry a query string; substitute {size} only.'
      ),
    gpxUrl: zod.string().describe('URL to download the analysed GPX file'),
    fitUrl: zod.string().describe('URL to download the analysed track as a FIT file'),
    drawn: zod
      .boolean()
      .describe(
        'Whether the track was drawn in the route planner (true) rather than imported from a GPX file. A drawn preview can only become a route of a team whose route planner is enabled; false when the origin is unknown'
      ),
    tracks: zod
      .array(
        zod
          .object({
            line: zod.object({
              type: zod.enum(['LineString']),
              coordinates: zod
                .array(zod.array(zod.number()))
                .describe(
                  "Array of [lon, lat] coordinates, followed by the elevation in metres when the line carries one ([lon, lat, ele]). A route track's geometry (TrackDto.line) adds a 4th component, [lon, lat, ele, dist]: the distance in metres from the start of THAT track, monotonic, restarting at 0 on each track of the route; it is not the distance along the whole route."
                ),
            }),
            climbs: zod
              .array(
                zod
                  .object({
                    startDistance: zod.int().describe('Start distance from route start in meters'),
                    endDistance: zod.int().describe('End distance from route start in meters'),
                    elevationGain: zod.int().describe('Elevation gain in meters'),
                    averageGradient: zod.number().describe('Average gradient percentage'),
                    maxGradient: zod.number().describe('Maximum gradient percentage'),
                    category: zod
                      .enum(['HC', 'CAT1', 'CAT2', 'CAT3', 'CAT4'])
                      .optional()
                      .describe('Climb category (HC, 1, 2, 3, 4)'),
                    parts: zod
                      .array(
                        zod
                          .object({
                            startDistance: zod
                              .int()
                              .describe('Start distance from route start in meters'),
                            endDistance: zod
                              .int()
                              .describe('End distance from route start in meters'),
                            elevationGain: zod.int().describe('Elevation gain in meters'),
                            grade: zod.number().describe('Gradient percentage'),
                          })
                          .describe('Climb part information')
                      )
                      .describe('Gradient segments making up the climb'),
                    name: zod
                      .string()
                      .optional()
                      .describe(
                        'Name of the climb: the route waypoint lying near its top (within 300 m), as the route\'s author named it in the GPX. Null when no waypoint marks the summit — clients then number the climb ("Climb N"). Never a geocoded guess.'
                      ),
                  })
                  .describe('Climb segment information')
              )
              .describe('List of climbs on the route'),
            surfaceState: zod
              .enum(['PENDING', 'READY', 'UNAVAILABLE'])
              .optional()
              .describe(
                'Where the surface of the track stands. Absent: never computed (a track saved before the feature, or the feature off), or not included (bulk endpoint with geometry=false, which carries no track)'
              ),
            surfaces: zod
              .array(
                zod
                  .object({
                    from: zod.number().describe('Start, metres along the track'),
                    to: zod.number().describe('End, metres along the track'),
                    surface: zod.enum([
                      'PAVED',
                      'PAVED_ROUGH',
                      'GRAVEL',
                      'DIRT',
                      'PATH',
                      'UNKNOWN',
                      'OFF_NETWORK',
                    ]),
                  })
                  .describe(
                    'A stretch of a track with one surface class, in metres along the track (the M of its line)'
                  )
              )
              .optional()
              .describe(
                "Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL), VersaTiles vector tiles"
              ),
          })
          .describe('GPX track with track points')
      )
      .describe('Tracks'),
    waypoints: zod
      .array(
        zod
          .object({
            geometry: zod
              .object({
                type: zod.enum(['Point']),
                coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
              })
              .describe('Location coordinates [longitude, latitude]'),
            name: zod.string().describe('Name, possibly empty'),
            id: zod
              .string()
              .optional()
              .describe(
                'Identifier (TSID) of the waypoint, to send back in the request so that it keeps its origin. Null for a waypoint of a GPX file not saved yet'
              ),
            type: zod
              .enum([
                'REGROUP',
                'SUPPLY',
                'WATER',
                'CAFE',
                'TOILETS',
                'DANGER',
                'SUMMIT',
                'VIEWPOINT',
                'BIKE_SHOP',
                'REAL_START',
                'SPLIT',
                'INFO',
              ])
              .describe('What the waypoint is'),
            description: zod.string().optional().describe('Free text, at most 500 characters'),
            distance: zod
              .number()
              .optional()
              .describe(
                'Metres from the start along the tracks in order (cumulated from one track to the next, in the order of their ids). Null for a waypoint more than 50 m from the track'
              ),
            origin: zod
              .enum(['AUTHOR', 'IMPORTED'])
              .describe(
                "Who put the waypoint: its AUTHOR in the editor, or a GPX file it was IMPORTED from. A new GPX file replaces the imported ones and keeps the author's"
              ),
          })
          .describe(
            'A waypoint of a route. Its geometry is where the author put it: its own position, never its projection on the track'
          )
      )
      .describe('Waypoints'),
    departureTime: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        'Departure instant, when the person gave a date. The wall time at the start of the track is this instant in departureTimezone. Present together with departureTimezone'
      ),
    departureTimezone: zod
      .string()
      .optional()
      .describe(
        'IANA time zone of the first point of the track, the one the departure was entered in'
      ),
    averageSpeed: zod
      .number()
      .optional()
      .describe(
        'Average speed in km/h the person gave, null when none (the weather then assumes 25 km/h)'
      ),
  })
  .describe('Analysed GPX file, not attached to any team')

/**
 * Rename the preview and, when a new GPX file or planner points are provided, replay the pipeline to replace its track. Only the creator may edit.
 * @summary Update an analysed GPX file
 */
export const UpdatePreviewParams = zod.object({
  previewId: zod.string().describe('Public preview identifier'),
})

export const updatePreviewBodyPreviewNameMin = 3
export const updatePreviewBodyPreviewNameMax = 250

export const updatePreviewBodyPreviewNameRegExp = new RegExp('\\S')
export const updatePreviewBodyPreviewPointsItemLngMin = -180
export const updatePreviewBodyPreviewPointsItemLngMax = 180

export const updatePreviewBodyPreviewPointsItemLatMin = -90
export const updatePreviewBodyPreviewPointsItemLatMax = 90

export const updatePreviewBodyPreviewPointsMax = 100000

export const updatePreviewBodyPreviewPlannerStateSourcesItemLineMax = 2000000

export const updatePreviewBodyPreviewPlannerStateSourcesItemEleMax = 2000000

export const updatePreviewBodyPreviewPlannerStateSourcesItemClimbMax = 2000000

export const updatePreviewBodyPreviewPlannerStateSourcesItemShapeMax = 2000000

export const updatePreviewBodyPreviewPlannerStateSourcesMax = 8

export const updatePreviewBodyPreviewPlannerStateJunctionsMax = 2001

export const updatePreviewBodyPreviewPlannerStatePiecesItemLineMax = 2000000

export const updatePreviewBodyPreviewPlannerStatePiecesItemEleMax = 2000000

export const updatePreviewBodyPreviewPlannerStatePiecesItemUnpavedItemFromMin = 0

export const updatePreviewBodyPreviewPlannerStatePiecesItemUnpavedMax = 50000

export const updatePreviewBodyPreviewPlannerStatePiecesItemShapeMax = 2000000

export const updatePreviewBodyPreviewPlannerStatePiecesMax = 2000

export const updatePreviewBodyPreviewWaypointsItemPositionLngMin = -180
export const updatePreviewBodyPreviewWaypointsItemPositionLngMax = 180

export const updatePreviewBodyPreviewWaypointsItemPositionLatMin = -90
export const updatePreviewBodyPreviewWaypointsItemPositionLatMax = 90

export const updatePreviewBodyPreviewWaypointsItemNameMax = 250

export const updatePreviewBodyPreviewWaypointsItemDescriptionMax = 500

export const updatePreviewBodyPreviewWaypointsItemDistanceMin = 0

export const updatePreviewBodyPreviewWaypointsMax = 500

export const updatePreviewBodyPreviewAverageSpeedMin = 10
export const updatePreviewBodyPreviewAverageSpeedMax = 60

export const UpdatePreviewBody = zod.object({
  preview: zod
    .object({
      name: zod
        .string()
        .min(updatePreviewBodyPreviewNameMin)
        .max(updatePreviewBodyPreviewNameMax)
        .regex(updatePreviewBodyPreviewNameRegExp)
        .describe('Preview name'),
      points: zod
        .array(
          zod.object({
            lng: zod
              .number()
              .min(updatePreviewBodyPreviewPointsItemLngMin)
              .max(updatePreviewBodyPreviewPointsItemLngMax),
            lat: zod
              .number()
              .min(updatePreviewBodyPreviewPointsItemLatMin)
              .max(updatePreviewBodyPreviewPointsItemLatMax),
          })
        )
        .max(updatePreviewBodyPreviewPointsMax)
        .optional()
        .describe('Points from frontend routing'),
      plannerState: zod
        .object({
          version: zod.int(),
          profile: zod.enum(['BIKE', 'FASTBIKE', 'GRAVEL', 'MTB', 'RUN_HIKE', 'MOTORCYCLE']),
          sources: zod
            .array(
              zod.object({
                line: zod
                  .string()
                  .max(updatePreviewBodyPreviewPlannerStateSourcesItemLineMax)
                  .describe('Polyline (precision 6, latitude then longitude) of the source track'),
                ele: zod
                  .string()
                  .max(updatePreviewBodyPreviewPlannerStateSourcesItemEleMax)
                  .optional()
                  .describe(
                    'One-dimension polyline (tenths of a metre), one value per point of line; absent: no elevation'
                  ),
                ascendScale: zod
                  .number()
                  .describe(
                    'Factor that recalibrates the raw climb of the source on a reference ascent (1 without reference); in ]0, 100]'
                  ),
                climb: zod
                  .string()
                  .max(updatePreviewBodyPreviewPlannerStateSourcesItemClimbMax)
                  .optional()
                  .describe(
                    'One-dimension polyline (tenths of a metre), one value per point of line: the ascent accumulated up to each point, as the server measured it (dead-band, non-decreasing, within [0, 100 000 m]). Absent: the client derives it from ele. Requires ele'
                  ),
                shape: zod
                  .string()
                  .max(updatePreviewBodyPreviewPlannerStateSourcesItemShapeMax)
                  .optional()
                  .describe(
                    'Polyline (precision 6, latitude then longitude) of the raw track of the file, as GpxImportTrack.shape gave it, never edited. An imported piece is cut out of it by projecting its junctions (from and to still index line); absent or inconsistent with line: line'
                  ),
              })
            )
            .max(updatePreviewBodyPreviewPlannerStateSourcesMax),
          junctions: zod
            .array(
              zod.object({
                kind: zod.enum(['CONTROL', 'JOIN']),
                lng: zod.number(),
                lat: zod.number(),
                ele: zod.number().optional(),
                source: zod
                  .int()
                  .optional()
                  .describe(
                    'Index of the source track this point comes from; with idx or not at all'
                  ),
                idx: zod.int().optional().describe('Index of this point in that source track'),
              })
            )
            .max(updatePreviewBodyPreviewPlannerStateJunctionsMax),
          pieces: zod
            .array(
              zod.object({
                mode: zod.enum(['ROUTED', 'DIRECT', 'IMPORTED']),
                line: zod
                  .string()
                  .max(updatePreviewBodyPreviewPlannerStatePiecesItemLineMax)
                  .optional()
                  .describe('ROUTED and DIRECT: polyline6 of the points strictly inside the piece'),
                ele: zod
                  .string()
                  .max(updatePreviewBodyPreviewPlannerStatePiecesItemEleMax)
                  .optional()
                  .describe('ROUTED and DIRECT: one-dimension polyline of their elevations'),
                ascend: zod.number().optional().describe('ROUTED: climb of the piece in metres'),
                source: zod.int().optional().describe('IMPORTED: index of the source track'),
                from: zod
                  .int()
                  .optional()
                  .describe('IMPORTED: index in the source of the first junction'),
                to: zod
                  .int()
                  .optional()
                  .describe('IMPORTED: index in the source of the last junction'),
                unpaved: zod
                  .array(
                    zod
                      .object({
                        from: zod
                          .int()
                          .min(updatePreviewBodyPreviewPlannerStatePiecesItemUnpavedItemFromMin),
                        to: zod.int().min(1),
                      })
                      .describe(
                        'Half-open run of unpaved edges [from, to) of a line; edge i joins points i and i + 1'
                      )
                  )
                  .max(updatePreviewBodyPreviewPlannerStatePiecesItemUnpavedMax)
                  .optional()
                  .describe(
                    'ROUTED: runs of unpaved edges of the piece, half-open, ascending and disjoint; edge 0 joins the first junction to the first interior point, the last edge ends at the last junction. Absent: surface unknown'
                  ),
                shape: zod
                  .string()
                  .max(updatePreviewBodyPreviewPlannerStatePiecesItemShapeMax)
                  .optional()
                  .describe(
                    "ROUTED: polyline6 of the router's raw geometry of the piece, RouterResponse.shape as the router answered it, never edited (its two ends may be kept: a point within 1 m of a junction is dropped). The saved track is derived from it rather than from line; absent or inconsistent with line (ends over 50 m from the junctions, length off by over 20 % + 200 m): line. Unpaved spans keep indexing the edges of line"
                  ),
              })
            )
            .max(updatePreviewBodyPreviewPlannerStatePiecesMax),
        })
        .optional()
        .describe(
          'Editing state of the planner; the server derives the track from it. Not with points (400 PLANNER_STATE_INVALID); a gpxFile wins over it'
        ),
      waypoints: zod
        .array(
          zod
            .object({
              id: zod
                .string()
                .optional()
                .describe(
                  'Identifier of an existing waypoint, as returned by the API: it keeps its origin. Omitted or unknown: a new waypoint. Malformed or repeated: 400'
                ),
              position: zod
                .object({
                  lng: zod
                    .number()
                    .min(updatePreviewBodyPreviewWaypointsItemPositionLngMin)
                    .max(updatePreviewBodyPreviewWaypointsItemPositionLngMax),
                  lat: zod
                    .number()
                    .min(updatePreviewBodyPreviewWaypointsItemPositionLatMin)
                    .max(updatePreviewBodyPreviewWaypointsItemPositionLatMax),
                })
                .describe('Where the waypoint is'),
              type: zod
                .enum([
                  'REGROUP',
                  'SUPPLY',
                  'WATER',
                  'CAFE',
                  'TOILETS',
                  'DANGER',
                  'SUMMIT',
                  'VIEWPOINT',
                  'BIKE_SHOP',
                  'REAL_START',
                  'SPLIT',
                  'INFO',
                ])
                .describe('What the waypoint is'),
              name: zod
                .string()
                .max(updatePreviewBodyPreviewWaypointsItemNameMax)
                .describe(
                  "Name, possibly empty (the type's label then shows on a device). The editor limits it to 40 characters; the API accepts what an import can bring, up to 250"
                ),
              description: zod
                .string()
                .max(updatePreviewBodyPreviewWaypointsItemDescriptionMax)
                .optional()
                .describe('Free text, at most 500 characters'),
              distance: zod
                .number()
                .min(updatePreviewBodyPreviewWaypointsItemDistanceMin)
                .optional()
                .describe(
                  'The distance in metres the editor shows the waypoint at. Only used to pick which passage of a route that goes by twice the waypoint belongs to: the server recomputes the distance itself'
                ),
              origin: zod
                .enum(['AUTHOR', 'IMPORTED'])
                .optional()
                .describe(
                  'Origin of a new waypoint, AUTHOR by default. Ignored for a waypoint that exists: it keeps its own'
                ),
            })
            .describe('A waypoint of a route, as sent by the editor')
        )
        .max(updatePreviewBodyPreviewWaypointsMax)
        .optional()
        .describe(
          'The complete list of the waypoints, replacing them. Omitted: they stay as they are (placed again when the track changes)'
        ),
      departure: zod
        .string()
        .optional()
        .describe(
          "Departure date and time, a wall time without offset, in the time zone of the first point of the track (not the device's). Omitted: kept (it follows the track if that moves to another zone). Present: the weather is computed when it falls within the next 7 days"
        ),
      clearDeparture: zod
        .boolean()
        .optional()
        .describe('Remove the departure date. Not with departure (400 BAD_REQUEST)'),
      averageSpeed: zod
        .number()
        .min(updatePreviewBodyPreviewAverageSpeedMin)
        .max(updatePreviewBodyPreviewAverageSpeedMax)
        .optional()
        .describe(
          'Average speed in km/h, 1 to 100, to estimate the passage times of the weather. Omitted: kept. Without one, 25 km/h is assumed'
        ),
      clearAverageSpeed: zod
        .boolean()
        .optional()
        .describe('Remove the average speed. Not with averageSpeed (400 BAD_REQUEST)'),
    })
    .optional()
    .describe('GPX preview update request'),
  gpxFile: zod.instanceof(Blob).optional(),
})

export const UpdatePreviewResponse = zod
  .object({
    id: zod.string().describe('Public identifier used in URLs'),
    name: zod.string().describe('Track name'),
    distance: zod.number().describe('Distance in meters'),
    elevationGain: zod.number().describe('Total elevation gain in meters'),
    elevationLoss: zod.number().describe('Total elevation loss in meters'),
    hilliness: zod.number().describe('Elevation gain per kilometer'),
    elevationState: zod
      .enum(['PENDING', 'HD', 'FAST'])
      .describe(
        'Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed.'
      ),
    owned: zod.boolean().describe('Whether the current user created this preview'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    thumbnailUrl: zod
      .string()
      .optional()
      .describe(
        'Rendered map thumbnail template URL (with a {size} placeholder), used for link previews; null when no thumbnail was generated. Opaque URL: may carry a query string; substitute {size} only.'
      ),
    gpxUrl: zod.string().describe('URL to download the analysed GPX file'),
    fitUrl: zod.string().describe('URL to download the analysed track as a FIT file'),
    drawn: zod
      .boolean()
      .describe(
        'Whether the track was drawn in the route planner (true) rather than imported from a GPX file. A drawn preview can only become a route of a team whose route planner is enabled; false when the origin is unknown'
      ),
    tracks: zod
      .array(
        zod
          .object({
            line: zod.object({
              type: zod.enum(['LineString']),
              coordinates: zod
                .array(zod.array(zod.number()))
                .describe(
                  "Array of [lon, lat] coordinates, followed by the elevation in metres when the line carries one ([lon, lat, ele]). A route track's geometry (TrackDto.line) adds a 4th component, [lon, lat, ele, dist]: the distance in metres from the start of THAT track, monotonic, restarting at 0 on each track of the route; it is not the distance along the whole route."
                ),
            }),
            climbs: zod
              .array(
                zod
                  .object({
                    startDistance: zod.int().describe('Start distance from route start in meters'),
                    endDistance: zod.int().describe('End distance from route start in meters'),
                    elevationGain: zod.int().describe('Elevation gain in meters'),
                    averageGradient: zod.number().describe('Average gradient percentage'),
                    maxGradient: zod.number().describe('Maximum gradient percentage'),
                    category: zod
                      .enum(['HC', 'CAT1', 'CAT2', 'CAT3', 'CAT4'])
                      .optional()
                      .describe('Climb category (HC, 1, 2, 3, 4)'),
                    parts: zod
                      .array(
                        zod
                          .object({
                            startDistance: zod
                              .int()
                              .describe('Start distance from route start in meters'),
                            endDistance: zod
                              .int()
                              .describe('End distance from route start in meters'),
                            elevationGain: zod.int().describe('Elevation gain in meters'),
                            grade: zod.number().describe('Gradient percentage'),
                          })
                          .describe('Climb part information')
                      )
                      .describe('Gradient segments making up the climb'),
                    name: zod
                      .string()
                      .optional()
                      .describe(
                        'Name of the climb: the route waypoint lying near its top (within 300 m), as the route\'s author named it in the GPX. Null when no waypoint marks the summit — clients then number the climb ("Climb N"). Never a geocoded guess.'
                      ),
                  })
                  .describe('Climb segment information')
              )
              .describe('List of climbs on the route'),
            surfaceState: zod
              .enum(['PENDING', 'READY', 'UNAVAILABLE'])
              .optional()
              .describe(
                'Where the surface of the track stands. Absent: never computed (a track saved before the feature, or the feature off), or not included (bulk endpoint with geometry=false, which carries no track)'
              ),
            surfaces: zod
              .array(
                zod
                  .object({
                    from: zod.number().describe('Start, metres along the track'),
                    to: zod.number().describe('End, metres along the track'),
                    surface: zod.enum([
                      'PAVED',
                      'PAVED_ROUGH',
                      'GRAVEL',
                      'DIRT',
                      'PATH',
                      'UNKNOWN',
                      'OFF_NETWORK',
                    ]),
                  })
                  .describe(
                    'A stretch of a track with one surface class, in metres along the track (the M of its line)'
                  )
              )
              .optional()
              .describe(
                "Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL), VersaTiles vector tiles"
              ),
          })
          .describe('GPX track with track points')
      )
      .describe('Tracks'),
    waypoints: zod
      .array(
        zod
          .object({
            geometry: zod
              .object({
                type: zod.enum(['Point']),
                coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
              })
              .describe('Location coordinates [longitude, latitude]'),
            name: zod.string().describe('Name, possibly empty'),
            id: zod
              .string()
              .optional()
              .describe(
                'Identifier (TSID) of the waypoint, to send back in the request so that it keeps its origin. Null for a waypoint of a GPX file not saved yet'
              ),
            type: zod
              .enum([
                'REGROUP',
                'SUPPLY',
                'WATER',
                'CAFE',
                'TOILETS',
                'DANGER',
                'SUMMIT',
                'VIEWPOINT',
                'BIKE_SHOP',
                'REAL_START',
                'SPLIT',
                'INFO',
              ])
              .describe('What the waypoint is'),
            description: zod.string().optional().describe('Free text, at most 500 characters'),
            distance: zod
              .number()
              .optional()
              .describe(
                'Metres from the start along the tracks in order (cumulated from one track to the next, in the order of their ids). Null for a waypoint more than 50 m from the track'
              ),
            origin: zod
              .enum(['AUTHOR', 'IMPORTED'])
              .describe(
                "Who put the waypoint: its AUTHOR in the editor, or a GPX file it was IMPORTED from. A new GPX file replaces the imported ones and keeps the author's"
              ),
          })
          .describe(
            'A waypoint of a route. Its geometry is where the author put it: its own position, never its projection on the track'
          )
      )
      .describe('Waypoints'),
    departureTime: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        'Departure instant, when the person gave a date. The wall time at the start of the track is this instant in departureTimezone. Present together with departureTimezone'
      ),
    departureTimezone: zod
      .string()
      .optional()
      .describe(
        'IANA time zone of the first point of the track, the one the departure was entered in'
      ),
    averageSpeed: zod
      .number()
      .optional()
      .describe(
        'Average speed in km/h the person gave, null when none (the weather then assumes 25 km/h)'
      ),
  })
  .describe('Analysed GPX file, not attached to any team')

/**
 * Anyone holding the link may read the preview: the unguessable identifier is what grants access. Creating and deleting require an account.
 * @summary Get an analysed GPX file
 */
export const GetPreviewParams = zod.object({
  previewId: zod.string().describe('Public preview identifier'),
})

export const GetPreviewResponse = zod
  .object({
    id: zod.string().describe('Public identifier used in URLs'),
    name: zod.string().describe('Track name'),
    distance: zod.number().describe('Distance in meters'),
    elevationGain: zod.number().describe('Total elevation gain in meters'),
    elevationLoss: zod.number().describe('Total elevation loss in meters'),
    hilliness: zod.number().describe('Elevation gain per kilometer'),
    elevationState: zod
      .enum(['PENDING', 'HD', 'FAST'])
      .describe(
        'Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed.'
      ),
    owned: zod.boolean().describe('Whether the current user created this preview'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    thumbnailUrl: zod
      .string()
      .optional()
      .describe(
        'Rendered map thumbnail template URL (with a {size} placeholder), used for link previews; null when no thumbnail was generated. Opaque URL: may carry a query string; substitute {size} only.'
      ),
    gpxUrl: zod.string().describe('URL to download the analysed GPX file'),
    fitUrl: zod.string().describe('URL to download the analysed track as a FIT file'),
    drawn: zod
      .boolean()
      .describe(
        'Whether the track was drawn in the route planner (true) rather than imported from a GPX file. A drawn preview can only become a route of a team whose route planner is enabled; false when the origin is unknown'
      ),
    tracks: zod
      .array(
        zod
          .object({
            line: zod.object({
              type: zod.enum(['LineString']),
              coordinates: zod
                .array(zod.array(zod.number()))
                .describe(
                  "Array of [lon, lat] coordinates, followed by the elevation in metres when the line carries one ([lon, lat, ele]). A route track's geometry (TrackDto.line) adds a 4th component, [lon, lat, ele, dist]: the distance in metres from the start of THAT track, monotonic, restarting at 0 on each track of the route; it is not the distance along the whole route."
                ),
            }),
            climbs: zod
              .array(
                zod
                  .object({
                    startDistance: zod.int().describe('Start distance from route start in meters'),
                    endDistance: zod.int().describe('End distance from route start in meters'),
                    elevationGain: zod.int().describe('Elevation gain in meters'),
                    averageGradient: zod.number().describe('Average gradient percentage'),
                    maxGradient: zod.number().describe('Maximum gradient percentage'),
                    category: zod
                      .enum(['HC', 'CAT1', 'CAT2', 'CAT3', 'CAT4'])
                      .optional()
                      .describe('Climb category (HC, 1, 2, 3, 4)'),
                    parts: zod
                      .array(
                        zod
                          .object({
                            startDistance: zod
                              .int()
                              .describe('Start distance from route start in meters'),
                            endDistance: zod
                              .int()
                              .describe('End distance from route start in meters'),
                            elevationGain: zod.int().describe('Elevation gain in meters'),
                            grade: zod.number().describe('Gradient percentage'),
                          })
                          .describe('Climb part information')
                      )
                      .describe('Gradient segments making up the climb'),
                    name: zod
                      .string()
                      .optional()
                      .describe(
                        'Name of the climb: the route waypoint lying near its top (within 300 m), as the route\'s author named it in the GPX. Null when no waypoint marks the summit — clients then number the climb ("Climb N"). Never a geocoded guess.'
                      ),
                  })
                  .describe('Climb segment information')
              )
              .describe('List of climbs on the route'),
            surfaceState: zod
              .enum(['PENDING', 'READY', 'UNAVAILABLE'])
              .optional()
              .describe(
                'Where the surface of the track stands. Absent: never computed (a track saved before the feature, or the feature off), or not included (bulk endpoint with geometry=false, which carries no track)'
              ),
            surfaces: zod
              .array(
                zod
                  .object({
                    from: zod.number().describe('Start, metres along the track'),
                    to: zod.number().describe('End, metres along the track'),
                    surface: zod.enum([
                      'PAVED',
                      'PAVED_ROUGH',
                      'GRAVEL',
                      'DIRT',
                      'PATH',
                      'UNKNOWN',
                      'OFF_NETWORK',
                    ]),
                  })
                  .describe(
                    'A stretch of a track with one surface class, in metres along the track (the M of its line)'
                  )
              )
              .optional()
              .describe(
                "Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL), VersaTiles vector tiles"
              ),
          })
          .describe('GPX track with track points')
      )
      .describe('Tracks'),
    waypoints: zod
      .array(
        zod
          .object({
            geometry: zod
              .object({
                type: zod.enum(['Point']),
                coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
              })
              .describe('Location coordinates [longitude, latitude]'),
            name: zod.string().describe('Name, possibly empty'),
            id: zod
              .string()
              .optional()
              .describe(
                'Identifier (TSID) of the waypoint, to send back in the request so that it keeps its origin. Null for a waypoint of a GPX file not saved yet'
              ),
            type: zod
              .enum([
                'REGROUP',
                'SUPPLY',
                'WATER',
                'CAFE',
                'TOILETS',
                'DANGER',
                'SUMMIT',
                'VIEWPOINT',
                'BIKE_SHOP',
                'REAL_START',
                'SPLIT',
                'INFO',
              ])
              .describe('What the waypoint is'),
            description: zod.string().optional().describe('Free text, at most 500 characters'),
            distance: zod
              .number()
              .optional()
              .describe(
                'Metres from the start along the tracks in order (cumulated from one track to the next, in the order of their ids). Null for a waypoint more than 50 m from the track'
              ),
            origin: zod
              .enum(['AUTHOR', 'IMPORTED'])
              .describe(
                "Who put the waypoint: its AUTHOR in the editor, or a GPX file it was IMPORTED from. A new GPX file replaces the imported ones and keeps the author's"
              ),
          })
          .describe(
            'A waypoint of a route. Its geometry is where the author put it: its own position, never its projection on the track'
          )
      )
      .describe('Waypoints'),
    departureTime: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        'Departure instant, when the person gave a date. The wall time at the start of the track is this instant in departureTimezone. Present together with departureTimezone'
      ),
    departureTimezone: zod
      .string()
      .optional()
      .describe(
        'IANA time zone of the first point of the track, the one the departure was entered in'
      ),
    averageSpeed: zod
      .number()
      .optional()
      .describe(
        'Average speed in km/h the person gave, null when none (the weather then assumes 25 km/h)'
      ),
  })
  .describe('Analysed GPX file, not attached to any team')

/**
 * Only the creator may delete
 * @summary Delete an analysed GPX file
 */
export const DeletePreviewParams = zod.object({
  previewId: zod.string().describe('Public preview identifier'),
})

export const DeletePreviewResponse = zod.void()

/**
 * Creates a new preview owned by the caller from any preview they have the link of, under the given name: same track, surface and waypoints, and the average speed and departure date when still to come. The planner state is private to the creator: only a copy by the creator keeps it. A copy counts no planner save, whatever the personal quota. Kept 30 days from its creation; the source is left as it is.
 * @summary Copy an analysed GPX file
 */
export const CopyGpxPreviewParams = zod.object({
  previewId: zod.string().describe('Public preview identifier'),
})

export const copyGpxPreviewBodyNameMin = 3
export const copyGpxPreviewBodyNameMax = 200

export const copyGpxPreviewBodyNameRegExp = new RegExp('\\S')

export const CopyGpxPreviewBody = zod
  .object({
    name: zod
      .string()
      .min(copyGpxPreviewBodyNameMin)
      .max(copyGpxPreviewBodyNameMax)
      .regex(copyGpxPreviewBodyNameRegExp)
      .describe('Name of the copy'),
  })
  .describe('GPX preview copy request')

export const CopyGpxPreviewResponse = zod
  .object({
    id: zod.string().describe('Public identifier used in URLs'),
    name: zod.string().describe('Track name'),
    distance: zod.number().describe('Distance in meters'),
    elevationGain: zod.number().describe('Total elevation gain in meters'),
    elevationLoss: zod.number().describe('Total elevation loss in meters'),
    hilliness: zod.number().describe('Elevation gain per kilometer'),
    elevationState: zod
      .enum(['PENDING', 'HD', 'FAST'])
      .describe(
        'Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed.'
      ),
    owned: zod.boolean().describe('Whether the current user created this preview'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    thumbnailUrl: zod
      .string()
      .optional()
      .describe(
        'Rendered map thumbnail template URL (with a {size} placeholder), used for link previews; null when no thumbnail was generated. Opaque URL: may carry a query string; substitute {size} only.'
      ),
    gpxUrl: zod.string().describe('URL to download the analysed GPX file'),
    fitUrl: zod.string().describe('URL to download the analysed track as a FIT file'),
    drawn: zod
      .boolean()
      .describe(
        'Whether the track was drawn in the route planner (true) rather than imported from a GPX file. A drawn preview can only become a route of a team whose route planner is enabled; false when the origin is unknown'
      ),
    tracks: zod
      .array(
        zod
          .object({
            line: zod.object({
              type: zod.enum(['LineString']),
              coordinates: zod
                .array(zod.array(zod.number()))
                .describe(
                  "Array of [lon, lat] coordinates, followed by the elevation in metres when the line carries one ([lon, lat, ele]). A route track's geometry (TrackDto.line) adds a 4th component, [lon, lat, ele, dist]: the distance in metres from the start of THAT track, monotonic, restarting at 0 on each track of the route; it is not the distance along the whole route."
                ),
            }),
            climbs: zod
              .array(
                zod
                  .object({
                    startDistance: zod.int().describe('Start distance from route start in meters'),
                    endDistance: zod.int().describe('End distance from route start in meters'),
                    elevationGain: zod.int().describe('Elevation gain in meters'),
                    averageGradient: zod.number().describe('Average gradient percentage'),
                    maxGradient: zod.number().describe('Maximum gradient percentage'),
                    category: zod
                      .enum(['HC', 'CAT1', 'CAT2', 'CAT3', 'CAT4'])
                      .optional()
                      .describe('Climb category (HC, 1, 2, 3, 4)'),
                    parts: zod
                      .array(
                        zod
                          .object({
                            startDistance: zod
                              .int()
                              .describe('Start distance from route start in meters'),
                            endDistance: zod
                              .int()
                              .describe('End distance from route start in meters'),
                            elevationGain: zod.int().describe('Elevation gain in meters'),
                            grade: zod.number().describe('Gradient percentage'),
                          })
                          .describe('Climb part information')
                      )
                      .describe('Gradient segments making up the climb'),
                    name: zod
                      .string()
                      .optional()
                      .describe(
                        'Name of the climb: the route waypoint lying near its top (within 300 m), as the route\'s author named it in the GPX. Null when no waypoint marks the summit — clients then number the climb ("Climb N"). Never a geocoded guess.'
                      ),
                  })
                  .describe('Climb segment information')
              )
              .describe('List of climbs on the route'),
            surfaceState: zod
              .enum(['PENDING', 'READY', 'UNAVAILABLE'])
              .optional()
              .describe(
                'Where the surface of the track stands. Absent: never computed (a track saved before the feature, or the feature off), or not included (bulk endpoint with geometry=false, which carries no track)'
              ),
            surfaces: zod
              .array(
                zod
                  .object({
                    from: zod.number().describe('Start, metres along the track'),
                    to: zod.number().describe('End, metres along the track'),
                    surface: zod.enum([
                      'PAVED',
                      'PAVED_ROUGH',
                      'GRAVEL',
                      'DIRT',
                      'PATH',
                      'UNKNOWN',
                      'OFF_NETWORK',
                    ]),
                  })
                  .describe(
                    'A stretch of a track with one surface class, in metres along the track (the M of its line)'
                  )
              )
              .optional()
              .describe(
                "Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL), VersaTiles vector tiles"
              ),
          })
          .describe('GPX track with track points')
      )
      .describe('Tracks'),
    waypoints: zod
      .array(
        zod
          .object({
            geometry: zod
              .object({
                type: zod.enum(['Point']),
                coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
              })
              .describe('Location coordinates [longitude, latitude]'),
            name: zod.string().describe('Name, possibly empty'),
            id: zod
              .string()
              .optional()
              .describe(
                'Identifier (TSID) of the waypoint, to send back in the request so that it keeps its origin. Null for a waypoint of a GPX file not saved yet'
              ),
            type: zod
              .enum([
                'REGROUP',
                'SUPPLY',
                'WATER',
                'CAFE',
                'TOILETS',
                'DANGER',
                'SUMMIT',
                'VIEWPOINT',
                'BIKE_SHOP',
                'REAL_START',
                'SPLIT',
                'INFO',
              ])
              .describe('What the waypoint is'),
            description: zod.string().optional().describe('Free text, at most 500 characters'),
            distance: zod
              .number()
              .optional()
              .describe(
                'Metres from the start along the tracks in order (cumulated from one track to the next, in the order of their ids). Null for a waypoint more than 50 m from the track'
              ),
            origin: zod
              .enum(['AUTHOR', 'IMPORTED'])
              .describe(
                "Who put the waypoint: its AUTHOR in the editor, or a GPX file it was IMPORTED from. A new GPX file replaces the imported ones and keeps the author's"
              ),
          })
          .describe(
            'A waypoint of a route. Its geometry is where the author put it: its own position, never its projection on the track'
          )
      )
      .describe('Waypoints'),
    departureTime: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        'Departure instant, when the person gave a date. The wall time at the start of the track is this instant in departureTimezone. Present together with departureTimezone'
      ),
    departureTimezone: zod
      .string()
      .optional()
      .describe(
        'IANA time zone of the first point of the track, the one the departure was entered in'
      ),
    averageSpeed: zod
      .number()
      .optional()
      .describe(
        'Average speed in km/h the person gave, null when none (the weather then assumes 25 km/h)'
      ),
  })
  .describe('Analysed GPX file, not attached to any team')

/**
 * Uploads the preview to the current user's connected Garmin, Hammerhead or Wahoo
 * @summary Send an analysed GPX file to a GPS service
 */
export const UploadToGpsServiceParams = zod.object({
  previewId: zod.string().describe('Public preview identifier'),
  serviceType: zod.enum(['HAMMERHEAD', 'GARMIN', 'WAHOO']).describe('GPS service type'),
})

export const UploadToGpsServiceResponse = zod
  .object({
    success: zod.boolean().describe('Whether the upload was successful'),
    message: zod.string().optional().describe('Error message if upload failed'),
    externalRouteId: zod.string().optional().describe('External route ID on the GPS service'),
  })
  .describe('Result of uploading a route to a GPS service')

/**
 * The control points, routed pieces and imported ranges the preview was last saved with, for its edit page. Only the creator may read it. 'state' is absent when there is none to read back.
 * @summary Get the planner state of an analysed GPX file
 */
export const GetPreviewPlannerStateParams = zod.object({
  previewId: zod.string().describe('Public preview identifier'),
})

export const getPreviewPlannerStateResponseStateSourcesItemLineMax = 2000000

export const getPreviewPlannerStateResponseStateSourcesItemEleMax = 2000000

export const getPreviewPlannerStateResponseStateSourcesItemClimbMax = 2000000

export const getPreviewPlannerStateResponseStateSourcesItemShapeMax = 2000000

export const getPreviewPlannerStateResponseStateSourcesMax = 8

export const getPreviewPlannerStateResponseStateJunctionsMax = 2001

export const getPreviewPlannerStateResponseStatePiecesItemLineMax = 2000000

export const getPreviewPlannerStateResponseStatePiecesItemEleMax = 2000000

export const getPreviewPlannerStateResponseStatePiecesItemUnpavedItemFromMin = 0

export const getPreviewPlannerStateResponseStatePiecesItemUnpavedMax = 50000

export const getPreviewPlannerStateResponseStatePiecesItemShapeMax = 2000000

export const getPreviewPlannerStateResponseStatePiecesMax = 2000

export const GetPreviewPlannerStateResponse = zod
  .object({
    state: zod
      .object({
        version: zod.int(),
        profile: zod.enum(['BIKE', 'FASTBIKE', 'GRAVEL', 'MTB', 'RUN_HIKE', 'MOTORCYCLE']),
        sources: zod
          .array(
            zod.object({
              line: zod
                .string()
                .max(getPreviewPlannerStateResponseStateSourcesItemLineMax)
                .describe('Polyline (precision 6, latitude then longitude) of the source track'),
              ele: zod
                .string()
                .max(getPreviewPlannerStateResponseStateSourcesItemEleMax)
                .optional()
                .describe(
                  'One-dimension polyline (tenths of a metre), one value per point of line; absent: no elevation'
                ),
              ascendScale: zod
                .number()
                .describe(
                  'Factor that recalibrates the raw climb of the source on a reference ascent (1 without reference); in ]0, 100]'
                ),
              climb: zod
                .string()
                .max(getPreviewPlannerStateResponseStateSourcesItemClimbMax)
                .optional()
                .describe(
                  'One-dimension polyline (tenths of a metre), one value per point of line: the ascent accumulated up to each point, as the server measured it (dead-band, non-decreasing, within [0, 100 000 m]). Absent: the client derives it from ele. Requires ele'
                ),
              shape: zod
                .string()
                .max(getPreviewPlannerStateResponseStateSourcesItemShapeMax)
                .optional()
                .describe(
                  'Polyline (precision 6, latitude then longitude) of the raw track of the file, as GpxImportTrack.shape gave it, never edited. An imported piece is cut out of it by projecting its junctions (from and to still index line); absent or inconsistent with line: line'
                ),
            })
          )
          .max(getPreviewPlannerStateResponseStateSourcesMax),
        junctions: zod
          .array(
            zod.object({
              kind: zod.enum(['CONTROL', 'JOIN']),
              lng: zod.number(),
              lat: zod.number(),
              ele: zod.number().optional(),
              source: zod
                .int()
                .optional()
                .describe(
                  'Index of the source track this point comes from; with idx or not at all'
                ),
              idx: zod.int().optional().describe('Index of this point in that source track'),
            })
          )
          .max(getPreviewPlannerStateResponseStateJunctionsMax),
        pieces: zod
          .array(
            zod.object({
              mode: zod.enum(['ROUTED', 'DIRECT', 'IMPORTED']),
              line: zod
                .string()
                .max(getPreviewPlannerStateResponseStatePiecesItemLineMax)
                .optional()
                .describe('ROUTED and DIRECT: polyline6 of the points strictly inside the piece'),
              ele: zod
                .string()
                .max(getPreviewPlannerStateResponseStatePiecesItemEleMax)
                .optional()
                .describe('ROUTED and DIRECT: one-dimension polyline of their elevations'),
              ascend: zod.number().optional().describe('ROUTED: climb of the piece in metres'),
              source: zod.int().optional().describe('IMPORTED: index of the source track'),
              from: zod
                .int()
                .optional()
                .describe('IMPORTED: index in the source of the first junction'),
              to: zod
                .int()
                .optional()
                .describe('IMPORTED: index in the source of the last junction'),
              unpaved: zod
                .array(
                  zod
                    .object({
                      from: zod
                        .int()
                        .min(getPreviewPlannerStateResponseStatePiecesItemUnpavedItemFromMin),
                      to: zod.int().min(1),
                    })
                    .describe(
                      'Half-open run of unpaved edges [from, to) of a line; edge i joins points i and i + 1'
                    )
                )
                .max(getPreviewPlannerStateResponseStatePiecesItemUnpavedMax)
                .optional()
                .describe(
                  'ROUTED: runs of unpaved edges of the piece, half-open, ascending and disjoint; edge 0 joins the first junction to the first interior point, the last edge ends at the last junction. Absent: surface unknown'
                ),
              shape: zod
                .string()
                .max(getPreviewPlannerStateResponseStatePiecesItemShapeMax)
                .optional()
                .describe(
                  "ROUTED: polyline6 of the router's raw geometry of the piece, RouterResponse.shape as the router answered it, never edited (its two ends may be kept: a point within 1 m of a junction is dropped). The saved track is derived from it rather than from line; absent or inconsistent with line (ends over 50 m from the junctions, length off by over 20 % + 200 m): line. Unpaved spans keep indexing the edges of line"
                ),
            })
          )
          .max(getPreviewPlannerStateResponseStatePiecesMax),
      })
      .optional()
      .describe('The state; absent when there is none to read back'),
  })
  .describe('Editing state of the planner of a route or a preview, if any')

/**
 * Creates a team route from the preview's original upload. A preview that was drawn in the route planner (drawn = true) is refused with ROUTE_PLANNER_DISABLED when the team has no route planner; an imported GPX file can become a route of any team.
 * @summary Save an analysed GPX file as a route
 */
export const CreateRouteFromPreviewParams = zod.object({
  previewId: zod.string().describe('Public preview identifier'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const createRouteFromPreviewBodyNameMin = 3
export const createRouteFromPreviewBodyNameMax = 200

export const createRouteFromPreviewBodyNameRegExp = new RegExp('\\S')
export const createRouteFromPreviewBodyMediaMarkdownMax = 100000

export const createRouteFromPreviewBodyPointsItemLngMin = -180
export const createRouteFromPreviewBodyPointsItemLngMax = 180

export const createRouteFromPreviewBodyPointsItemLatMin = -90
export const createRouteFromPreviewBodyPointsItemLatMax = 90

export const createRouteFromPreviewBodyPointsMax = 100000

export const createRouteFromPreviewBodyPlannerStateSourcesItemLineMax = 2000000

export const createRouteFromPreviewBodyPlannerStateSourcesItemEleMax = 2000000

export const createRouteFromPreviewBodyPlannerStateSourcesItemClimbMax = 2000000

export const createRouteFromPreviewBodyPlannerStateSourcesItemShapeMax = 2000000

export const createRouteFromPreviewBodyPlannerStateSourcesMax = 8

export const createRouteFromPreviewBodyPlannerStateJunctionsMax = 2001

export const createRouteFromPreviewBodyPlannerStatePiecesItemLineMax = 2000000

export const createRouteFromPreviewBodyPlannerStatePiecesItemEleMax = 2000000

export const createRouteFromPreviewBodyPlannerStatePiecesItemUnpavedItemFromMin = 0

export const createRouteFromPreviewBodyPlannerStatePiecesItemUnpavedMax = 50000

export const createRouteFromPreviewBodyPlannerStatePiecesItemShapeMax = 2000000

export const createRouteFromPreviewBodyPlannerStatePiecesMax = 2000

export const createRouteFromPreviewBodyWaypointsItemPositionLngMin = -180
export const createRouteFromPreviewBodyWaypointsItemPositionLngMax = 180

export const createRouteFromPreviewBodyWaypointsItemPositionLatMin = -90
export const createRouteFromPreviewBodyWaypointsItemPositionLatMax = 90

export const createRouteFromPreviewBodyWaypointsItemNameMax = 250

export const createRouteFromPreviewBodyWaypointsItemDescriptionMax = 500

export const createRouteFromPreviewBodyWaypointsItemDistanceMin = 0

export const createRouteFromPreviewBodyWaypointsMax = 500

export const CreateRouteFromPreviewBody = zod
  .object({
    name: zod
      .string()
      .min(createRouteFromPreviewBodyNameMin)
      .max(createRouteFromPreviewBodyNameMax)
      .regex(createRouteFromPreviewBodyNameRegExp)
      .describe('Route name'),
    media: zod
      .object({
        markdown: zod.string().max(createRouteFromPreviewBodyMediaMarkdownMax).describe('Markdown'),
        assets: zod
          .object({
            logo: zod
              .object({
                id: zod.string().describe('ID (TSID)'),
                fileName: zod.string().describe('Filename'),
                contentType: zod.string().describe('Content-Type'),
                url: zod
                  .string()
                  .describe(
                    'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                  ),
                imageUrl: zod
                  .string()
                  .optional()
                  .describe(
                    'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                  ),
                imageDimensions: zod
                  .object({
                    width: zod.int().optional(),
                    height: zod.int().optional(),
                  })
                  .optional()
                  .describe('image dimensions'),
                size: zod
                  .int()
                  .optional()
                  .describe(
                    'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                  ),
              })
              .optional()
              .describe('Logo'),
            images: zod
              .array(
                zod.object({
                  id: zod.string().describe('ID (TSID)'),
                  fileName: zod.string().describe('Filename'),
                  contentType: zod.string().describe('Content-Type'),
                  url: zod
                    .string()
                    .describe(
                      'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                    ),
                  imageUrl: zod
                    .string()
                    .optional()
                    .describe(
                      'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                    ),
                  imageDimensions: zod
                    .object({
                      width: zod.int().optional(),
                      height: zod.int().optional(),
                    })
                    .optional()
                    .describe('image dimensions'),
                  size: zod
                    .int()
                    .optional()
                    .describe(
                      'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                    ),
                })
              )
              .describe('Images'),
            attachments: zod
              .array(
                zod.object({
                  id: zod.string().describe('ID (TSID)'),
                  fileName: zod.string().describe('Filename'),
                  contentType: zod.string().describe('Content-Type'),
                  url: zod
                    .string()
                    .describe(
                      'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                    ),
                  imageUrl: zod
                    .string()
                    .optional()
                    .describe(
                      'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                    ),
                  imageDimensions: zod
                    .object({
                      width: zod.int().optional(),
                      height: zod.int().optional(),
                    })
                    .optional()
                    .describe('image dimensions'),
                  size: zod
                    .int()
                    .optional()
                    .describe(
                      'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                    ),
                })
              )
              .describe('Attachments'),
            originalGpx: zod
              .object({
                id: zod.string().describe('ID (TSID)'),
                fileName: zod.string().describe('Filename'),
                contentType: zod.string().describe('Content-Type'),
                url: zod
                  .string()
                  .describe(
                    'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                  ),
                imageUrl: zod
                  .string()
                  .optional()
                  .describe(
                    'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                  ),
                imageDimensions: zod
                  .object({
                    width: zod.int().optional(),
                    height: zod.int().optional(),
                  })
                  .optional()
                  .describe('image dimensions'),
                size: zod
                  .int()
                  .optional()
                  .describe(
                    'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                  ),
              })
              .optional()
              .describe('Original GPX'),
            gpx: zod
              .object({
                id: zod.string().describe('ID (TSID)'),
                fileName: zod.string().describe('Filename'),
                contentType: zod.string().describe('Content-Type'),
                url: zod
                  .string()
                  .describe(
                    'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                  ),
                imageUrl: zod
                  .string()
                  .optional()
                  .describe(
                    'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                  ),
                imageDimensions: zod
                  .object({
                    width: zod.int().optional(),
                    height: zod.int().optional(),
                  })
                  .optional()
                  .describe('image dimensions'),
                size: zod
                  .int()
                  .optional()
                  .describe(
                    'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                  ),
              })
              .optional()
              .describe('GPX'),
            fit: zod
              .object({
                id: zod.string().describe('ID (TSID)'),
                fileName: zod.string().describe('Filename'),
                contentType: zod.string().describe('Content-Type'),
                url: zod
                  .string()
                  .describe(
                    'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                  ),
                imageUrl: zod
                  .string()
                  .optional()
                  .describe(
                    'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                  ),
                imageDimensions: zod
                  .object({
                    width: zod.int().optional(),
                    height: zod.int().optional(),
                  })
                  .optional()
                  .describe('image dimensions'),
                size: zod
                  .int()
                  .optional()
                  .describe(
                    'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                  ),
              })
              .optional()
              .describe('FIT'),
            thumbnailLight: zod
              .object({
                id: zod.string().describe('ID (TSID)'),
                fileName: zod.string().describe('Filename'),
                contentType: zod.string().describe('Content-Type'),
                url: zod
                  .string()
                  .describe(
                    'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                  ),
                imageUrl: zod
                  .string()
                  .optional()
                  .describe(
                    'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                  ),
                imageDimensions: zod
                  .object({
                    width: zod.int().optional(),
                    height: zod.int().optional(),
                  })
                  .optional()
                  .describe('image dimensions'),
                size: zod
                  .int()
                  .optional()
                  .describe(
                    'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                  ),
              })
              .optional()
              .describe('Light thumbnail'),
            thumbnailDark: zod
              .object({
                id: zod.string().describe('ID (TSID)'),
                fileName: zod.string().describe('Filename'),
                contentType: zod.string().describe('Content-Type'),
                url: zod
                  .string()
                  .describe(
                    'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                  ),
                imageUrl: zod
                  .string()
                  .optional()
                  .describe(
                    'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                  ),
                imageDimensions: zod
                  .object({
                    width: zod.int().optional(),
                    height: zod.int().optional(),
                  })
                  .optional()
                  .describe('image dimensions'),
                size: zod
                  .int()
                  .optional()
                  .describe(
                    'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                  ),
              })
              .optional()
              .describe('Dark thumbnail'),
          })
          .describe('Assets'),
      })
      .describe('Media'),
    surfaceType: zod.enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED']).describe('Surface type'),
    visibility: zod
      .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
      .describe('Whether the route is publicly visible'),
    points: zod
      .array(
        zod.object({
          lng: zod
            .number()
            .min(createRouteFromPreviewBodyPointsItemLngMin)
            .max(createRouteFromPreviewBodyPointsItemLngMax),
          lat: zod
            .number()
            .min(createRouteFromPreviewBodyPointsItemLatMin)
            .max(createRouteFromPreviewBodyPointsItemLatMax),
        })
      )
      .max(createRouteFromPreviewBodyPointsMax)
      .optional()
      .describe('Points from frontend routing'),
    tagIds: zod
      .array(zod.string())
      .optional()
      .describe(
        "IDs (TSID) of the team's ROUTE tags the route carries, replacing the whole set — at most 10, each a tag of this team and of kind ROUTE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update."
      ),
    plannerState: zod
      .object({
        version: zod.int(),
        profile: zod.enum(['BIKE', 'FASTBIKE', 'GRAVEL', 'MTB', 'RUN_HIKE', 'MOTORCYCLE']),
        sources: zod
          .array(
            zod.object({
              line: zod
                .string()
                .max(createRouteFromPreviewBodyPlannerStateSourcesItemLineMax)
                .describe('Polyline (precision 6, latitude then longitude) of the source track'),
              ele: zod
                .string()
                .max(createRouteFromPreviewBodyPlannerStateSourcesItemEleMax)
                .optional()
                .describe(
                  'One-dimension polyline (tenths of a metre), one value per point of line; absent: no elevation'
                ),
              ascendScale: zod
                .number()
                .describe(
                  'Factor that recalibrates the raw climb of the source on a reference ascent (1 without reference); in ]0, 100]'
                ),
              climb: zod
                .string()
                .max(createRouteFromPreviewBodyPlannerStateSourcesItemClimbMax)
                .optional()
                .describe(
                  'One-dimension polyline (tenths of a metre), one value per point of line: the ascent accumulated up to each point, as the server measured it (dead-band, non-decreasing, within [0, 100 000 m]). Absent: the client derives it from ele. Requires ele'
                ),
              shape: zod
                .string()
                .max(createRouteFromPreviewBodyPlannerStateSourcesItemShapeMax)
                .optional()
                .describe(
                  'Polyline (precision 6, latitude then longitude) of the raw track of the file, as GpxImportTrack.shape gave it, never edited. An imported piece is cut out of it by projecting its junctions (from and to still index line); absent or inconsistent with line: line'
                ),
            })
          )
          .max(createRouteFromPreviewBodyPlannerStateSourcesMax),
        junctions: zod
          .array(
            zod.object({
              kind: zod.enum(['CONTROL', 'JOIN']),
              lng: zod.number(),
              lat: zod.number(),
              ele: zod.number().optional(),
              source: zod
                .int()
                .optional()
                .describe(
                  'Index of the source track this point comes from; with idx or not at all'
                ),
              idx: zod.int().optional().describe('Index of this point in that source track'),
            })
          )
          .max(createRouteFromPreviewBodyPlannerStateJunctionsMax),
        pieces: zod
          .array(
            zod.object({
              mode: zod.enum(['ROUTED', 'DIRECT', 'IMPORTED']),
              line: zod
                .string()
                .max(createRouteFromPreviewBodyPlannerStatePiecesItemLineMax)
                .optional()
                .describe('ROUTED and DIRECT: polyline6 of the points strictly inside the piece'),
              ele: zod
                .string()
                .max(createRouteFromPreviewBodyPlannerStatePiecesItemEleMax)
                .optional()
                .describe('ROUTED and DIRECT: one-dimension polyline of their elevations'),
              ascend: zod.number().optional().describe('ROUTED: climb of the piece in metres'),
              source: zod.int().optional().describe('IMPORTED: index of the source track'),
              from: zod
                .int()
                .optional()
                .describe('IMPORTED: index in the source of the first junction'),
              to: zod
                .int()
                .optional()
                .describe('IMPORTED: index in the source of the last junction'),
              unpaved: zod
                .array(
                  zod
                    .object({
                      from: zod
                        .int()
                        .min(createRouteFromPreviewBodyPlannerStatePiecesItemUnpavedItemFromMin),
                      to: zod.int().min(1),
                    })
                    .describe(
                      'Half-open run of unpaved edges [from, to) of a line; edge i joins points i and i + 1'
                    )
                )
                .max(createRouteFromPreviewBodyPlannerStatePiecesItemUnpavedMax)
                .optional()
                .describe(
                  'ROUTED: runs of unpaved edges of the piece, half-open, ascending and disjoint; edge 0 joins the first junction to the first interior point, the last edge ends at the last junction. Absent: surface unknown'
                ),
              shape: zod
                .string()
                .max(createRouteFromPreviewBodyPlannerStatePiecesItemShapeMax)
                .optional()
                .describe(
                  "ROUTED: polyline6 of the router's raw geometry of the piece, RouterResponse.shape as the router answered it, never edited (its two ends may be kept: a point within 1 m of a junction is dropped). The saved track is derived from it rather than from line; absent or inconsistent with line (ends over 50 m from the junctions, length off by over 20 % + 200 m): line. Unpaved spans keep indexing the edges of line"
                ),
            })
          )
          .max(createRouteFromPreviewBodyPlannerStatePiecesMax),
      })
      .optional()
      .describe(
        'Editing state of the planner; the server derives the track from it. Not with points (400 PLANNER_STATE_INVALID); a gpxFile wins over it'
      ),
    waypoints: zod
      .array(
        zod
          .object({
            id: zod
              .string()
              .optional()
              .describe(
                'Identifier of an existing waypoint, as returned by the API: it keeps its origin. Omitted or unknown: a new waypoint. Malformed or repeated: 400'
              ),
            position: zod
              .object({
                lng: zod
                  .number()
                  .min(createRouteFromPreviewBodyWaypointsItemPositionLngMin)
                  .max(createRouteFromPreviewBodyWaypointsItemPositionLngMax),
                lat: zod
                  .number()
                  .min(createRouteFromPreviewBodyWaypointsItemPositionLatMin)
                  .max(createRouteFromPreviewBodyWaypointsItemPositionLatMax),
              })
              .describe('Where the waypoint is'),
            type: zod
              .enum([
                'REGROUP',
                'SUPPLY',
                'WATER',
                'CAFE',
                'TOILETS',
                'DANGER',
                'SUMMIT',
                'VIEWPOINT',
                'BIKE_SHOP',
                'REAL_START',
                'SPLIT',
                'INFO',
              ])
              .describe('What the waypoint is'),
            name: zod
              .string()
              .max(createRouteFromPreviewBodyWaypointsItemNameMax)
              .describe(
                "Name, possibly empty (the type's label then shows on a device). The editor limits it to 40 characters; the API accepts what an import can bring, up to 250"
              ),
            description: zod
              .string()
              .max(createRouteFromPreviewBodyWaypointsItemDescriptionMax)
              .optional()
              .describe('Free text, at most 500 characters'),
            distance: zod
              .number()
              .min(createRouteFromPreviewBodyWaypointsItemDistanceMin)
              .optional()
              .describe(
                'The distance in metres the editor shows the waypoint at. Only used to pick which passage of a route that goes by twice the waypoint belongs to: the server recomputes the distance itself'
              ),
            origin: zod
              .enum(['AUTHOR', 'IMPORTED'])
              .optional()
              .describe(
                'Origin of a new waypoint, AUTHOR by default. Ignored for a waypoint that exists: it keeps its own'
              ),
          })
          .describe('A waypoint of a route, as sent by the editor')
      )
      .max(createRouteFromPreviewBodyWaypointsMax)
      .optional()
      .describe(
        "The complete list of the route's waypoints, replacing them. Omitted: they stay as they are (placed again on the new track when the track changes, and a new GPX file replaces the imported ones and keeps the author's). When present it wins over the waypoints of a GPX file sent with it"
      ),
  })
  .describe('Route update request')

export const createRouteFromPreviewResponseMediaMarkdownMax = 100000

export const CreateRouteFromPreviewResponse = zod
  .object({
    id: zod.string().describe('Route ID (TSID)'),
    slug: zod.string().describe('Route slug'),
    team: zod
      .object({
        id: zod.string().describe('Team ID (TSID)'),
        name: zod.string().describe('Team name'),
        slug: zod.string().describe('Team URL slug'),
        visibility: zod
          .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
          .describe('Whether the team is public'),
        logoUrl: zod
          .string()
          .optional()
          .describe(
            "URL template of the team's logo (with a {size} placeholder), when it has one and the caller may download it. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team. Absent when accessible is false and the private team does not publish content by link: its logo is then closed to the caller. Opaque URL: may carry a query string; substitute {size} only."
          ),
        accessible: zod
          .boolean()
          .describe(
            'Whether GET team answers the caller: the team is not private, or the caller is a member of it or a platform admin. A client loads the team, links to it or shows its header only when true; otherwise it renders this summary. The public content of a private team is read by link with this false.'
          ),
      })
      .describe('Team'),
    name: zod.string().describe('Route name'),
    media: zod
      .object({
        markdown: zod
          .string()
          .max(createRouteFromPreviewResponseMediaMarkdownMax)
          .describe('Markdown'),
        assets: zod
          .object({
            logo: zod
              .object({
                id: zod.string().describe('ID (TSID)'),
                fileName: zod.string().describe('Filename'),
                contentType: zod.string().describe('Content-Type'),
                url: zod
                  .string()
                  .describe(
                    'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                  ),
                imageUrl: zod
                  .string()
                  .optional()
                  .describe(
                    'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                  ),
                imageDimensions: zod
                  .object({
                    width: zod.int().optional(),
                    height: zod.int().optional(),
                  })
                  .optional()
                  .describe('image dimensions'),
                size: zod
                  .int()
                  .optional()
                  .describe(
                    'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                  ),
              })
              .optional()
              .describe('Logo'),
            images: zod
              .array(
                zod.object({
                  id: zod.string().describe('ID (TSID)'),
                  fileName: zod.string().describe('Filename'),
                  contentType: zod.string().describe('Content-Type'),
                  url: zod
                    .string()
                    .describe(
                      'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                    ),
                  imageUrl: zod
                    .string()
                    .optional()
                    .describe(
                      'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                    ),
                  imageDimensions: zod
                    .object({
                      width: zod.int().optional(),
                      height: zod.int().optional(),
                    })
                    .optional()
                    .describe('image dimensions'),
                  size: zod
                    .int()
                    .optional()
                    .describe(
                      'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                    ),
                })
              )
              .describe('Images'),
            attachments: zod
              .array(
                zod.object({
                  id: zod.string().describe('ID (TSID)'),
                  fileName: zod.string().describe('Filename'),
                  contentType: zod.string().describe('Content-Type'),
                  url: zod
                    .string()
                    .describe(
                      'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                    ),
                  imageUrl: zod
                    .string()
                    .optional()
                    .describe(
                      'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                    ),
                  imageDimensions: zod
                    .object({
                      width: zod.int().optional(),
                      height: zod.int().optional(),
                    })
                    .optional()
                    .describe('image dimensions'),
                  size: zod
                    .int()
                    .optional()
                    .describe(
                      'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                    ),
                })
              )
              .describe('Attachments'),
            originalGpx: zod
              .object({
                id: zod.string().describe('ID (TSID)'),
                fileName: zod.string().describe('Filename'),
                contentType: zod.string().describe('Content-Type'),
                url: zod
                  .string()
                  .describe(
                    'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                  ),
                imageUrl: zod
                  .string()
                  .optional()
                  .describe(
                    'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                  ),
                imageDimensions: zod
                  .object({
                    width: zod.int().optional(),
                    height: zod.int().optional(),
                  })
                  .optional()
                  .describe('image dimensions'),
                size: zod
                  .int()
                  .optional()
                  .describe(
                    'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                  ),
              })
              .optional()
              .describe('Original GPX'),
            gpx: zod
              .object({
                id: zod.string().describe('ID (TSID)'),
                fileName: zod.string().describe('Filename'),
                contentType: zod.string().describe('Content-Type'),
                url: zod
                  .string()
                  .describe(
                    'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                  ),
                imageUrl: zod
                  .string()
                  .optional()
                  .describe(
                    'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                  ),
                imageDimensions: zod
                  .object({
                    width: zod.int().optional(),
                    height: zod.int().optional(),
                  })
                  .optional()
                  .describe('image dimensions'),
                size: zod
                  .int()
                  .optional()
                  .describe(
                    'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                  ),
              })
              .optional()
              .describe('GPX'),
            fit: zod
              .object({
                id: zod.string().describe('ID (TSID)'),
                fileName: zod.string().describe('Filename'),
                contentType: zod.string().describe('Content-Type'),
                url: zod
                  .string()
                  .describe(
                    'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                  ),
                imageUrl: zod
                  .string()
                  .optional()
                  .describe(
                    'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                  ),
                imageDimensions: zod
                  .object({
                    width: zod.int().optional(),
                    height: zod.int().optional(),
                  })
                  .optional()
                  .describe('image dimensions'),
                size: zod
                  .int()
                  .optional()
                  .describe(
                    'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                  ),
              })
              .optional()
              .describe('FIT'),
            thumbnailLight: zod
              .object({
                id: zod.string().describe('ID (TSID)'),
                fileName: zod.string().describe('Filename'),
                contentType: zod.string().describe('Content-Type'),
                url: zod
                  .string()
                  .describe(
                    'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                  ),
                imageUrl: zod
                  .string()
                  .optional()
                  .describe(
                    'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                  ),
                imageDimensions: zod
                  .object({
                    width: zod.int().optional(),
                    height: zod.int().optional(),
                  })
                  .optional()
                  .describe('image dimensions'),
                size: zod
                  .int()
                  .optional()
                  .describe(
                    'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                  ),
              })
              .optional()
              .describe('Light thumbnail'),
            thumbnailDark: zod
              .object({
                id: zod.string().describe('ID (TSID)'),
                fileName: zod.string().describe('Filename'),
                contentType: zod.string().describe('Content-Type'),
                url: zod
                  .string()
                  .describe(
                    'Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.'
                  ),
                imageUrl: zod
                  .string()
                  .optional()
                  .describe(
                    'Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.'
                  ),
                imageDimensions: zod
                  .object({
                    width: zod.int().optional(),
                    height: zod.int().optional(),
                  })
                  .optional()
                  .describe('image dimensions'),
                size: zod
                  .int()
                  .optional()
                  .describe(
                    'Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.'
                  ),
              })
              .optional()
              .describe('Dark thumbnail'),
          })
          .describe('Assets'),
      })
      .describe('Route description'),
    excerpt: zod
      .string()
      .optional()
      .describe(
        "Plain-text opening of the description, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the description holds no text. Lets a list row render its two lines without the description being sent at all — see the 'view' parameter."
      ),
    thumbnailUrl: zod
      .string()
      .optional()
      .describe(
        "URL template of the route's thumbnail, light variant if there is one, else dark. Saves a compact row from carrying media.assets just to find the map preview. Opaque URL: may carry a query string; substitute {size} only."
      ),
    distance: zod.number().describe('Distance in meters'),
    elevationGain: zod.number().describe('Total elevation gain in meters'),
    elevationLoss: zod.number().describe('Total elevation loss in meters'),
    elevationState: zod
      .enum(['PENDING', 'HD', 'FAST'])
      .describe(
        'Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed.'
      ),
    surfaceType: zod.enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED']).describe('Surface type'),
    visibility: zod
      .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
      .describe('Whether the route is public'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    deleted: zod.boolean().describe('Whether the route is soft-deleted'),
    commentCount: zod
      .int()
      .optional()
      .describe(
        'Number of comments, replies included. Absent when the caller may not read the comments of this route — comments are members-only, so an outsider is told nothing, not even zero.'
      ),
    tags: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Tag ID (TSID)'),
            label: zod.string().describe('Label, at most 32 characters'),
            color: zod
              .enum(['INDIGO', 'BLUE', 'GREEN', 'RED', 'YELLOW', 'ORANGE', 'GRAPE', 'TEAL', 'GRAY'])
              .describe('Colour family'),
          })
          .describe('A team tag on a content')
      )
      .describe(
        "The team's ROUTE tags the route carries, sorted by label. Empty when it carries none."
      ),
    gpsSyncStatuses: zod
      .array(
        zod
          .object({
            serviceType: zod.enum(['HAMMERHEAD', 'GARMIN', 'WAHOO']).describe('GPS service'),
            state: zod
              .enum(['SENT', 'OUTDATED', 'PENDING', 'FAILING', 'RECONNECT_REQUIRED'])
              .describe(
                'SENT: at the service, up to date; OUTDATED: at the service in an older version that nothing will update, send it again; PENDING: to be sent or updated shortly; FAILING: the last attempt failed (a few retries, then it waits for the route to change); RECONNECT_REQUIRED: the connection must be renewed'
              ),
            syncedAt: zod.iso
              .datetime({ offset: true })
              .optional()
              .describe(
                'When the route was last sent to the service successfully. Absent while it never was.'
              ),
          })
          .describe("Where the route stands at one of the caller's automatically synced services")
      )
      .optional()
      .describe(
        "Where this route stands at each of the caller's GPS services whose automatic sync is on and which hold it (sent for one of their rides or trip stages, or uploaded by hand), sorted by service. Only ever about the caller's own connections. Absent when there is none — anonymous caller, no such service, or a response that does not report it (create, update)."
      ),
    permissions: zod
      .object({
        canEdit: zod
          .boolean()
          .describe(
            "Whether the caller may edit this entity (the update endpoints would accept it). For a trip stage, whether they may edit its trip, which a stage is written through. For the team's about page, whether they may edit it through the team update, the only way it is written."
          ),
        canDelete: zod
          .boolean()
          .describe(
            'Whether the caller may delete this entity. For a trip stage, whether they may delete its trip.'
          ),
        canRegister: zod
          .boolean()
          .optional()
          .describe(
            'Rides and trips only: whether the caller may register — a member of the team (or a platform admin), the entity published. On a detail it is exact about timing too: false once every group of the ride has left or the trip is finished, as the join endpoints answer. On list rows it does not look at timing, so it may be true on a row and false on the detail of the same entity. Never counts capacity: a full group still refuses. Absent on the other types.'
          ),
        canComment: zod
          .boolean()
          .optional()
          .describe(
            "Whether the caller may read and write the comment thread: a member of the team or a platform admin, whatever the entity's visibility. Absent on the types that carry no comments (team pages, ads)."
          ),
        canSeeParticipants: zod
          .boolean()
          .optional()
          .describe(
            'Rides and trips only: whether the caller may see who takes part (names, the participants endpoints). Same rule as canComment. When false, only the counts are sent. Absent on the other types.'
          ),
        allowedVisibilities: zod
          .array(zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']))
          .optional()
          .describe(
            "The visibilities this entity may be saved with, in the order of the Visibility enum; an editor hides its selector when there is only one. For a route used by a ride or a trip that is not TEAM (drafts included, deleted ones not), TEAM is left out: saving it as TEAM is refused with INCOMPATIBLE_VISIBILITY. That can leave the list empty, when the team accepts nothing but TEAM any more: the route cannot be saved until those usages go TEAM. Present on a detail only: absent on list rows, on embedded summaries, on the types without a visibility of their own (trip stages) and on the team's about page, whose visibility no endpoint sets. Clients that create read TeamDetailDto.allowedContentVisibilities instead."
          ),
        indexable: zod
          .boolean()
          .describe(
            "Whether search engines may index the entity's page: the rule of the sitemap — entity PUBLIC, team PUBLIC, published or cancelled, not hidden by moderation. False means the page must carry noindex. A trip stage carries its trip's answer."
          ),
      })
      .describe(
        'What the caller may do with the route: edit, delete, comment. A list row and the route of a stage carry no allowedVisibilities; the detail (RouteDetailDto) does.'
      ),
  })
  .describe('Route summary data')

/**
 * The forecast along the track when the preview has a departure date: at the start, then at each estimated passage (the average speed given, else 25 km/h). Anyone holding the link may read it. Read from the server's cache only — the forecast is refreshed in the background, never on request — and always 200: the state is in status (OUT_OF_RANGE without a date or once it is past). Cache-Control: private, no-cache with an ETag (revalidate with If-None-Match, 304 when unchanged); no-store when status is UNAVAILABLE.
 * @summary Get the weather of an analysed GPX file
 */
export const GetPreviewWeatherParams = zod.object({
  previewId: zod.string().describe('Public preview identifier'),
})

export const GetPreviewWeatherResponse = zod
  .object({
    status: zod
      .enum(['OK', 'STALE', 'NOT_YET_AVAILABLE', 'UNAVAILABLE', 'NO_LOCATION', 'OUT_OF_RANGE'])
      .describe(
        "Overall state. OK and STALE (shown, flagged as old) carry the forecast; NOT_YET_AVAILABLE comes with availableFrom; UNAVAILABLE (nothing in cache yet, or the provider failing) offers to retry; NO_LOCATION is worth a word to the organisers only; OUT_OF_RANGE (over — its last group back, the ride's estimated end —, cancelled) shows nothing. A ride that has left but whose groups are still out, or still to leave, keeps its forecast."
      ),
    availableFrom: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe('For NOT_YET_AVAILABLE: when the forecast opens, seven days before the departure'),
    fetchedAt: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe('The oldest fetch among the forecasts read'),
    departure: zod
      .object({
        status: zod
          .enum(['OK', 'STALE', 'NOT_YET_AVAILABLE', 'UNAVAILABLE', 'NO_LOCATION', 'OUT_OF_RANGE'])
          .describe(
            'State of the departure forecast. conditions is present for OK and STALE only.'
          ),
        conditions: zod
          .object({
            time: zod.iso
              .datetime({ offset: true })
              .describe('The forecast hour used: the one nearest the moment asked about'),
            weatherCode: zod
              .int()
              .describe(
                'WMO weather interpretation code, as the model gives it. condition is its folding; a client reads condition, this is for the curious.'
              ),
            condition: zod
              .enum([
                'CLEAR',
                'MOSTLY_CLEAR',
                'PARTLY_CLOUDY',
                'OVERCAST',
                'FOG',
                'DRIZZLE',
                'RAIN',
                'HEAVY_RAIN',
                'FREEZING_RAIN',
                'SHOWERS',
                'SNOW',
                'THUNDERSTORM',
              ])
              .describe(
                'weatherCode folded into what a rider decides on. WMO code → condition: 0 CLEAR; 1 MOSTLY_CLEAR; 2 PARTLY_CLOUDY; 3 OVERCAST; 45, 48 FOG; 51, 53, 55 DRIZZLE; 56, 57, 66, 67 FREEZING_RAIN; 61, 63 RAIN; 65 HEAVY_RAIN; 71, 73, 75, 77, 85, 86 SNOW; 80, 81, 82 SHOWERS; 95, 96, 99 THUNDERSTORM; any other OVERCAST. A client meeting a value it does not know shows a plain cloud.'
              ),
            daylight: zod
              .boolean()
              .describe(
                "Whether the moment asked about (the departure, the checkpoint's passage) falls between sunrise and sunset at that place — not time, the round model hour. Picks the day or night icon"
              ),
            temperature: zod.number().describe('Air temperature at 2 m, °C'),
            apparentTemperature: zod
              .number()
              .describe('Felt temperature (wind chill, humidity), °C'),
            precipitationProbability: zod
              .int()
              .optional()
              .describe(
                'Probability of precipitation, % (0–100). Absent when the model gives none.'
              ),
            precipitation: zod
              .number()
              .describe('Precipitation over the hour (rain, showers, snow), mm'),
            wind: zod
              .object({
                speed: zod.number().describe('Mean wind speed, km/h'),
                gusts: zod
                  .number()
                  .optional()
                  .describe('Gusts, km/h. Absent when the model gives none.'),
                direction: zod
                  .number()
                  .describe(
                    'Direction the wind comes FROM, degrees clockwise from north (0 = from the north, 90 = from the east)'
                  ),
                compass: zod
                  .enum(['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'])
                  .describe(
                    'direction on the eight-point rose, still the direction the wind comes FROM'
                  ),
              })
              .describe('Wind of that hour'),
          })
          .optional()
          .describe('The forecast of the departure hour, for OK and STALE'),
        sunrise: zod.iso
          .datetime({ offset: true })
          .optional()
          .describe("Sunrise at the meeting point, on the departure's local date"),
        sunset: zod.iso
          .datetime({ offset: true })
          .optional()
          .describe("Sunset at the meeting point, on the departure's local date"),
        fetchedAt: zod.iso
          .datetime({ offset: true })
          .optional()
          .describe('When the forecast of the meeting point was last fetched'),
      })
      .describe(
        "The meeting point when the ride leaves (its dateTime). Each leg carries its own, at the group's start."
      ),
    legs: zod
      .array(
        zod
          .object({
            groupId: zod
              .string()
              .optional()
              .describe(
                "The ride group (TSID). Absent for a ride without groups — the leg rides the ride's own route — and for a trip's legs, which TripStageWeatherDto.stageId names."
              ),
            status: zod
              .enum([
                'OK',
                'STALE',
                'NOT_YET_AVAILABLE',
                'UNAVAILABLE',
                'NO_LOCATION',
                'OUT_OF_RANGE',
              ])
              .describe(
                "State of this leg's forecast. NO_LOCATION when the leg has no route to sample: then no checkpoint, no segment. NOT_YET_AVAILABLE when it leaves beyond the seven-day horizon: checkpoints and times without weather, and availableFrom. OUT_OF_RANGE for a trip stage already over (its estimated end passed): nothing to show."
              ),
            availableFrom: zod.iso
              .datetime({ offset: true })
              .optional()
              .describe(
                "For NOT_YET_AVAILABLE: when this leg's forecast opens, seven days before it leaves"
              ),
            startTime: zod.iso.datetime({ offset: true }).describe('When the leg leaves'),
            averageSpeed: zod.number().describe('Speed used for the passages, km/h'),
            speedIsDefault: zod
              .boolean()
              .describe(
                'Whether averageSpeed is the 25 km/h default, the group or stage having none — to be said on screen'
              ),
            distance: zod.number().describe("Length of the leg's route, metres"),
            arrivalTime: zod.iso.datetime({ offset: true }).describe('Estimated arrival'),
            fetchedAt: zod.iso
              .datetime({ offset: true })
              .optional()
              .describe('The oldest fetch among the forecasts this leg reads'),
            checkpoints: zod
              .array(
                zod
                  .object({
                    index: zod.int().describe('Position of the point on the leg, 0 for the start'),
                    kind: zod
                      .enum(['START', 'EN_ROUTE', 'FINISH'])
                      .describe('Where the point stands on the leg'),
                    distance: zod
                      .number()
                      .describe(
                        "Distance from the start of the leg's route, metres: its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next. To place the point on the geometry, add up the lengths of the previous tracks: the 4th coordinate of a track geometry restarts at 0 on each track."
                      ),
                    elevation: zod
                      .number()
                      .optional()
                      .describe('Elevation of the point, metres, from the track'),
                    time: zod.iso
                      .datetime({ offset: true })
                      .describe("Estimated passage, from the leg's start time and speed"),
                    weather: zod
                      .object({
                        time: zod.iso
                          .datetime({ offset: true })
                          .describe(
                            'The forecast hour used: the one nearest the moment asked about'
                          ),
                        weatherCode: zod
                          .int()
                          .describe(
                            'WMO weather interpretation code, as the model gives it. condition is its folding; a client reads condition, this is for the curious.'
                          ),
                        condition: zod
                          .enum([
                            'CLEAR',
                            'MOSTLY_CLEAR',
                            'PARTLY_CLOUDY',
                            'OVERCAST',
                            'FOG',
                            'DRIZZLE',
                            'RAIN',
                            'HEAVY_RAIN',
                            'FREEZING_RAIN',
                            'SHOWERS',
                            'SNOW',
                            'THUNDERSTORM',
                          ])
                          .describe(
                            'weatherCode folded into what a rider decides on. WMO code → condition: 0 CLEAR; 1 MOSTLY_CLEAR; 2 PARTLY_CLOUDY; 3 OVERCAST; 45, 48 FOG; 51, 53, 55 DRIZZLE; 56, 57, 66, 67 FREEZING_RAIN; 61, 63 RAIN; 65 HEAVY_RAIN; 71, 73, 75, 77, 85, 86 SNOW; 80, 81, 82 SHOWERS; 95, 96, 99 THUNDERSTORM; any other OVERCAST. A client meeting a value it does not know shows a plain cloud.'
                          ),
                        daylight: zod
                          .boolean()
                          .describe(
                            "Whether the moment asked about (the departure, the checkpoint's passage) falls between sunrise and sunset at that place — not time, the round model hour. Picks the day or night icon"
                          ),
                        temperature: zod.number().describe('Air temperature at 2 m, °C'),
                        apparentTemperature: zod
                          .number()
                          .describe('Felt temperature (wind chill, humidity), °C'),
                        precipitationProbability: zod
                          .int()
                          .optional()
                          .describe(
                            'Probability of precipitation, % (0–100). Absent when the model gives none.'
                          ),
                        precipitation: zod
                          .number()
                          .describe('Precipitation over the hour (rain, showers, snow), mm'),
                        wind: zod
                          .object({
                            speed: zod.number().describe('Mean wind speed, km/h'),
                            gusts: zod
                              .number()
                              .optional()
                              .describe('Gusts, km/h. Absent when the model gives none.'),
                            direction: zod
                              .number()
                              .describe(
                                'Direction the wind comes FROM, degrees clockwise from north (0 = from the north, 90 = from the east)'
                              ),
                            compass: zod
                              .enum(['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'])
                              .describe(
                                'direction on the eight-point rose, still the direction the wind comes FROM'
                              ),
                          })
                          .describe('Wind of that hour'),
                      })
                      .optional()
                      .describe(
                        'The forecast at the passage. Absent when nothing is in cache for that place yet.'
                      ),
                    relativeWind: zod
                      .enum(['HEAD', 'CROSS', 'TAIL'])
                      .optional()
                      .describe(
                        'How the rider meets the wind on the stretch that starts here (for the finish, the stretch that ends here). Absent without weather.'
                      ),
                    headwind: zod
                      .number()
                      .optional()
                      .describe(
                        'Mean head component of the wind on that stretch, km/h, signed: positive against the rider, negative behind'
                      ),
                    relativeWindAngle: zod
                      .number()
                      .optional()
                      .describe(
                        'Direction the wind blows TOWARDS, relative to the direction of travel, degrees clockwise: 0 = from behind (pushing), 90 = from the left, 180 = in the face. Draw the arrow pointing forward, then rotate it by this angle.'
                      ),
                  })
                  .describe(
                    'A forecast point along a leg, about every 15 km plus the finish. Deliberately carries no coordinates: place it by distance on the route geometry the client may read.'
                  )
              )
              .describe('Forecast points, start to finish'),
            segments: zod
              .array(
                zod
                  .object({
                    fromDistance: zod
                      .number()
                      .describe(
                        "Start of the stretch, equal to its checkpoint's distance: metres from the start of the route, its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next (unlike the 4th coordinate of a track geometry, which restarts at 0 on each track)."
                      ),
                    toDistance: zod
                      .number()
                      .describe(
                        "End of the stretch, equal to the next checkpoint's distance: metres from the start of the route, its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next (unlike the 4th coordinate of a track geometry, which restarts at 0 on each track)."
                      ),
                    relativeWind: zod
                      .enum(['HEAD', 'CROSS', 'TAIL'])
                      .describe(
                        'HEAD when the head component exceeds half the wind speed, TAIL below minus half, CROSS otherwise. Always shown with its label and an arrow, not by colour alone.'
                      ),
                    headwind: zod
                      .number()
                      .describe('Mean head component, km/h, signed: positive against the rider'),
                  })
                  .describe(
                    'The wind on the stretch between two checkpoints, as the rider meets it'
                  )
              )
              .describe('The wind stretch by stretch, from one checkpoint to the next'),
            windExposure: zod
              .object({
                head: zod.number().describe('Metres with a HEAD wind'),
                cross: zod.number().describe('Metres with a CROSS wind'),
                tail: zod.number().describe('Metres with a TAIL wind'),
              })
              .describe('Distance ridden against, across and with the wind'),
            prevailingWind: zod
              .object({
                speed: zod.number().describe('Mean wind speed, km/h'),
                gusts: zod
                  .number()
                  .optional()
                  .describe('Gusts, km/h. Absent when the model gives none.'),
                direction: zod
                  .number()
                  .describe(
                    'Direction the wind comes FROM, degrees clockwise from north (0 = from the north, 90 = from the east)'
                  ),
                compass: zod
                  .enum(['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'])
                  .describe(
                    'direction on the eight-point rose, still the direction the wind comes FROM'
                  ),
              })
              .optional()
              .describe(
                "The leg's dominant wind: circular mean of the directions, mean speed, highest gust"
              ),
            rainAlert: zod
              .object({
                probability: zod.int().describe('Probability of precipitation then, % (0–100)'),
                time: zod.iso
                  .datetime({ offset: true })
                  .describe('When — the passage at the checkpoint, or the hour'),
                distance: zod
                  .number()
                  .optional()
                  .describe(
                    "Where, metres from the start of the leg. Absent in a ride's summary, which only knows the departure point."
                  ),
                condition: zod
                  .enum([
                    'CLEAR',
                    'MOSTLY_CLEAR',
                    'PARTLY_CLOUDY',
                    'OVERCAST',
                    'FOG',
                    'DRIZZLE',
                    'RAIN',
                    'HEAVY_RAIN',
                    'FREEZING_RAIN',
                    'SHOWERS',
                    'SNOW',
                    'THUNDERSTORM',
                  ])
                  .describe('The condition forecast then'),
              })
              .optional()
              .describe('The first checkpoint where rain becomes likely, if any'),
            summary: zod
              .object({
                status: zod
                  .enum([
                    'OK',
                    'STALE',
                    'NOT_YET_AVAILABLE',
                    'UNAVAILABLE',
                    'NO_LOCATION',
                    'OUT_OF_RANGE',
                  ])
                  .describe('OK, STALE or NOT_YET_AVAILABLE'),
                availableFrom: zod.iso
                  .datetime({ offset: true })
                  .optional()
                  .describe(
                    'For NOT_YET_AVAILABLE: when the forecast opens, seven days before the departure'
                  ),
                weatherCode: zod.int().optional().describe('WMO code at the departure hour'),
                condition: zod
                  .enum([
                    'CLEAR',
                    'MOSTLY_CLEAR',
                    'PARTLY_CLOUDY',
                    'OVERCAST',
                    'FOG',
                    'DRIZZLE',
                    'RAIN',
                    'HEAVY_RAIN',
                    'FREEZING_RAIN',
                    'SHOWERS',
                    'SNOW',
                    'THUNDERSTORM',
                  ])
                  .optional()
                  .describe(
                    'weatherCode folded into a condition, same table as WeatherConditionsDto.condition'
                  ),
                daylight: zod
                  .boolean()
                  .optional()
                  .describe(
                    'Whether the departure itself (not the round model hour read for it) is between sunrise and sunset'
                  ),
                temperature: zod
                  .number()
                  .optional()
                  .describe('Air temperature at the departure hour, °C'),
                temperatureMin: zod
                  .number()
                  .optional()
                  .describe('Lowest temperature over the window, °C'),
                temperatureMax: zod
                  .number()
                  .optional()
                  .describe('Highest temperature over the window, °C'),
                maxPrecipitationProbability: zod
                  .int()
                  .optional()
                  .describe(
                    'Highest probability of precipitation over the window, %. Absent when the model gives none.'
                  ),
                wind: zod
                  .object({
                    speed: zod.number().describe('Mean wind speed, km/h'),
                    gusts: zod
                      .number()
                      .optional()
                      .describe('Gusts, km/h. Absent when the model gives none.'),
                    direction: zod
                      .number()
                      .describe(
                        'Direction the wind comes FROM, degrees clockwise from north (0 = from the north, 90 = from the east)'
                      ),
                    compass: zod
                      .enum(['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'])
                      .describe(
                        'direction on the eight-point rose, still the direction the wind comes FROM'
                      ),
                  })
                  .optional()
                  .describe('Wind at the departure hour'),
                rainAlert: zod
                  .object({
                    probability: zod.int().describe('Probability of precipitation then, % (0–100)'),
                    time: zod.iso
                      .datetime({ offset: true })
                      .describe('When — the passage at the checkpoint, or the hour'),
                    distance: zod
                      .number()
                      .optional()
                      .describe(
                        "Where, metres from the start of the leg. Absent in a ride's summary, which only knows the departure point."
                      ),
                    condition: zod
                      .enum([
                        'CLEAR',
                        'MOSTLY_CLEAR',
                        'PARTLY_CLOUDY',
                        'OVERCAST',
                        'FOG',
                        'DRIZZLE',
                        'RAIN',
                        'HEAVY_RAIN',
                        'FREEZING_RAIN',
                        'SHOWERS',
                        'SNOW',
                        'THUNDERSTORM',
                      ])
                      .describe('The condition forecast then'),
                  })
                  .optional()
                  .describe(
                    "The first hour of the window with rain likely (50 % or more). Its distance is absent on a ride's summary, present on a trip stage's (the checkpoint's)"
                  ),
                timezone: zod
                  .string()
                  .optional()
                  .describe(
                    "IANA zone the times of this summary (rain alert) are read in, as rendezvous with no zone mention. Set on a trip's card, where it is its next stage's zone — not TripDto.timezone, the first stage's. Absent elsewhere: the owner's timezone (RideDto, TripStageDto) applies."
                  ),
              })
              .optional()
              .describe(
                "The leg's weather in one line, for its card: the first checkpoint's hour, the extremes over the checkpoints, the rain alert — as TripStageWeatherDto.summary for a stage. Present when status is OK, STALE or NOT_YET_AVAILABLE (then status and availableFrom only)."
              ),
            departure: zod
              .object({
                status: zod
                  .enum([
                    'OK',
                    'STALE',
                    'NOT_YET_AVAILABLE',
                    'UNAVAILABLE',
                    'NO_LOCATION',
                    'OUT_OF_RANGE',
                  ])
                  .describe(
                    'State of the departure forecast. conditions is present for OK and STALE only.'
                  ),
                conditions: zod
                  .object({
                    time: zod.iso
                      .datetime({ offset: true })
                      .describe('The forecast hour used: the one nearest the moment asked about'),
                    weatherCode: zod
                      .int()
                      .describe(
                        'WMO weather interpretation code, as the model gives it. condition is its folding; a client reads condition, this is for the curious.'
                      ),
                    condition: zod
                      .enum([
                        'CLEAR',
                        'MOSTLY_CLEAR',
                        'PARTLY_CLOUDY',
                        'OVERCAST',
                        'FOG',
                        'DRIZZLE',
                        'RAIN',
                        'HEAVY_RAIN',
                        'FREEZING_RAIN',
                        'SHOWERS',
                        'SNOW',
                        'THUNDERSTORM',
                      ])
                      .describe(
                        'weatherCode folded into what a rider decides on. WMO code → condition: 0 CLEAR; 1 MOSTLY_CLEAR; 2 PARTLY_CLOUDY; 3 OVERCAST; 45, 48 FOG; 51, 53, 55 DRIZZLE; 56, 57, 66, 67 FREEZING_RAIN; 61, 63 RAIN; 65 HEAVY_RAIN; 71, 73, 75, 77, 85, 86 SNOW; 80, 81, 82 SHOWERS; 95, 96, 99 THUNDERSTORM; any other OVERCAST. A client meeting a value it does not know shows a plain cloud.'
                      ),
                    daylight: zod
                      .boolean()
                      .describe(
                        "Whether the moment asked about (the departure, the checkpoint's passage) falls between sunrise and sunset at that place — not time, the round model hour. Picks the day or night icon"
                      ),
                    temperature: zod.number().describe('Air temperature at 2 m, °C'),
                    apparentTemperature: zod
                      .number()
                      .describe('Felt temperature (wind chill, humidity), °C'),
                    precipitationProbability: zod
                      .int()
                      .optional()
                      .describe(
                        'Probability of precipitation, % (0–100). Absent when the model gives none.'
                      ),
                    precipitation: zod
                      .number()
                      .describe('Precipitation over the hour (rain, showers, snow), mm'),
                    wind: zod
                      .object({
                        speed: zod.number().describe('Mean wind speed, km/h'),
                        gusts: zod
                          .number()
                          .optional()
                          .describe('Gusts, km/h. Absent when the model gives none.'),
                        direction: zod
                          .number()
                          .describe(
                            'Direction the wind comes FROM, degrees clockwise from north (0 = from the north, 90 = from the east)'
                          ),
                        compass: zod
                          .enum(['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'])
                          .describe(
                            'direction on the eight-point rose, still the direction the wind comes FROM'
                          ),
                      })
                      .describe('Wind of that hour'),
                  })
                  .optional()
                  .describe('The forecast of the departure hour, for OK and STALE'),
                sunrise: zod.iso
                  .datetime({ offset: true })
                  .optional()
                  .describe("Sunrise at the meeting point, on the departure's local date"),
                sunset: zod.iso
                  .datetime({ offset: true })
                  .optional()
                  .describe("Sunset at the meeting point, on the departure's local date"),
                fetchedAt: zod.iso
                  .datetime({ offset: true })
                  .optional()
                  .describe('When the forecast of the meeting point was last fetched'),
              })
              .optional()
              .describe(
                "For a ride's leg: the weather at the ride's meeting point when this group leaves (startTime), sunrise and sunset included — RideWeatherDto.departure is the same at the ride's own time. Same states: conditions for OK and STALE only, UNAVAILABLE when the cache has no hour near the group's start, NOT_YET_AVAILABLE when the group leaves beyond the horizon. Absent on a trip's legs, whose departure TripStageWeatherDto.departure carries."
              ),
          })
          .describe(
            'The weather along one ridden route: a group of a ride, or a stage of a trip. Passages are estimated from startTime at averageSpeed.'
          )
      )
      .describe(
        'One per group, in group order; a single one without groupId for a ride without groups. Empty for OUT_OF_RANGE, NO_LOCATION and NOT_YET_AVAILABLE.'
      ),
    attribution: zod
      .object({
        name: zod.string().describe('Name to display, e.g. "Open-Meteo.com"'),
        url: zod.string().describe('Link of the credit'),
      })
      .describe("The credit the forecast's licence asks for"),
  })
  .describe(
    "A ride's weather, for its detail page: the meeting point at departure, then one leg per group. Read from the server's cache only — the forecast is refreshed in the background, never on request."
  )
