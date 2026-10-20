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
                .describe('Array of [lon, lat] coordinates'),
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
                "Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL) by Stadia Maps"
              ),
          })
          .describe('GPX track with track points')
      )
      .describe('Tracks'),
    waypoints: zod
      .array(
        zod.object({
          geometry: zod
            .object({
              type: zod.enum(['Point']),
              coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
            })
            .describe('Location coordinates [longitude, latitude]'),
          name: zod.string().optional(),
        })
      )
      .describe('Waypoints'),
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

export const createPreviewFromPointsBodyPlannerStateSourcesMax = 8

export const createPreviewFromPointsBodyPlannerStateJunctionsMax = 2001

export const createPreviewFromPointsBodyPlannerStatePiecesItemLineMax = 2000000

export const createPreviewFromPointsBodyPlannerStatePiecesItemEleMax = 2000000

export const createPreviewFromPointsBodyPlannerStatePiecesItemUnpavedItemFromMin = 0

export const createPreviewFromPointsBodyPlannerStatePiecesItemUnpavedMax = 50000

export const createPreviewFromPointsBodyPlannerStatePiecesMax = 2000

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
            })
          )
          .max(createPreviewFromPointsBodyPlannerStatePiecesMax),
      })
      .optional()
      .describe(
        'Editing state of the planner; the server derives the track from it. Not with points'
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
                .describe('Array of [lon, lat] coordinates'),
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
                "Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL) by Stadia Maps"
              ),
          })
          .describe('GPX track with track points')
      )
      .describe('Tracks'),
    waypoints: zod
      .array(
        zod.object({
          geometry: zod
            .object({
              type: zod.enum(['Point']),
              coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
            })
            .describe('Location coordinates [longitude, latitude]'),
          name: zod.string().optional(),
        })
      )
      .describe('Waypoints'),
  })
  .describe('Analysed GPX file, not attached to any team')

/**
 * Uploads 2 to 10 GPX files (10 MB together at most) and merges all their tracks into a single track, choosing the order of the tracks and the direction each one is ridden in so that the summed straight-line gaps between them are as short as possible. The result then runs the same pipeline as a single upload and is stored the same way, for 30 days
 * @summary Merge several GPX files into one analysed GPX file
 */
export const MergePreviewsBody = zod.object({
  gpxFiles: zod.array(zod.instanceof(Blob)).optional(),
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
                .describe('Array of [lon, lat] coordinates'),
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
                "Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL) by Stadia Maps"
              ),
          })
          .describe('GPX track with track points')
      )
      .describe('Tracks'),
    waypoints: zod
      .array(
        zod.object({
          geometry: zod
            .object({
              type: zod.enum(['Point']),
              coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
            })
            .describe('Location coordinates [longitude, latitude]'),
          name: zod.string().optional(),
        })
      )
      .describe('Waypoints'),
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

export const updatePreviewBodyPreviewPlannerStateSourcesMax = 8

export const updatePreviewBodyPreviewPlannerStateJunctionsMax = 2001

export const updatePreviewBodyPreviewPlannerStatePiecesItemLineMax = 2000000

export const updatePreviewBodyPreviewPlannerStatePiecesItemEleMax = 2000000

export const updatePreviewBodyPreviewPlannerStatePiecesItemUnpavedItemFromMin = 0

export const updatePreviewBodyPreviewPlannerStatePiecesItemUnpavedMax = 50000

export const updatePreviewBodyPreviewPlannerStatePiecesMax = 2000

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
              })
            )
            .max(updatePreviewBodyPreviewPlannerStatePiecesMax),
        })
        .optional()
        .describe(
          'Editing state of the planner; the server derives the track from it. Not with points (400 PLANNER_STATE_INVALID); a gpxFile wins over it'
        ),
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
                .describe('Array of [lon, lat] coordinates'),
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
                "Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL) by Stadia Maps"
              ),
          })
          .describe('GPX track with track points')
      )
      .describe('Tracks'),
    waypoints: zod
      .array(
        zod.object({
          geometry: zod
            .object({
              type: zod.enum(['Point']),
              coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
            })
            .describe('Location coordinates [longitude, latitude]'),
          name: zod.string().optional(),
        })
      )
      .describe('Waypoints'),
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
                .describe('Array of [lon, lat] coordinates'),
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
                "Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL) by Stadia Maps"
              ),
          })
          .describe('GPX track with track points')
      )
      .describe('Tracks'),
    waypoints: zod
      .array(
        zod.object({
          geometry: zod
            .object({
              type: zod.enum(['Point']),
              coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
            })
            .describe('Location coordinates [longitude, latitude]'),
          name: zod.string().optional(),
        })
      )
      .describe('Waypoints'),
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

export const getPreviewPlannerStateResponseStateSourcesMax = 8

export const getPreviewPlannerStateResponseStateJunctionsMax = 2001

export const getPreviewPlannerStateResponseStatePiecesItemLineMax = 2000000

export const getPreviewPlannerStateResponseStatePiecesItemEleMax = 2000000

export const getPreviewPlannerStateResponseStatePiecesItemUnpavedItemFromMin = 0

export const getPreviewPlannerStateResponseStatePiecesItemUnpavedMax = 50000

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

export const createRouteFromPreviewBodyPlannerStateSourcesMax = 8

export const createRouteFromPreviewBodyPlannerStateJunctionsMax = 2001

export const createRouteFromPreviewBodyPlannerStatePiecesItemLineMax = 2000000

export const createRouteFromPreviewBodyPlannerStatePiecesItemEleMax = 2000000

export const createRouteFromPreviewBodyPlannerStatePiecesItemUnpavedItemFromMin = 0

export const createRouteFromPreviewBodyPlannerStatePiecesItemUnpavedMax = 50000

export const createRouteFromPreviewBodyPlannerStatePiecesMax = 2000

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
            })
          )
          .max(createRouteFromPreviewBodyPlannerStatePiecesMax),
      })
      .optional()
      .describe(
        'Editing state of the planner; the server derives the track from it. Not with points (400 PLANNER_STATE_INVALID); a gpxFile wins over it'
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
            "URL template of the team's logo (with a {size} placeholder), when it has one. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team. Opaque URL: may carry a query string; substitute {size} only."
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
  })
  .describe('Route summary data')
