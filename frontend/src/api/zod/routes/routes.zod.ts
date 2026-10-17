import * as zod from 'zod'

/**
 * Get paginated list of routes from all accessible teams (user's teams + public teams)
 * @summary List all routes
 */
export const listAllRoutesQueryPageDefault = 0
export const listAllRoutesQuerySizeDefault = 20

export const ListAllRoutesQueryParams = zod.object({
  hilliness: zod
    .enum(['FLAT', 'HILLY', 'MOUNTAINOUS'])
    .optional()
    .describe('Hilliness preset (FLAT, HILLY, MOUNTAINOUS)'),
  maxDistance: zod.number().optional().describe('Maximum distance in meters'),
  maxElevationGain: zod.number().optional().describe('Maximum elevation gain in meters'),
  minDistance: zod.number().optional().describe('Minimum distance in meters'),
  minElevationGain: zod.number().optional().describe('Minimum elevation gain in meters'),
  minRole: zod
    .enum(['MEMBER', 'ORGANIZER', 'ADMIN'])
    .optional()
    .describe(
      'Only routes from teams where the user has at least this role. Yields nothing for an anonymous visitor.'
    ),
  nearLat: zod.number().optional().describe('Latitude for proximity search'),
  nearLon: zod.number().optional().describe('Longitude for proximity search'),
  nearRadius: zod.number().optional().describe('Search radius in meters (default: 25000)'),
  nearType: zod
    .enum(['START', 'END', 'START_OR_END'])
    .optional()
    .describe('Search near START, END, or START_OR_END (default)'),
  page: zod.int().default(listAllRoutesQueryPageDefault).describe('Page number (0-indexed)'),
  search: zod.string().optional().describe('Search by name/markdown'),
  size: zod.int().default(listAllRoutesQuerySizeDefault).describe('Page size'),
  sortBy: zod
    .enum(['DISTANCE', 'ELEVATION_GAIN', 'HILLINESS', 'DATE_TIME'])
    .optional()
    .describe('Sort by field (DISTANCE, ELEVATION_GAIN, HILLINESS, DATE_TIME)'),
  sortDir: zod.enum(['ASC', 'DESC']).optional().describe('Sort direction (ASC, DESC)'),
  surfaceType: zod
    .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
    .optional()
    .describe('Filter by surface type'),
  view: zod
    .enum(['FULL', 'COMPACT'])
    .optional()
    .describe(
      "How much of each row to send. COMPACT (case-insensitive) returns media.markdown empty and media.assets trimmed to the logo, the first image and the themed thumbnails — read 'excerpt' and 'thumbnailUrl' instead, both of which are present either way. The markdown body, the attachments, the GPX and FIT files and every image past the first are dropped. Omitted, or FULL, is the previous behaviour, byte for byte."
    ),
  windDirection: zod
    .enum([
      'NORTH',
      'NORTH_EAST',
      'EAST',
      'SOUTH_EAST',
      'SOUTH',
      'SOUTH_WEST',
      'WEST',
      'NORTH_WEST',
    ])
    .optional()
    .describe('Filter by wind direction'),
})

export const listAllRoutesResponseRoutesItemMediaMarkdownMax = 100000

export const ListAllRoutesResponse = zod
  .object({
    routes: zod
      .array(
        zod
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
                  .max(listAllRoutesResponseRoutesItemMediaMarkdownMax)
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
                      .enum([
                        'INDIGO',
                        'BLUE',
                        'GREEN',
                        'RED',
                        'YELLOW',
                        'ORANGE',
                        'GRAPE',
                        'TEAL',
                        'GRAY',
                      ])
                      .describe('Colour family'),
                  })
                  .describe('A team tag on a content')
              )
              .describe(
                "The team's ROUTE tags the route carries, sorted by label. Empty when it carries none."
              ),
          })
          .describe('Route summary data')
      )
      .describe('List of routes'),
    total: zod.int().describe('Total number of routes'),
    page: zod.int().describe('Current page number'),
    size: zod.int().describe('Page size'),
  })
  .describe('Paginated route list response')

/**
 * Extent enclosing the routes of all accessible teams, so a map can open framed on them. Accepts the same filters as the route list, minus sorting and pagination. Yields a null box when no route matches.
 * @summary All routes bounding box
 */
export const GetAllRoutesBoundsQueryParams = zod.object({
  hilliness: zod
    .enum(['FLAT', 'HILLY', 'MOUNTAINOUS'])
    .optional()
    .describe('Hilliness preset (FLAT, HILLY, MOUNTAINOUS)'),
  maxDistance: zod.number().optional().describe('Maximum distance in meters'),
  maxElevationGain: zod.number().optional().describe('Maximum elevation gain in meters'),
  minDistance: zod.number().optional().describe('Minimum distance in meters'),
  minElevationGain: zod.number().optional().describe('Minimum elevation gain in meters'),
  minRole: zod
    .enum(['MEMBER', 'ORGANIZER', 'ADMIN'])
    .optional()
    .describe(
      'Only routes from teams where the user has at least this role. Yields a null box for an anonymous visitor.'
    ),
  nearLat: zod.number().optional().describe('Latitude for proximity search'),
  nearLon: zod.number().optional().describe('Longitude for proximity search'),
  nearRadius: zod.number().optional().describe('Search radius in meters (default: 25000)'),
  nearType: zod
    .enum(['START', 'END', 'START_OR_END'])
    .optional()
    .describe('Search near START, END, or START_OR_END (default)'),
  search: zod.string().optional().describe('Search by name/markdown'),
  surfaceType: zod
    .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
    .optional()
    .describe('Filter by surface type'),
  windDirection: zod
    .enum([
      'NORTH',
      'NORTH_EAST',
      'EAST',
      'SOUTH_EAST',
      'SOUTH',
      'SOUTH_WEST',
      'WEST',
      'NORTH_WEST',
    ])
    .optional()
    .describe('Filter by wind direction'),
})

export const GetAllRoutesBoundsResponse = zod
  .object({
    bounds: zod
      .object({
        minLon: zod.number().describe('Western edge'),
        minLat: zod.number().describe('Southern edge'),
        maxLon: zod.number().describe('Eastern edge'),
        maxLat: zod.number().describe('Northern edge'),
      })
      .optional()
      .describe('Bounding box, or null when no route matches'),
  })
  .describe('Bounding box of the routes matching a filter set')

/**
 * How many routes of all accessible teams match the filters, with none of them read. Accepts exactly the same filters as the route list, minus sorting and pagination, so the figure and the list it opens can never disagree. Meant for a filter sheet that wants to announce its result count before the user commits to it.
 * @summary Count all routes
 */
export const CountAllRoutesQueryParams = zod.object({
  hilliness: zod
    .enum(['FLAT', 'HILLY', 'MOUNTAINOUS'])
    .optional()
    .describe('Hilliness preset (FLAT, HILLY, MOUNTAINOUS)'),
  maxDistance: zod.number().optional().describe('Maximum distance in meters'),
  maxElevationGain: zod.number().optional().describe('Maximum elevation gain in meters'),
  minDistance: zod.number().optional().describe('Minimum distance in meters'),
  minElevationGain: zod.number().optional().describe('Minimum elevation gain in meters'),
  minRole: zod
    .enum(['MEMBER', 'ORGANIZER', 'ADMIN'])
    .optional()
    .describe(
      'Only routes from teams where the user has at least this role. Yields zero for an anonymous visitor.'
    ),
  nearLat: zod.number().optional().describe('Latitude for proximity search'),
  nearLon: zod.number().optional().describe('Longitude for proximity search'),
  nearRadius: zod.number().optional().describe('Search radius in meters (default: 25000)'),
  nearType: zod
    .enum(['START', 'END', 'START_OR_END'])
    .optional()
    .describe('Search near START, END, or START_OR_END (default)'),
  search: zod.string().optional().describe('Search by name/markdown'),
  surfaceType: zod
    .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
    .optional()
    .describe('Filter by surface type'),
  windDirection: zod
    .enum([
      'NORTH',
      'NORTH_EAST',
      'EAST',
      'SOUTH_EAST',
      'SOUTH',
      'SOUTH_WEST',
      'WEST',
      'NORTH_WEST',
    ])
    .optional()
    .describe('Filter by wind direction'),
})

export const CountAllRoutesResponse = zod
  .object({
    total: zod.int().describe('Total number of matching items'),
  })
  .describe('Number of items matching a filter set')

/**
 * Mapbox vector tile holding the routes of all accessible teams, layer 'routes'. Accepts the same filters as the route list, minus sorting and pagination, which a tile has no use for. Fetched directly by the map renderer, outside the authenticated HTTP stack: a browser authenticates with its session cookie, any other client with the 't' tile token.
 * @summary All routes vector tile
 */
export const AllRoutesTileParams = zod.object({
  x: zod.int().describe('Tile column'),
  y: zod.int().describe('Tile row'),
  z: zod.int().describe('Zoom level'),
})

export const AllRoutesTileQueryParams = zod.object({
  hilliness: zod
    .enum(['FLAT', 'HILLY', 'MOUNTAINOUS'])
    .optional()
    .describe('Hilliness preset (FLAT, HILLY, MOUNTAINOUS)'),
  maxDistance: zod.number().optional().describe('Maximum distance in meters'),
  maxElevationGain: zod.number().optional().describe('Maximum elevation gain in meters'),
  minDistance: zod.number().optional().describe('Minimum distance in meters'),
  minElevationGain: zod.number().optional().describe('Minimum elevation gain in meters'),
  minRole: zod
    .enum(['MEMBER', 'ORGANIZER', 'ADMIN'])
    .optional()
    .describe(
      'Only routes from teams where the user has at least this role. Yields an empty tile for an anonymous visitor.'
    ),
  nearLat: zod.number().optional().describe('Latitude for proximity search'),
  nearLon: zod.number().optional().describe('Longitude for proximity search'),
  nearRadius: zod.number().optional().describe('Search radius in meters (default: 25000)'),
  nearType: zod
    .enum(['START', 'END', 'START_OR_END'])
    .optional()
    .describe('Search near START, END, or START_OR_END (default)'),
  search: zod.string().optional().describe('Search by name/markdown'),
  surfaceType: zod
    .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
    .optional()
    .describe('Filter by surface type'),
  t: zod
    .string()
    .optional()
    .describe(
      'Tile token from POST /api/tiles/token, for clients whose map renderer cannot carry an Authorization header. Omitted, the request falls back to the session cookie and then to the anonymous visitor.'
    ),
  windDirection: zod
    .enum([
      'NORTH',
      'NORTH_EAST',
      'EAST',
      'SOUTH_EAST',
      'SOUTH',
      'SOUTH_WEST',
      'WEST',
      'NORTH_WEST',
    ])
    .optional()
    .describe('Filter by wind direction'),
})

export const AllRoutesTileResponse = zod.unknown()

/**
 * Get paginated list of routes for a team with optional filters and sorting
 * @summary List routes
 */
export const ListRoutesParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const listRoutesQueryPageDefault = 0
export const listRoutesQuerySizeDefault = 20

export const ListRoutesQueryParams = zod.object({
  hilliness: zod
    .enum(['FLAT', 'HILLY', 'MOUNTAINOUS'])
    .optional()
    .describe('Hilliness preset (FLAT, HILLY, MOUNTAINOUS)'),
  maxDistance: zod.number().optional().describe('Maximum distance in meters'),
  maxElevationGain: zod.number().optional().describe('Maximum elevation gain in meters'),
  minDistance: zod.number().optional().describe('Minimum distance in meters'),
  minElevationGain: zod.number().optional().describe('Minimum elevation gain in meters'),
  nearLat: zod.number().optional().describe('Latitude for proximity search'),
  nearLon: zod.number().optional().describe('Longitude for proximity search'),
  nearRadius: zod.number().optional().describe('Search radius in meters (default: 25000)'),
  nearType: zod
    .enum(['START', 'END', 'START_OR_END'])
    .optional()
    .describe('Search near START, END, or START_OR_END (default)'),
  page: zod.int().default(listRoutesQueryPageDefault).describe('Page number (0-indexed)'),
  search: zod.string().optional().describe('Search by name/markdown'),
  size: zod.int().default(listRoutesQuerySizeDefault).describe('Page size'),
  sortBy: zod
    .enum(['DISTANCE', 'ELEVATION_GAIN', 'HILLINESS', 'DATE_TIME'])
    .optional()
    .describe('Sort by field (DISTANCE, ELEVATION_GAIN, HILLINESS, DATE_TIME)'),
  sortDir: zod.enum(['ASC', 'DESC']).optional().describe('Sort direction (ASC, DESC)'),
  surfaceType: zod
    .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
    .optional()
    .describe('Filter by surface type'),
  tags: zod
    .array(zod.string())
    .optional()
    .describe(
      "Only the routes carrying at least one of these tags — ids (TSID) of the team's ROUTE tags, comma-separated or repeated. Unknown ids are ignored; a filter left with no known id filters nothing."
    ),
  view: zod
    .enum(['FULL', 'COMPACT'])
    .optional()
    .describe(
      "How much of each row to send. COMPACT (case-insensitive) returns media.markdown empty and media.assets trimmed to the logo, the first image and the themed thumbnails — read 'excerpt' and 'thumbnailUrl' instead, both of which are present either way. The markdown body, the attachments, the GPX and FIT files and every image past the first are dropped. Omitted, or FULL, is the previous behaviour, byte for byte."
    ),
  windDirection: zod
    .enum([
      'NORTH',
      'NORTH_EAST',
      'EAST',
      'SOUTH_EAST',
      'SOUTH',
      'SOUTH_WEST',
      'WEST',
      'NORTH_WEST',
    ])
    .optional()
    .describe('Filter by wind direction'),
})

export const listRoutesResponseRoutesItemMediaMarkdownMax = 100000

export const ListRoutesResponse = zod
  .object({
    routes: zod
      .array(
        zod
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
                  .max(listRoutesResponseRoutesItemMediaMarkdownMax)
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
                      .enum([
                        'INDIGO',
                        'BLUE',
                        'GREEN',
                        'RED',
                        'YELLOW',
                        'ORANGE',
                        'GRAPE',
                        'TEAL',
                        'GRAY',
                      ])
                      .describe('Colour family'),
                  })
                  .describe('A team tag on a content')
              )
              .describe(
                "The team's ROUTE tags the route carries, sorted by label. Empty when it carries none."
              ),
          })
          .describe('Route summary data')
      )
      .describe('List of routes'),
    total: zod.int().describe('Total number of routes'),
    page: zod.int().describe('Current page number'),
    size: zod.int().describe('Page size'),
  })
  .describe('Paginated route list response')

/**
 * Create a new route by uploading a GPX file
 * @summary Create route
 */
export const CreateRouteParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const createRouteBodyRouteNameMin = 3
export const createRouteBodyRouteNameMax = 200

export const createRouteBodyRouteNameRegExp = new RegExp('\\S')
export const createRouteBodyRouteMediaMarkdownMax = 100000

export const createRouteBodyRoutePointsItemLngMin = -180
export const createRouteBodyRoutePointsItemLngMax = 180

export const createRouteBodyRoutePointsItemLatMin = -90
export const createRouteBodyRoutePointsItemLatMax = 90

export const createRouteBodyRoutePointsMax = 100000

export const CreateRouteBody = zod.object({
  route: zod
    .object({
      name: zod
        .string()
        .min(createRouteBodyRouteNameMin)
        .max(createRouteBodyRouteNameMax)
        .regex(createRouteBodyRouteNameRegExp)
        .describe('Route name'),
      media: zod
        .object({
          markdown: zod.string().max(createRouteBodyRouteMediaMarkdownMax).describe('Markdown'),
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
              .min(createRouteBodyRoutePointsItemLngMin)
              .max(createRouteBodyRoutePointsItemLngMax),
            lat: zod
              .number()
              .min(createRouteBodyRoutePointsItemLatMin)
              .max(createRouteBodyRoutePointsItemLatMax),
          })
        )
        .max(createRouteBodyRoutePointsMax)
        .optional()
        .describe('Points from frontend routing'),
      tagIds: zod
        .array(zod.string())
        .optional()
        .describe(
          "IDs (TSID) of the team's ROUTE tags the route carries, replacing the whole set — at most 10, each a tag of this team and of kind ROUTE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update."
        ),
    })
    .optional()
    .describe('Route update request'),
  gpxFile: zod.instanceof(Blob).optional(),
})

export const createRouteResponseMediaMarkdownMax = 100000

export const CreateRouteResponse = zod
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
        markdown: zod.string().max(createRouteResponseMediaMarkdownMax).describe('Markdown'),
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

/**
 * Extent enclosing the team's routes, so a map can open framed on them. Accepts the same filters as the route list, minus sorting and pagination. Yields a null box when no route matches.
 * @summary Team routes bounding box
 */
export const GetRoutesBoundsParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const GetRoutesBoundsQueryParams = zod.object({
  hilliness: zod
    .enum(['FLAT', 'HILLY', 'MOUNTAINOUS'])
    .optional()
    .describe('Hilliness preset (FLAT, HILLY, MOUNTAINOUS)'),
  maxDistance: zod.number().optional().describe('Maximum distance in meters'),
  maxElevationGain: zod.number().optional().describe('Maximum elevation gain in meters'),
  minDistance: zod.number().optional().describe('Minimum distance in meters'),
  minElevationGain: zod.number().optional().describe('Minimum elevation gain in meters'),
  nearLat: zod.number().optional().describe('Latitude for proximity search'),
  nearLon: zod.number().optional().describe('Longitude for proximity search'),
  nearRadius: zod.number().optional().describe('Search radius in meters (default: 25000)'),
  nearType: zod
    .enum(['START', 'END', 'START_OR_END'])
    .optional()
    .describe('Search near START, END, or START_OR_END (default)'),
  search: zod.string().optional().describe('Search by name/markdown'),
  surfaceType: zod
    .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
    .optional()
    .describe('Filter by surface type'),
  tags: zod
    .array(zod.string())
    .optional()
    .describe(
      "Only the routes carrying at least one of these tags — ids (TSID) of the team's ROUTE tags, comma-separated or repeated. Unknown ids are ignored; a filter left with no known id filters nothing."
    ),
  windDirection: zod
    .enum([
      'NORTH',
      'NORTH_EAST',
      'EAST',
      'SOUTH_EAST',
      'SOUTH',
      'SOUTH_WEST',
      'WEST',
      'NORTH_WEST',
    ])
    .optional()
    .describe('Filter by wind direction'),
})

export const GetRoutesBoundsResponse = zod
  .object({
    bounds: zod
      .object({
        minLon: zod.number().describe('Western edge'),
        minLat: zod.number().describe('Southern edge'),
        maxLon: zod.number().describe('Eastern edge'),
        maxLat: zod.number().describe('Northern edge'),
      })
      .optional()
      .describe('Bounding box, or null when no route matches'),
  })
  .describe('Bounding box of the routes matching a filter set')

/**
 * The detail of every requested 'slug' that exists and the caller may read, in one round-trip — built for the screens that load several routes together (a ride's stages, a comparison view), which would otherwise cost one request per route. Each row is exactly what the single-route endpoint returns, geometry included. Unknown slugs and slugs the caller may not read are silently left out of the answer rather than failing the whole batch. Set 'geometry' to false for the screens that only need each route's name and figures. The response also carries the bounding box of the track geometry actually sent back (waypoints are excluded, so an imported meeting-point or car-park waypoint far off the track cannot widen it), so a map can frame the batch without a second request.
 * @summary Get several routes' details at once
 */
export const GetRoutesBulkParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const getRoutesBulkQueryGeometryDefault = true

export const GetRoutesBulkQueryParams = zod.object({
  geometry: zod
    .boolean()
    .default(getRoutesBulkQueryGeometryDefault)
    .describe(
      "Whether to include each route's track geometry. False answers metadata only — name, distances, media, asset links — with an empty 'tracks' array and no 'extent', for the screens that name routes without drawing them."
    ),
  slug: zod
    .array(zod.string())
    .optional()
    .describe(
      "Route slug to include, repeatable. Capped at 50; unknown slugs and slugs the caller may not read are silently omitted from the response rather than erroring. Unlike GET /{routeSlug}, a slug that was renamed is also omitted rather than followed to the route's current slug: the single-route endpoint falls back to the rename history, this one does not. Same 'omit, never fail' contract as an unknown or unreadable slug, just for a different reason."
    ),
})

export const getRoutesBulkResponseRoutesItemMediaMarkdownMax = 100000

export const GetRoutesBulkResponse = zod
  .object({
    routes: zod
      .array(
        zod
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
                  .max(getRoutesBulkResponseRoutesItemMediaMarkdownMax)
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
              .describe('Media'),
            distance: zod.number().describe('Distance in meters'),
            elevationGain: zod.number().describe('Total elevation gain in meters'),
            elevationLoss: zod.number().describe('Total elevation loss in meters'),
            surfaceType: zod.enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED']).describe('Surface type'),
            visibility: zod
              .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
              .describe('Whether the route is public'),
            start: zod
              .object({
                type: zod.enum(['Point']),
                coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
              })
              .optional()
              .describe('Location coordinates [longitude, latitude]'),
            end: zod
              .object({
                type: zod.enum(['Point']),
                coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
              })
              .optional()
              .describe('Location coordinates [longitude, latitude]'),
            createdBy: zod
              .object({
                id: zod.string().describe('User ID (TSID)'),
                displayName: zod.string().describe('User display name'),
                avatarUrl: zod.string().optional().describe('User avatar URL'),
              })
              .describe('Creator user'),
            createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
            updatedAt: zod.iso.datetime({ offset: true }).describe('Last update timestamp'),
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
                            startDistance: zod
                              .int()
                              .describe('Start distance from route start in meters'),
                            endDistance: zod
                              .int()
                              .describe('End distance from route start in meters'),
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
                  })
                  .describe('GPX track with track points')
              )
              .describe(
                "Tracks, with the stored geometry untouched — every coordinate carries longitude, latitude, elevation and cumulative distance in meters. Empty when the bulk endpoint was called with 'geometry=false'."
              ),
            waypoints: zod
              .array(
                zod.object({
                  geometry: zod
                    .object({
                      type: zod.enum(['Point']),
                      coordinates: zod
                        .array(zod.number())
                        .describe('Coordinates [longitude, latitude]'),
                    })
                    .describe('Location coordinates [longitude, latitude]'),
                  name: zod.string().optional(),
                })
              )
              .describe('Waypoints'),
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
                      .enum([
                        'INDIGO',
                        'BLUE',
                        'GREEN',
                        'RED',
                        'YELLOW',
                        'ORANGE',
                        'GRAPE',
                        'TEAL',
                        'GRAY',
                      ])
                      .describe('Colour family'),
                  })
                  .describe('A team tag on a content')
              )
              .describe(
                "The team's ROUTE tags the route carries, sorted by label. Empty when it carries none."
              ),
          })
          .describe('Detailed route information')
      )
      .describe('Route details, one per readable requested slug'),
    extent: zod
      .object({
        minLon: zod.number().describe('Western edge'),
        minLat: zod.number().describe('Southern edge'),
        maxLon: zod.number().describe('Eastern edge'),
        maxLat: zod.number().describe('Northern edge'),
      })
      .optional()
      .describe('Bounding box of every returned route, or null when routes is empty'),
  })
  .describe('Detail of several routes fetched at once, plus their combined extent')

/**
 * How many of the team's routes match the filters, with none of them read. Accepts exactly the same filters as the route list, minus sorting and pagination, so the figure and the list it opens can never disagree. Meant for a filter sheet that wants to announce its result count before the user commits to it.
 * @summary Count routes
 */
export const CountRoutesParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const CountRoutesQueryParams = zod.object({
  hilliness: zod
    .enum(['FLAT', 'HILLY', 'MOUNTAINOUS'])
    .optional()
    .describe('Hilliness preset (FLAT, HILLY, MOUNTAINOUS)'),
  maxDistance: zod.number().optional().describe('Maximum distance in meters'),
  maxElevationGain: zod.number().optional().describe('Maximum elevation gain in meters'),
  minDistance: zod.number().optional().describe('Minimum distance in meters'),
  minElevationGain: zod.number().optional().describe('Minimum elevation gain in meters'),
  nearLat: zod.number().optional().describe('Latitude for proximity search'),
  nearLon: zod.number().optional().describe('Longitude for proximity search'),
  nearRadius: zod.number().optional().describe('Search radius in meters (default: 25000)'),
  nearType: zod
    .enum(['START', 'END', 'START_OR_END'])
    .optional()
    .describe('Search near START, END, or START_OR_END (default)'),
  search: zod.string().optional().describe('Search by name/markdown'),
  surfaceType: zod
    .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
    .optional()
    .describe('Filter by surface type'),
  tags: zod
    .array(zod.string())
    .optional()
    .describe(
      "Only the routes carrying at least one of these tags — ids (TSID) of the team's ROUTE tags, comma-separated or repeated. Unknown ids are ignored; a filter left with no known id filters nothing."
    ),
  windDirection: zod
    .enum([
      'NORTH',
      'NORTH_EAST',
      'EAST',
      'SOUTH_EAST',
      'SOUTH',
      'SOUTH_WEST',
      'WEST',
      'NORTH_WEST',
    ])
    .optional()
    .describe('Filter by wind direction'),
})

export const CountRoutesResponse = zod
  .object({
    total: zod.int().describe('Total number of matching items'),
  })
  .describe('Number of items matching a filter set')

/**
 * Mapbox vector tile holding the team's routes, layer 'routes'. Accepts the same filters as the route list, minus sorting and pagination, which a tile has no use for. Fetched directly by the map renderer, outside the authenticated HTTP stack: a browser authenticates with its session cookie, any other client with the 't' tile token.
 * @summary Team routes vector tile
 */
export const RoutesTileParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  x: zod.int().describe('Tile column'),
  y: zod.int().describe('Tile row'),
  z: zod.int().describe('Zoom level'),
})

export const RoutesTileQueryParams = zod.object({
  hilliness: zod
    .enum(['FLAT', 'HILLY', 'MOUNTAINOUS'])
    .optional()
    .describe('Hilliness preset (FLAT, HILLY, MOUNTAINOUS)'),
  maxDistance: zod.number().optional().describe('Maximum distance in meters'),
  maxElevationGain: zod.number().optional().describe('Maximum elevation gain in meters'),
  minDistance: zod.number().optional().describe('Minimum distance in meters'),
  minElevationGain: zod.number().optional().describe('Minimum elevation gain in meters'),
  nearLat: zod.number().optional().describe('Latitude for proximity search'),
  nearLon: zod.number().optional().describe('Longitude for proximity search'),
  nearRadius: zod.number().optional().describe('Search radius in meters (default: 25000)'),
  nearType: zod
    .enum(['START', 'END', 'START_OR_END'])
    .optional()
    .describe('Search near START, END, or START_OR_END (default)'),
  search: zod.string().optional().describe('Search by name/markdown'),
  surfaceType: zod
    .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
    .optional()
    .describe('Filter by surface type'),
  t: zod
    .string()
    .optional()
    .describe(
      'Tile token from POST /api/tiles/token, for clients whose map renderer cannot carry an Authorization header. Omitted, the request falls back to the session cookie and then to the anonymous visitor.'
    ),
  tags: zod
    .array(zod.string())
    .optional()
    .describe(
      "Only the routes carrying at least one of these tags — ids (TSID) of the team's ROUTE tags, comma-separated or repeated. Unknown ids are ignored; a filter left with no known id filters nothing."
    ),
  windDirection: zod
    .enum([
      'NORTH',
      'NORTH_EAST',
      'EAST',
      'SOUTH_EAST',
      'SOUTH',
      'SOUTH_WEST',
      'WEST',
      'NORTH_WEST',
    ])
    .optional()
    .describe('Filter by wind direction'),
})

export const RoutesTileResponse = zod.unknown()

/**
 * Update route metadata (name, markdown, etc.) and optionally replace the GPX file. If a new GPX file is provided, the old track data and climbs will be replaced.
 * @summary Update route
 */
export const UpdateRouteParams = zod.object({
  routeSlug: zod.string().describe('Route slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const updateRouteBodyRouteNameMin = 3
export const updateRouteBodyRouteNameMax = 200

export const updateRouteBodyRouteNameRegExp = new RegExp('\\S')
export const updateRouteBodyRouteMediaMarkdownMax = 100000

export const updateRouteBodyRoutePointsItemLngMin = -180
export const updateRouteBodyRoutePointsItemLngMax = 180

export const updateRouteBodyRoutePointsItemLatMin = -90
export const updateRouteBodyRoutePointsItemLatMax = 90

export const updateRouteBodyRoutePointsMax = 100000

export const UpdateRouteBody = zod.object({
  route: zod
    .object({
      name: zod
        .string()
        .min(updateRouteBodyRouteNameMin)
        .max(updateRouteBodyRouteNameMax)
        .regex(updateRouteBodyRouteNameRegExp)
        .describe('Route name'),
      media: zod
        .object({
          markdown: zod.string().max(updateRouteBodyRouteMediaMarkdownMax).describe('Markdown'),
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
              .min(updateRouteBodyRoutePointsItemLngMin)
              .max(updateRouteBodyRoutePointsItemLngMax),
            lat: zod
              .number()
              .min(updateRouteBodyRoutePointsItemLatMin)
              .max(updateRouteBodyRoutePointsItemLatMax),
          })
        )
        .max(updateRouteBodyRoutePointsMax)
        .optional()
        .describe('Points from frontend routing'),
      tagIds: zod
        .array(zod.string())
        .optional()
        .describe(
          "IDs (TSID) of the team's ROUTE tags the route carries, replacing the whole set — at most 10, each a tag of this team and of kind ROUTE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update."
        ),
    })
    .optional()
    .describe('Route update request'),
  gpxFile: zod.instanceof(Blob).optional(),
})

export const updateRouteResponseMediaMarkdownMax = 100000

export const UpdateRouteResponse = zod
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
        markdown: zod.string().max(updateRouteResponseMediaMarkdownMax).describe('Markdown'),
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

/**
 * Get detailed route information including GPS coordinates and statistics. The track is returned exactly as stored — already resampled and Douglas-Peucker-filtered at import, which lands it at roughly one point every 90 m. Every coordinate carries longitude, latitude, elevation and cumulative distance in meters, so a client can draw both the line and its elevation profile from this one payload.
 * @summary Get route details
 */
export const GetRouteParams = zod.object({
  routeSlug: zod.string().describe('Route slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const getRouteResponseMediaMarkdownMax = 100000

export const GetRouteResponse = zod
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
        markdown: zod.string().max(getRouteResponseMediaMarkdownMax).describe('Markdown'),
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
    distance: zod.number().describe('Distance in meters'),
    elevationGain: zod.number().describe('Total elevation gain in meters'),
    elevationLoss: zod.number().describe('Total elevation loss in meters'),
    surfaceType: zod.enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED']).describe('Surface type'),
    visibility: zod
      .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
      .describe('Whether the route is public'),
    start: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe('Location coordinates [longitude, latitude]'),
    end: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe('Location coordinates [longitude, latitude]'),
    createdBy: zod
      .object({
        id: zod.string().describe('User ID (TSID)'),
        displayName: zod.string().describe('User display name'),
        avatarUrl: zod.string().optional().describe('User avatar URL'),
      })
      .describe('Creator user'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    updatedAt: zod.iso.datetime({ offset: true }).describe('Last update timestamp'),
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
          })
          .describe('GPX track with track points')
      )
      .describe(
        "Tracks, with the stored geometry untouched — every coordinate carries longitude, latitude, elevation and cumulative distance in meters. Empty when the bulk endpoint was called with 'geometry=false'."
      ),
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
  .describe('Detailed route information')

/**
 * Soft delete a route. Requires route creator or team admin permissions.
 * @summary Delete route
 */
export const DeleteRouteParams = zod.object({
  routeSlug: zod.string().describe('Route slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const DeleteRouteResponse = zod.void()

/**
 * Change route URL slug. Requires organizer permissions.
 * @summary Change route slug
 */
export const ChangeRouteSlugParams = zod.object({
  routeSlug: zod.string().describe('Current route URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const changeRouteSlugBodySlugMax = 200

export const changeRouteSlugBodySlugRegExp = new RegExp('^[a-z0-9]+(-[a-z0-9]+)*$')

export const ChangeRouteSlugBody = zod
  .object({
    slug: zod
      .string()
      .max(changeRouteSlugBodySlugMax)
      .regex(changeRouteSlugBodySlugRegExp)
      .describe('New slug (lowercase letters, numbers, and hyphens only)'),
  })
  .describe('Slug change request')

export const changeRouteSlugResponseMediaMarkdownMax = 100000

export const ChangeRouteSlugResponse = zod
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
        markdown: zod.string().max(changeRouteSlugResponseMediaMarkdownMax).describe('Markdown'),
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
    distance: zod.number().describe('Distance in meters'),
    elevationGain: zod.number().describe('Total elevation gain in meters'),
    elevationLoss: zod.number().describe('Total elevation loss in meters'),
    surfaceType: zod.enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED']).describe('Surface type'),
    visibility: zod
      .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
      .describe('Whether the route is public'),
    start: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe('Location coordinates [longitude, latitude]'),
    end: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe('Location coordinates [longitude, latitude]'),
    createdBy: zod
      .object({
        id: zod.string().describe('User ID (TSID)'),
        displayName: zod.string().describe('User display name'),
        avatarUrl: zod.string().optional().describe('User avatar URL'),
      })
      .describe('Creator user'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    updatedAt: zod.iso.datetime({ offset: true }).describe('Last update timestamp'),
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
          })
          .describe('GPX track with track points')
      )
      .describe(
        "Tracks, with the stored geometry untouched — every coordinate carries longitude, latitude, elevation and cumulative distance in meters. Empty when the bulk endpoint was called with 'geometry=false'."
      ),
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
  .describe('Detailed route information')

/**
 * Restore a soft-deleted route. Requires route creator or team admin permissions.
 * @summary Restore route
 */
export const UndeleteRouteParams = zod.object({
  routeSlug: zod.string().describe('Route slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const undeleteRouteResponseMediaMarkdownMax = 100000

export const UndeleteRouteResponse = zod
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
        markdown: zod.string().max(undeleteRouteResponseMediaMarkdownMax).describe('Markdown'),
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
    distance: zod.number().describe('Distance in meters'),
    elevationGain: zod.number().describe('Total elevation gain in meters'),
    elevationLoss: zod.number().describe('Total elevation loss in meters'),
    surfaceType: zod.enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED']).describe('Surface type'),
    visibility: zod
      .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
      .describe('Whether the route is public'),
    start: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe('Location coordinates [longitude, latitude]'),
    end: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe('Location coordinates [longitude, latitude]'),
    createdBy: zod
      .object({
        id: zod.string().describe('User ID (TSID)'),
        displayName: zod.string().describe('User display name'),
        avatarUrl: zod.string().optional().describe('User avatar URL'),
      })
      .describe('Creator user'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    updatedAt: zod.iso.datetime({ offset: true }).describe('Last update timestamp'),
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
          })
          .describe('GPX track with track points')
      )
      .describe(
        "Tracks, with the stored geometry untouched — every coordinate carries longitude, latitude, elevation and cumulative distance in meters. Empty when the bulk endpoint was called with 'geometry=false'."
      ),
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
  .describe('Detailed route information')

/**
 * Rides and trips that reference this route, directly or via a group/stage. Results are visibility filtered for the caller.
 * @summary List route usages
 */
export const GetRouteUsagesParams = zod.object({
  routeSlug: zod.string().describe('Route slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const GetRouteUsagesResponse = zod
  .object({
    usages: zod
      .array(
        zod
          .object({
            type: zod.enum(['RIDE', 'POST', 'TRIP']).describe('Publication type (RIDE or TRIP)'),
            slug: zod.string().describe('Publication URL slug'),
            name: zod.string().describe('Publication name'),
            dateTime: zod.iso.datetime({ offset: true }).describe('Publication date/time'),
            timezone: zod
              .string()
              .describe(
                'IANA zone of the publication, as RideDto.timezone / TripDto.timezone: dateTime and endDate are rendezvous in it.'
              ),
            endDate: zod.iso
              .datetime({ offset: true })
              .optional()
              .describe(
                'For a trip, the date of its last stage — the same value as TripDto.endDate. Null for a ride, and for a trip with no stage, which lasts a day.'
              ),
            teamSlug: zod.string().describe('Slug of the team owning the publication'),
            referencedDirectly: zod
              .boolean()
              .describe(
                'Whether the publication references the route directly (not only via a child)'
              ),
            viaChildNames: zod
              .array(zod.string())
              .describe('Names of the ride groups or trip stages that reference the route, if any'),
          })
          .describe('A ride or trip that uses a route')
      )
      .describe('Usages of the route, most recent first'),
  })
  .describe('Rides and trips that use a route')
