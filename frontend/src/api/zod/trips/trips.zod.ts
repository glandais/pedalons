import * as zod from 'zod'

/**
 * Create a new trip with optional stages
 * @summary Create trip
 */
export const CreateTripParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const createTripBodyNameMax = 200

export const createTripBodyNameRegExp = new RegExp('\\S')
export const createTripBodyMediaMarkdownMax = 100000

export const createTripBodyStagesItemNameMax = 200

export const createTripBodyStagesItemNameRegExp = new RegExp('\\S')
export const createTripBodyStagesItemAverageSpeedExclusiveMin = 0

export const createTripBodyStagesItemMediaMarkdownMax = 100000

export const CreateTripBody = zod
  .object({
    name: zod
      .string()
      .min(1)
      .max(createTripBodyNameMax)
      .regex(createTripBodyNameRegExp)
      .describe('Trip name'),
    media: zod
      .object({
        markdown: zod.string().max(createTripBodyMediaMarkdownMax).describe('Markdown'),
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
      .describe('Trip media'),
    dateTime: zod
      .string()
      .describe(
        "Trip start date/time: a wall time without offset, read in the trip's zone (first stage, else route, else team)."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Trip status'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    routeSlug: zod.string().optional().describe('Overall route slug for the trip'),
    publishAt: zod
      .string()
      .optional()
      .describe(
        "Publication time (for scheduled publishing), a wall time in the trip's zone like dateTime."
      ),
    stages: zod
      .array(
        zod
          .object({
            id: zod.string().optional().describe('Stage ID (for updates)'),
            name: zod
              .string()
              .min(1)
              .max(createTripBodyStagesItemNameMax)
              .regex(createTripBodyStagesItemNameRegExp)
              .describe('Stage name'),
            dateTime: zod
              .string()
              .describe(
                "Stage date/time: a wall time without offset, read in the stage's zone (start place, else route, else the previous stage's, else the trip route's, else the team's)."
              ),
            averageSpeed: zod
              .number()
              .gt(createTripBodyStagesItemAverageSpeedExclusiveMin)
              .optional()
              .describe('Average speed in km/h'),
            routeSlug: zod.string().optional().describe('Route slug for this stage'),
            startPlaceId: zod.string().optional().describe('Start place ID (TSID)'),
            endPlaceId: zod.string().optional().describe('End place ID (TSID)'),
            media: zod
              .object({
                markdown: zod
                  .string()
                  .max(createTripBodyStagesItemMediaMarkdownMax)
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
              .describe('Stage media'),
          })
          .describe('Trip stage creation request')
      )
      .describe('Trip stages to create'),
    tagIds: zod
      .array(zod.string())
      .optional()
      .describe(
        "IDs (TSID) of the team's TRIP tags the trip carries, replacing the whole set — at most 10, each a tag of this team and of kind TRIP, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update."
      ),
  })
  .describe('Trip request')

export const createTripResponseMediaMarkdownMax = 100000

export const createTripResponseStagesItemRouteMediaMarkdownMax = 100000

export const createTripResponseStagesItemMediaMarkdownMax = 100000

export const CreateTripResponse = zod
  .object({
    type: zod.enum(['TRIP']),
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
    id: zod.string().describe('Publication ID (TSID)'),
    slug: zod.string().describe('Publication URL slug'),
    name: zod.string().describe('Publication name'),
    media: zod
      .object({
        markdown: zod.string().max(createTripResponseMediaMarkdownMax).describe('Markdown'),
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
      .describe('Publication media'),
    excerpt: zod
      .string()
      .optional()
      .describe(
        "Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter."
      ),
    dateTime: zod.iso.datetime({ offset: true }).describe('Trip start date/time'),
    timezone: zod
      .string()
      .describe(
        "IANA zone the trip's times were entered in and read in: its first stage's, else its route's, else the team's. dateTime, endDate, endDateTime and publishAt are rendezvous in this zone."
      ),
    endDate: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        'Date of the last stage — the day the trip ends. Null when the trip has no stage, in which case it lasts a day and dateTime is both ends.'
      ),
    endDateTime: zod.iso
      .datetime({ offset: true })
      .describe(
        "When the trip is over, computed by the server: the end of its latest stage — its departure plus its route's length at its average speed, or plus 3 hours when the stage has no speed or no route — or dateTime plus 3 hours for a trip with no stage. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Publication status'),
    finished: zod
      .boolean()
      .describe(
        'Whether the trip is over, computed by the server when the response is built: its last stage (endDate, or dateTime when there is none) has started. Independent of status — a past cancelled trip is both CANCELLED and finished.'
      ),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    publishAt: zod.iso.datetime({ offset: true }).optional().describe('Publication timestamp'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Creation timestamp'),
    routeSlug: zod.string().optional().describe('Route slug'),
    participantCount: zod.int().describe('Number of participants'),
    stageCount: zod.int().describe('Number of stages'),
    totalDistance: zod
      .number()
      .optional()
      .describe(
        'Distance in metres over every stage that has a route. Null when no stage has one — an unrouted trip has no distance, which is not the same as a distance of zero.'
      ),
    totalElevationGain: zod
      .number()
      .optional()
      .describe(
        'Elevation gain in metres over every stage that has a route. Null when no stage has one.'
      ),
    stages: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Stage ID (TSID)'),
            slug: zod.string().describe('Stage slug'),
            name: zod.string().describe('Stage name'),
            dateTime: zod.iso.datetime({ offset: true }).describe('Stage date/time'),
            timezone: zod
              .string()
              .describe(
                "IANA zone the stage's time was entered in and is read in: its start place's, else its route's, else the previous stage's, else the trip route's, else the team's. A stage may differ from its trip."
              ),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            route: zod
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
                      .max(createTripResponseStagesItemRouteMediaMarkdownMax)
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
              .optional()
              .describe('Route'),
            startPlace: zod
              .object({
                id: zod.string().describe('Place ID (TSID)'),
                name: zod.string(),
                address: zod.string().optional(),
                link: zod.string().optional(),
                startPlace: zod.boolean(),
                endPlace: zod.boolean(),
                geometry: zod
                  .object({
                    type: zod.enum(['Point']),
                    coordinates: zod
                      .array(zod.number())
                      .describe('Coordinates [longitude, latitude]'),
                  })
                  .optional()
                  .describe('Location coordinates [longitude, latitude]'),
              })
              .optional()
              .describe('Start place'),
            endPlace: zod
              .object({
                id: zod.string().describe('Place ID (TSID)'),
                name: zod.string(),
                address: zod.string().optional(),
                link: zod.string().optional(),
                startPlace: zod.boolean(),
                endPlace: zod.boolean(),
                geometry: zod
                  .object({
                    type: zod.enum(['Point']),
                    coordinates: zod
                      .array(zod.number())
                      .describe('Coordinates [longitude, latitude]'),
                  })
                  .optional()
                  .describe('Location coordinates [longitude, latitude]'),
              })
              .optional()
              .describe('End place'),
            media: zod
              .object({
                markdown: zod
                  .string()
                  .max(createTripResponseStagesItemMediaMarkdownMax)
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
              .describe('Stage media'),
            sortOrder: zod.int().describe('Sort order'),
            stageIndex: zod
              .int()
              .describe(
                "Position of this stage among the trip's live stages, 1-based — the 'Day 2' of a stage header. Unlike sortOrder, which is a persisted rank that may have gaps, this is a rank a client can print."
              ),
            stageCount: zod
              .int()
              .describe("How many live stages the trip has — the '/ 5' of 'Day 2 / 5'."),
            commentCount: zod
              .int()
              .optional()
              .describe(
                "Number of comments on the stage's own thread. Absent when the caller cannot read comments (not a member of the team), like TripDto.commentCount."
              ),
          })
          .describe('Trip stage information')
      )
      .describe('Trip stages'),
    participants: zod
      .array(
        zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .describe('Public user information (limited fields)')
      )
      .describe(
        'The first participants of the trip (at most 8), earliest registrations first — enough to draw avatars; empty on a list row. participantCount is the total; the whole list is paginated and searched by GET …/trips/{tripSlug}/participants. Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.'
      ),
    thumbnailLightUrl: zod
      .string()
      .optional()
      .describe(
        'Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.'
      ),
    thumbnailDarkUrl: zod
      .string()
      .optional()
      .describe(
        'Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.'
      ),
    thumbnailUrl: zod
      .string()
      .optional()
      .describe(
        'The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.'
      ),
    deleted: zod.boolean().describe('Whether the trip is soft-deleted'),
    registered: zod
      .boolean()
      .describe('Whether the current user is registered for this trip. False if anonymous.'),
    commentCount: zod
      .int()
      .optional()
      .describe(
        'Number of comments, replies included. Absent when the caller may not read the comments of this trip — comments are members-only, so an outsider is told nothing, not even zero.'
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
        "The team's TRIP tags the trip carries, sorted by label. Empty when it carries none."
      ),
    weather: zod
      .object({
        status: zod
          .enum(['OK', 'STALE', 'NOT_YET_AVAILABLE', 'UNAVAILABLE', 'NO_LOCATION', 'OUT_OF_RANGE'])
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
        temperature: zod.number().optional().describe('Air temperature at the departure hour, °C'),
        temperatureMin: zod.number().optional().describe('Lowest temperature over the window, °C'),
        temperatureMax: zod.number().optional().describe('Highest temperature over the window, °C'),
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
        "The weather line of a list card: that of the trip's next leg — its first stage still to leave, else the trip itself when it has no stage — at the start of its route, over the window from its departure to its estimated arrival. Absent when there is nothing to show — trip finished, draft or cancelled, next stage without a route, forecast not in cache yet — and on the trip's own detail, which reads getTripWeather; present only with status OK, STALE or NOT_YET_AVAILABLE."
      ),
  })
  .describe('Trip data')

/**
 * Update trip information. Requires organizer permissions.
 * @summary Update trip
 */
export const UpdateTripParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  tripSlug: zod.string().describe('Trip URL slug'),
})

export const updateTripBodyNameMax = 200

export const updateTripBodyNameRegExp = new RegExp('\\S')
export const updateTripBodyMediaMarkdownMax = 100000

export const updateTripBodyStagesItemNameMax = 200

export const updateTripBodyStagesItemNameRegExp = new RegExp('\\S')
export const updateTripBodyStagesItemAverageSpeedExclusiveMin = 0

export const updateTripBodyStagesItemMediaMarkdownMax = 100000

export const UpdateTripBody = zod
  .object({
    name: zod
      .string()
      .min(1)
      .max(updateTripBodyNameMax)
      .regex(updateTripBodyNameRegExp)
      .describe('Trip name'),
    media: zod
      .object({
        markdown: zod.string().max(updateTripBodyMediaMarkdownMax).describe('Markdown'),
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
      .describe('Trip media'),
    dateTime: zod
      .string()
      .describe(
        "Trip start date/time: a wall time without offset, read in the trip's zone (first stage, else route, else team)."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Trip status'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    routeSlug: zod.string().optional().describe('Overall route slug for the trip'),
    publishAt: zod
      .string()
      .optional()
      .describe(
        "Publication time (for scheduled publishing), a wall time in the trip's zone like dateTime."
      ),
    stages: zod
      .array(
        zod
          .object({
            id: zod.string().optional().describe('Stage ID (for updates)'),
            name: zod
              .string()
              .min(1)
              .max(updateTripBodyStagesItemNameMax)
              .regex(updateTripBodyStagesItemNameRegExp)
              .describe('Stage name'),
            dateTime: zod
              .string()
              .describe(
                "Stage date/time: a wall time without offset, read in the stage's zone (start place, else route, else the previous stage's, else the trip route's, else the team's)."
              ),
            averageSpeed: zod
              .number()
              .gt(updateTripBodyStagesItemAverageSpeedExclusiveMin)
              .optional()
              .describe('Average speed in km/h'),
            routeSlug: zod.string().optional().describe('Route slug for this stage'),
            startPlaceId: zod.string().optional().describe('Start place ID (TSID)'),
            endPlaceId: zod.string().optional().describe('End place ID (TSID)'),
            media: zod
              .object({
                markdown: zod
                  .string()
                  .max(updateTripBodyStagesItemMediaMarkdownMax)
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
              .describe('Stage media'),
          })
          .describe('Trip stage creation request')
      )
      .describe('Trip stages to create'),
    tagIds: zod
      .array(zod.string())
      .optional()
      .describe(
        "IDs (TSID) of the team's TRIP tags the trip carries, replacing the whole set — at most 10, each a tag of this team and of kind TRIP, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update."
      ),
  })
  .describe('Trip request')

export const updateTripResponseMediaMarkdownMax = 100000

export const updateTripResponseStagesItemRouteMediaMarkdownMax = 100000

export const updateTripResponseStagesItemMediaMarkdownMax = 100000

export const UpdateTripResponse = zod
  .object({
    type: zod.enum(['TRIP']),
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
    id: zod.string().describe('Publication ID (TSID)'),
    slug: zod.string().describe('Publication URL slug'),
    name: zod.string().describe('Publication name'),
    media: zod
      .object({
        markdown: zod.string().max(updateTripResponseMediaMarkdownMax).describe('Markdown'),
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
      .describe('Publication media'),
    excerpt: zod
      .string()
      .optional()
      .describe(
        "Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter."
      ),
    dateTime: zod.iso.datetime({ offset: true }).describe('Trip start date/time'),
    timezone: zod
      .string()
      .describe(
        "IANA zone the trip's times were entered in and read in: its first stage's, else its route's, else the team's. dateTime, endDate, endDateTime and publishAt are rendezvous in this zone."
      ),
    endDate: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        'Date of the last stage — the day the trip ends. Null when the trip has no stage, in which case it lasts a day and dateTime is both ends.'
      ),
    endDateTime: zod.iso
      .datetime({ offset: true })
      .describe(
        "When the trip is over, computed by the server: the end of its latest stage — its departure plus its route's length at its average speed, or plus 3 hours when the stage has no speed or no route — or dateTime plus 3 hours for a trip with no stage. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Publication status'),
    finished: zod
      .boolean()
      .describe(
        'Whether the trip is over, computed by the server when the response is built: its last stage (endDate, or dateTime when there is none) has started. Independent of status — a past cancelled trip is both CANCELLED and finished.'
      ),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    publishAt: zod.iso.datetime({ offset: true }).optional().describe('Publication timestamp'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Creation timestamp'),
    routeSlug: zod.string().optional().describe('Route slug'),
    participantCount: zod.int().describe('Number of participants'),
    stageCount: zod.int().describe('Number of stages'),
    totalDistance: zod
      .number()
      .optional()
      .describe(
        'Distance in metres over every stage that has a route. Null when no stage has one — an unrouted trip has no distance, which is not the same as a distance of zero.'
      ),
    totalElevationGain: zod
      .number()
      .optional()
      .describe(
        'Elevation gain in metres over every stage that has a route. Null when no stage has one.'
      ),
    stages: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Stage ID (TSID)'),
            slug: zod.string().describe('Stage slug'),
            name: zod.string().describe('Stage name'),
            dateTime: zod.iso.datetime({ offset: true }).describe('Stage date/time'),
            timezone: zod
              .string()
              .describe(
                "IANA zone the stage's time was entered in and is read in: its start place's, else its route's, else the previous stage's, else the trip route's, else the team's. A stage may differ from its trip."
              ),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            route: zod
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
                      .max(updateTripResponseStagesItemRouteMediaMarkdownMax)
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
              .optional()
              .describe('Route'),
            startPlace: zod
              .object({
                id: zod.string().describe('Place ID (TSID)'),
                name: zod.string(),
                address: zod.string().optional(),
                link: zod.string().optional(),
                startPlace: zod.boolean(),
                endPlace: zod.boolean(),
                geometry: zod
                  .object({
                    type: zod.enum(['Point']),
                    coordinates: zod
                      .array(zod.number())
                      .describe('Coordinates [longitude, latitude]'),
                  })
                  .optional()
                  .describe('Location coordinates [longitude, latitude]'),
              })
              .optional()
              .describe('Start place'),
            endPlace: zod
              .object({
                id: zod.string().describe('Place ID (TSID)'),
                name: zod.string(),
                address: zod.string().optional(),
                link: zod.string().optional(),
                startPlace: zod.boolean(),
                endPlace: zod.boolean(),
                geometry: zod
                  .object({
                    type: zod.enum(['Point']),
                    coordinates: zod
                      .array(zod.number())
                      .describe('Coordinates [longitude, latitude]'),
                  })
                  .optional()
                  .describe('Location coordinates [longitude, latitude]'),
              })
              .optional()
              .describe('End place'),
            media: zod
              .object({
                markdown: zod
                  .string()
                  .max(updateTripResponseStagesItemMediaMarkdownMax)
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
              .describe('Stage media'),
            sortOrder: zod.int().describe('Sort order'),
            stageIndex: zod
              .int()
              .describe(
                "Position of this stage among the trip's live stages, 1-based — the 'Day 2' of a stage header. Unlike sortOrder, which is a persisted rank that may have gaps, this is a rank a client can print."
              ),
            stageCount: zod
              .int()
              .describe("How many live stages the trip has — the '/ 5' of 'Day 2 / 5'."),
            commentCount: zod
              .int()
              .optional()
              .describe(
                "Number of comments on the stage's own thread. Absent when the caller cannot read comments (not a member of the team), like TripDto.commentCount."
              ),
          })
          .describe('Trip stage information')
      )
      .describe('Trip stages'),
    participants: zod
      .array(
        zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .describe('Public user information (limited fields)')
      )
      .describe(
        'The first participants of the trip (at most 8), earliest registrations first — enough to draw avatars; empty on a list row. participantCount is the total; the whole list is paginated and searched by GET …/trips/{tripSlug}/participants. Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.'
      ),
    thumbnailLightUrl: zod
      .string()
      .optional()
      .describe(
        'Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.'
      ),
    thumbnailDarkUrl: zod
      .string()
      .optional()
      .describe(
        'Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.'
      ),
    thumbnailUrl: zod
      .string()
      .optional()
      .describe(
        'The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.'
      ),
    deleted: zod.boolean().describe('Whether the trip is soft-deleted'),
    registered: zod
      .boolean()
      .describe('Whether the current user is registered for this trip. False if anonymous.'),
    commentCount: zod
      .int()
      .optional()
      .describe(
        'Number of comments, replies included. Absent when the caller may not read the comments of this trip — comments are members-only, so an outsider is told nothing, not even zero.'
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
        "The team's TRIP tags the trip carries, sorted by label. Empty when it carries none."
      ),
    weather: zod
      .object({
        status: zod
          .enum(['OK', 'STALE', 'NOT_YET_AVAILABLE', 'UNAVAILABLE', 'NO_LOCATION', 'OUT_OF_RANGE'])
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
        temperature: zod.number().optional().describe('Air temperature at the departure hour, °C'),
        temperatureMin: zod.number().optional().describe('Lowest temperature over the window, °C'),
        temperatureMax: zod.number().optional().describe('Highest temperature over the window, °C'),
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
        "The weather line of a list card: that of the trip's next leg — its first stage still to leave, else the trip itself when it has no stage — at the start of its route, over the window from its departure to its estimated arrival. Absent when there is nothing to show — trip finished, draft or cancelled, next stage without a route, forecast not in cache yet — and on the trip's own detail, which reads getTripWeather; present only with status OK, STALE or NOT_YET_AVAILABLE."
      ),
  })
  .describe('Trip data')

/**
 * Get detailed trip information including stages and participants
 * @summary Get trip details
 */
export const GetTripParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  tripSlug: zod.string().describe('Trip URL slug'),
})

export const getTripResponseMediaMarkdownMax = 100000

export const getTripResponseStagesItemRouteMediaMarkdownMax = 100000

export const getTripResponseStagesItemMediaMarkdownMax = 100000

export const GetTripResponse = zod
  .object({
    type: zod.enum(['TRIP']),
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
    id: zod.string().describe('Publication ID (TSID)'),
    slug: zod.string().describe('Publication URL slug'),
    name: zod.string().describe('Publication name'),
    media: zod
      .object({
        markdown: zod.string().max(getTripResponseMediaMarkdownMax).describe('Markdown'),
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
      .describe('Publication media'),
    excerpt: zod
      .string()
      .optional()
      .describe(
        "Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter."
      ),
    dateTime: zod.iso.datetime({ offset: true }).describe('Trip start date/time'),
    timezone: zod
      .string()
      .describe(
        "IANA zone the trip's times were entered in and read in: its first stage's, else its route's, else the team's. dateTime, endDate, endDateTime and publishAt are rendezvous in this zone."
      ),
    endDate: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        'Date of the last stage — the day the trip ends. Null when the trip has no stage, in which case it lasts a day and dateTime is both ends.'
      ),
    endDateTime: zod.iso
      .datetime({ offset: true })
      .describe(
        "When the trip is over, computed by the server: the end of its latest stage — its departure plus its route's length at its average speed, or plus 3 hours when the stage has no speed or no route — or dateTime plus 3 hours for a trip with no stage. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Publication status'),
    finished: zod
      .boolean()
      .describe(
        'Whether the trip is over, computed by the server when the response is built: its last stage (endDate, or dateTime when there is none) has started. Independent of status — a past cancelled trip is both CANCELLED and finished.'
      ),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    publishAt: zod.iso.datetime({ offset: true }).optional().describe('Publication timestamp'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Creation timestamp'),
    routeSlug: zod.string().optional().describe('Route slug'),
    participantCount: zod.int().describe('Number of participants'),
    stageCount: zod.int().describe('Number of stages'),
    totalDistance: zod
      .number()
      .optional()
      .describe(
        'Distance in metres over every stage that has a route. Null when no stage has one — an unrouted trip has no distance, which is not the same as a distance of zero.'
      ),
    totalElevationGain: zod
      .number()
      .optional()
      .describe(
        'Elevation gain in metres over every stage that has a route. Null when no stage has one.'
      ),
    stages: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Stage ID (TSID)'),
            slug: zod.string().describe('Stage slug'),
            name: zod.string().describe('Stage name'),
            dateTime: zod.iso.datetime({ offset: true }).describe('Stage date/time'),
            timezone: zod
              .string()
              .describe(
                "IANA zone the stage's time was entered in and is read in: its start place's, else its route's, else the previous stage's, else the trip route's, else the team's. A stage may differ from its trip."
              ),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            route: zod
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
                      .max(getTripResponseStagesItemRouteMediaMarkdownMax)
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
              .optional()
              .describe('Route'),
            startPlace: zod
              .object({
                id: zod.string().describe('Place ID (TSID)'),
                name: zod.string(),
                address: zod.string().optional(),
                link: zod.string().optional(),
                startPlace: zod.boolean(),
                endPlace: zod.boolean(),
                geometry: zod
                  .object({
                    type: zod.enum(['Point']),
                    coordinates: zod
                      .array(zod.number())
                      .describe('Coordinates [longitude, latitude]'),
                  })
                  .optional()
                  .describe('Location coordinates [longitude, latitude]'),
              })
              .optional()
              .describe('Start place'),
            endPlace: zod
              .object({
                id: zod.string().describe('Place ID (TSID)'),
                name: zod.string(),
                address: zod.string().optional(),
                link: zod.string().optional(),
                startPlace: zod.boolean(),
                endPlace: zod.boolean(),
                geometry: zod
                  .object({
                    type: zod.enum(['Point']),
                    coordinates: zod
                      .array(zod.number())
                      .describe('Coordinates [longitude, latitude]'),
                  })
                  .optional()
                  .describe('Location coordinates [longitude, latitude]'),
              })
              .optional()
              .describe('End place'),
            media: zod
              .object({
                markdown: zod
                  .string()
                  .max(getTripResponseStagesItemMediaMarkdownMax)
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
              .describe('Stage media'),
            sortOrder: zod.int().describe('Sort order'),
            stageIndex: zod
              .int()
              .describe(
                "Position of this stage among the trip's live stages, 1-based — the 'Day 2' of a stage header. Unlike sortOrder, which is a persisted rank that may have gaps, this is a rank a client can print."
              ),
            stageCount: zod
              .int()
              .describe("How many live stages the trip has — the '/ 5' of 'Day 2 / 5'."),
            commentCount: zod
              .int()
              .optional()
              .describe(
                "Number of comments on the stage's own thread. Absent when the caller cannot read comments (not a member of the team), like TripDto.commentCount."
              ),
          })
          .describe('Trip stage information')
      )
      .describe('Trip stages'),
    participants: zod
      .array(
        zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .describe('Public user information (limited fields)')
      )
      .describe(
        'The first participants of the trip (at most 8), earliest registrations first — enough to draw avatars; empty on a list row. participantCount is the total; the whole list is paginated and searched by GET …/trips/{tripSlug}/participants. Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.'
      ),
    thumbnailLightUrl: zod
      .string()
      .optional()
      .describe(
        'Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.'
      ),
    thumbnailDarkUrl: zod
      .string()
      .optional()
      .describe(
        'Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.'
      ),
    thumbnailUrl: zod
      .string()
      .optional()
      .describe(
        'The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.'
      ),
    deleted: zod.boolean().describe('Whether the trip is soft-deleted'),
    registered: zod
      .boolean()
      .describe('Whether the current user is registered for this trip. False if anonymous.'),
    commentCount: zod
      .int()
      .optional()
      .describe(
        'Number of comments, replies included. Absent when the caller may not read the comments of this trip — comments are members-only, so an outsider is told nothing, not even zero.'
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
        "The team's TRIP tags the trip carries, sorted by label. Empty when it carries none."
      ),
    weather: zod
      .object({
        status: zod
          .enum(['OK', 'STALE', 'NOT_YET_AVAILABLE', 'UNAVAILABLE', 'NO_LOCATION', 'OUT_OF_RANGE'])
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
        temperature: zod.number().optional().describe('Air temperature at the departure hour, °C'),
        temperatureMin: zod.number().optional().describe('Lowest temperature over the window, °C'),
        temperatureMax: zod.number().optional().describe('Highest temperature over the window, °C'),
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
        "The weather line of a list card: that of the trip's next leg — its first stage still to leave, else the trip itself when it has no stage — at the start of its route, over the window from its departure to its estimated arrival. Absent when there is nothing to show — trip finished, draft or cancelled, next stage without a route, forecast not in cache yet — and on the trip's own detail, which reads getTripWeather; present only with status OK, STALE or NOT_YET_AVAILABLE."
      ),
  })
  .describe('Trip data')

/**
 * Soft delete a trip. Requires organizer permissions.
 * @summary Delete trip
 */
export const DeleteTripParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  tripSlug: zod.string().describe('Trip URL slug'),
})

export const DeleteTripResponse = zod.void()

/**
 * One all-day VEVENT per stage, to add the trip on its own to a calendar. Readable by whoever may read the trip; no calendar token.
 * @summary Download trip as a calendar file
 */
export const DownloadTripIcsParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  tripSlug: zod.string().describe('Trip URL slug'),
})

export const DownloadTripIcsResponse = zod.unknown()

/**
 * Join a trip as a participant
 * @summary Join trip
 */
export const JoinTripParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  tripSlug: zod.string().describe('Trip URL slug'),
})

export const JoinTripResponse = zod
  .object({
    id: zod.string().describe('Participation ID (TSID)'),
    userId: zod.string().describe('User ID (TSID)'),
    registeredAt: zod.iso.datetime({ offset: true }).optional().describe('Registration timestamp'),
  })
  .describe('Trip participation information')

/**
 * Leave a trip as a participant
 * @summary Leave trip
 */
export const LeaveTripParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  tripSlug: zod.string().describe('Trip URL slug'),
})

export const LeaveTripResponse = zod.void()

/**
 * One page of the people registered to the trip, earliest registrations first, searchable by display name. The trip detail only embeds the first few; this is the whole list, with its total. Members of the team only (and platform administrators): member names are never sent to anyone else.
 * @summary List trip participants
 */
export const GetTripParticipantsParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  tripSlug: zod.string().describe('Trip URL slug'),
})

export const getTripParticipantsQueryPageDefault = 0
export const getTripParticipantsQuerySizeDefault = 50

export const GetTripParticipantsQueryParams = zod.object({
  page: zod.int().default(getTripParticipantsQueryPageDefault).describe('Page number (0-based)'),
  search: zod.string().optional().describe('Search by display name'),
  size: zod.int().default(getTripParticipantsQuerySizeDefault).describe('Page size'),
})

export const GetTripParticipantsResponse = zod
  .object({
    participants: zod
      .array(
        zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .describe('Public user information (limited fields)')
      )
      .describe('Participants of this page, in registration order (earliest first)'),
    total: zod
      .int()
      .describe(
        'Number of participants matching the search, over every page — the M of « N of M »'
      ),
    page: zod.int().describe('Current page number (0-based)'),
    size: zod.int().describe('Page size actually applied'),
  })
  .describe('Paginated list of the people registered to a ride, a ride group or a trip')

/**
 * Change trip URL slug. Requires organizer permissions.
 * @summary Change trip slug
 */
export const ChangeTripSlugParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  tripSlug: zod.string().describe('Current trip URL slug'),
})

export const changeTripSlugBodySlugMax = 200

export const changeTripSlugBodySlugRegExp = new RegExp('^[a-z0-9]+(-[a-z0-9]+)*$')

export const ChangeTripSlugBody = zod
  .object({
    slug: zod
      .string()
      .max(changeTripSlugBodySlugMax)
      .regex(changeTripSlugBodySlugRegExp)
      .describe('New slug (lowercase letters, numbers, and hyphens only)'),
  })
  .describe('Slug change request')

export const changeTripSlugResponseMediaMarkdownMax = 100000

export const changeTripSlugResponseStagesItemRouteMediaMarkdownMax = 100000

export const changeTripSlugResponseStagesItemMediaMarkdownMax = 100000

export const ChangeTripSlugResponse = zod
  .object({
    type: zod.enum(['TRIP']),
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
    id: zod.string().describe('Publication ID (TSID)'),
    slug: zod.string().describe('Publication URL slug'),
    name: zod.string().describe('Publication name'),
    media: zod
      .object({
        markdown: zod.string().max(changeTripSlugResponseMediaMarkdownMax).describe('Markdown'),
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
      .describe('Publication media'),
    excerpt: zod
      .string()
      .optional()
      .describe(
        "Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter."
      ),
    dateTime: zod.iso.datetime({ offset: true }).describe('Trip start date/time'),
    timezone: zod
      .string()
      .describe(
        "IANA zone the trip's times were entered in and read in: its first stage's, else its route's, else the team's. dateTime, endDate, endDateTime and publishAt are rendezvous in this zone."
      ),
    endDate: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        'Date of the last stage — the day the trip ends. Null when the trip has no stage, in which case it lasts a day and dateTime is both ends.'
      ),
    endDateTime: zod.iso
      .datetime({ offset: true })
      .describe(
        "When the trip is over, computed by the server: the end of its latest stage — its departure plus its route's length at its average speed, or plus 3 hours when the stage has no speed or no route — or dateTime plus 3 hours for a trip with no stage. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Publication status'),
    finished: zod
      .boolean()
      .describe(
        'Whether the trip is over, computed by the server when the response is built: its last stage (endDate, or dateTime when there is none) has started. Independent of status — a past cancelled trip is both CANCELLED and finished.'
      ),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    publishAt: zod.iso.datetime({ offset: true }).optional().describe('Publication timestamp'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Creation timestamp'),
    routeSlug: zod.string().optional().describe('Route slug'),
    participantCount: zod.int().describe('Number of participants'),
    stageCount: zod.int().describe('Number of stages'),
    totalDistance: zod
      .number()
      .optional()
      .describe(
        'Distance in metres over every stage that has a route. Null when no stage has one — an unrouted trip has no distance, which is not the same as a distance of zero.'
      ),
    totalElevationGain: zod
      .number()
      .optional()
      .describe(
        'Elevation gain in metres over every stage that has a route. Null when no stage has one.'
      ),
    stages: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Stage ID (TSID)'),
            slug: zod.string().describe('Stage slug'),
            name: zod.string().describe('Stage name'),
            dateTime: zod.iso.datetime({ offset: true }).describe('Stage date/time'),
            timezone: zod
              .string()
              .describe(
                "IANA zone the stage's time was entered in and is read in: its start place's, else its route's, else the previous stage's, else the trip route's, else the team's. A stage may differ from its trip."
              ),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            route: zod
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
                      .max(changeTripSlugResponseStagesItemRouteMediaMarkdownMax)
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
              .optional()
              .describe('Route'),
            startPlace: zod
              .object({
                id: zod.string().describe('Place ID (TSID)'),
                name: zod.string(),
                address: zod.string().optional(),
                link: zod.string().optional(),
                startPlace: zod.boolean(),
                endPlace: zod.boolean(),
                geometry: zod
                  .object({
                    type: zod.enum(['Point']),
                    coordinates: zod
                      .array(zod.number())
                      .describe('Coordinates [longitude, latitude]'),
                  })
                  .optional()
                  .describe('Location coordinates [longitude, latitude]'),
              })
              .optional()
              .describe('Start place'),
            endPlace: zod
              .object({
                id: zod.string().describe('Place ID (TSID)'),
                name: zod.string(),
                address: zod.string().optional(),
                link: zod.string().optional(),
                startPlace: zod.boolean(),
                endPlace: zod.boolean(),
                geometry: zod
                  .object({
                    type: zod.enum(['Point']),
                    coordinates: zod
                      .array(zod.number())
                      .describe('Coordinates [longitude, latitude]'),
                  })
                  .optional()
                  .describe('Location coordinates [longitude, latitude]'),
              })
              .optional()
              .describe('End place'),
            media: zod
              .object({
                markdown: zod
                  .string()
                  .max(changeTripSlugResponseStagesItemMediaMarkdownMax)
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
              .describe('Stage media'),
            sortOrder: zod.int().describe('Sort order'),
            stageIndex: zod
              .int()
              .describe(
                "Position of this stage among the trip's live stages, 1-based — the 'Day 2' of a stage header. Unlike sortOrder, which is a persisted rank that may have gaps, this is a rank a client can print."
              ),
            stageCount: zod
              .int()
              .describe("How many live stages the trip has — the '/ 5' of 'Day 2 / 5'."),
            commentCount: zod
              .int()
              .optional()
              .describe(
                "Number of comments on the stage's own thread. Absent when the caller cannot read comments (not a member of the team), like TripDto.commentCount."
              ),
          })
          .describe('Trip stage information')
      )
      .describe('Trip stages'),
    participants: zod
      .array(
        zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .describe('Public user information (limited fields)')
      )
      .describe(
        'The first participants of the trip (at most 8), earliest registrations first — enough to draw avatars; empty on a list row. participantCount is the total; the whole list is paginated and searched by GET …/trips/{tripSlug}/participants. Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.'
      ),
    thumbnailLightUrl: zod
      .string()
      .optional()
      .describe(
        'Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.'
      ),
    thumbnailDarkUrl: zod
      .string()
      .optional()
      .describe(
        'Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.'
      ),
    thumbnailUrl: zod
      .string()
      .optional()
      .describe(
        'The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.'
      ),
    deleted: zod.boolean().describe('Whether the trip is soft-deleted'),
    registered: zod
      .boolean()
      .describe('Whether the current user is registered for this trip. False if anonymous.'),
    commentCount: zod
      .int()
      .optional()
      .describe(
        'Number of comments, replies included. Absent when the caller may not read the comments of this trip — comments are members-only, so an outsider is told nothing, not even zero.'
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
        "The team's TRIP tags the trip carries, sorted by label. Empty when it carries none."
      ),
    weather: zod
      .object({
        status: zod
          .enum(['OK', 'STALE', 'NOT_YET_AVAILABLE', 'UNAVAILABLE', 'NO_LOCATION', 'OUT_OF_RANGE'])
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
        temperature: zod.number().optional().describe('Air temperature at the departure hour, °C'),
        temperatureMin: zod.number().optional().describe('Lowest temperature over the window, °C'),
        temperatureMax: zod.number().optional().describe('Highest temperature over the window, °C'),
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
        "The weather line of a list card: that of the trip's next leg — its first stage still to leave, else the trip itself when it has no stage — at the start of its route, over the window from its departure to its estimated arrival. Absent when there is nothing to show — trip finished, draft or cancelled, next stage without a route, forecast not in cache yet — and on the trip's own detail, which reads getTripWeather; present only with status OK, STALE or NOT_YET_AVAILABLE."
      ),
  })
  .describe('Trip data')

/**
 * Change the trip's status and nothing else — what a list row can do without the full trip. Same side effects as a status change through the update. Requires organizer permissions. The stages follow the trip.
 * @summary Change trip status
 */
export const ChangeTripStatusParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  tripSlug: zod.string().describe('Trip URL slug'),
})

export const ChangeTripStatusBody = zod
  .object({
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('New status'),
  })
  .describe('Status change request')

export const changeTripStatusResponseMediaMarkdownMax = 100000

export const changeTripStatusResponseStagesItemRouteMediaMarkdownMax = 100000

export const changeTripStatusResponseStagesItemMediaMarkdownMax = 100000

export const ChangeTripStatusResponse = zod
  .object({
    type: zod.enum(['TRIP']),
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
    id: zod.string().describe('Publication ID (TSID)'),
    slug: zod.string().describe('Publication URL slug'),
    name: zod.string().describe('Publication name'),
    media: zod
      .object({
        markdown: zod.string().max(changeTripStatusResponseMediaMarkdownMax).describe('Markdown'),
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
      .describe('Publication media'),
    excerpt: zod
      .string()
      .optional()
      .describe(
        "Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter."
      ),
    dateTime: zod.iso.datetime({ offset: true }).describe('Trip start date/time'),
    timezone: zod
      .string()
      .describe(
        "IANA zone the trip's times were entered in and read in: its first stage's, else its route's, else the team's. dateTime, endDate, endDateTime and publishAt are rendezvous in this zone."
      ),
    endDate: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        'Date of the last stage — the day the trip ends. Null when the trip has no stage, in which case it lasts a day and dateTime is both ends.'
      ),
    endDateTime: zod.iso
      .datetime({ offset: true })
      .describe(
        "When the trip is over, computed by the server: the end of its latest stage — its departure plus its route's length at its average speed, or plus 3 hours when the stage has no speed or no route — or dateTime plus 3 hours for a trip with no stage. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Publication status'),
    finished: zod
      .boolean()
      .describe(
        'Whether the trip is over, computed by the server when the response is built: its last stage (endDate, or dateTime when there is none) has started. Independent of status — a past cancelled trip is both CANCELLED and finished.'
      ),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    publishAt: zod.iso.datetime({ offset: true }).optional().describe('Publication timestamp'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Creation timestamp'),
    routeSlug: zod.string().optional().describe('Route slug'),
    participantCount: zod.int().describe('Number of participants'),
    stageCount: zod.int().describe('Number of stages'),
    totalDistance: zod
      .number()
      .optional()
      .describe(
        'Distance in metres over every stage that has a route. Null when no stage has one — an unrouted trip has no distance, which is not the same as a distance of zero.'
      ),
    totalElevationGain: zod
      .number()
      .optional()
      .describe(
        'Elevation gain in metres over every stage that has a route. Null when no stage has one.'
      ),
    stages: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Stage ID (TSID)'),
            slug: zod.string().describe('Stage slug'),
            name: zod.string().describe('Stage name'),
            dateTime: zod.iso.datetime({ offset: true }).describe('Stage date/time'),
            timezone: zod
              .string()
              .describe(
                "IANA zone the stage's time was entered in and is read in: its start place's, else its route's, else the previous stage's, else the trip route's, else the team's. A stage may differ from its trip."
              ),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            route: zod
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
                      .max(changeTripStatusResponseStagesItemRouteMediaMarkdownMax)
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
              .optional()
              .describe('Route'),
            startPlace: zod
              .object({
                id: zod.string().describe('Place ID (TSID)'),
                name: zod.string(),
                address: zod.string().optional(),
                link: zod.string().optional(),
                startPlace: zod.boolean(),
                endPlace: zod.boolean(),
                geometry: zod
                  .object({
                    type: zod.enum(['Point']),
                    coordinates: zod
                      .array(zod.number())
                      .describe('Coordinates [longitude, latitude]'),
                  })
                  .optional()
                  .describe('Location coordinates [longitude, latitude]'),
              })
              .optional()
              .describe('Start place'),
            endPlace: zod
              .object({
                id: zod.string().describe('Place ID (TSID)'),
                name: zod.string(),
                address: zod.string().optional(),
                link: zod.string().optional(),
                startPlace: zod.boolean(),
                endPlace: zod.boolean(),
                geometry: zod
                  .object({
                    type: zod.enum(['Point']),
                    coordinates: zod
                      .array(zod.number())
                      .describe('Coordinates [longitude, latitude]'),
                  })
                  .optional()
                  .describe('Location coordinates [longitude, latitude]'),
              })
              .optional()
              .describe('End place'),
            media: zod
              .object({
                markdown: zod
                  .string()
                  .max(changeTripStatusResponseStagesItemMediaMarkdownMax)
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
              .describe('Stage media'),
            sortOrder: zod.int().describe('Sort order'),
            stageIndex: zod
              .int()
              .describe(
                "Position of this stage among the trip's live stages, 1-based — the 'Day 2' of a stage header. Unlike sortOrder, which is a persisted rank that may have gaps, this is a rank a client can print."
              ),
            stageCount: zod
              .int()
              .describe("How many live stages the trip has — the '/ 5' of 'Day 2 / 5'."),
            commentCount: zod
              .int()
              .optional()
              .describe(
                "Number of comments on the stage's own thread. Absent when the caller cannot read comments (not a member of the team), like TripDto.commentCount."
              ),
          })
          .describe('Trip stage information')
      )
      .describe('Trip stages'),
    participants: zod
      .array(
        zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .describe('Public user information (limited fields)')
      )
      .describe(
        'The first participants of the trip (at most 8), earliest registrations first — enough to draw avatars; empty on a list row. participantCount is the total; the whole list is paginated and searched by GET …/trips/{tripSlug}/participants. Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.'
      ),
    thumbnailLightUrl: zod
      .string()
      .optional()
      .describe(
        'Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.'
      ),
    thumbnailDarkUrl: zod
      .string()
      .optional()
      .describe(
        'Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.'
      ),
    thumbnailUrl: zod
      .string()
      .optional()
      .describe(
        'The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.'
      ),
    deleted: zod.boolean().describe('Whether the trip is soft-deleted'),
    registered: zod
      .boolean()
      .describe('Whether the current user is registered for this trip. False if anonymous.'),
    commentCount: zod
      .int()
      .optional()
      .describe(
        'Number of comments, replies included. Absent when the caller may not read the comments of this trip — comments are members-only, so an outsider is told nothing, not even zero.'
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
        "The team's TRIP tags the trip carries, sorted by label. Empty when it carries none."
      ),
    weather: zod
      .object({
        status: zod
          .enum(['OK', 'STALE', 'NOT_YET_AVAILABLE', 'UNAVAILABLE', 'NO_LOCATION', 'OUT_OF_RANGE'])
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
        temperature: zod.number().optional().describe('Air temperature at the departure hour, °C'),
        temperatureMin: zod.number().optional().describe('Lowest temperature over the window, °C'),
        temperatureMax: zod.number().optional().describe('Highest temperature over the window, °C'),
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
        "The weather line of a list card: that of the trip's next leg — its first stage still to leave, else the trip itself when it has no stage — at the start of its route, over the window from its departure to its estimated arrival. Absent when there is nothing to show — trip finished, draft or cancelled, next stage without a route, forecast not in cache yet — and on the trip's own detail, which reads getTripWeather; present only with status OK, STALE or NOT_YET_AVAILABLE."
      ),
  })
  .describe('Trip data')

/**
 * Restore a soft-deleted trip. Requires organizer permissions.
 * @summary Restore trip
 */
export const UndeleteTripParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  tripSlug: zod.string().describe('Trip URL slug'),
})

export const undeleteTripResponseMediaMarkdownMax = 100000

export const undeleteTripResponseStagesItemRouteMediaMarkdownMax = 100000

export const undeleteTripResponseStagesItemMediaMarkdownMax = 100000

export const UndeleteTripResponse = zod
  .object({
    type: zod.enum(['TRIP']),
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
    id: zod.string().describe('Publication ID (TSID)'),
    slug: zod.string().describe('Publication URL slug'),
    name: zod.string().describe('Publication name'),
    media: zod
      .object({
        markdown: zod.string().max(undeleteTripResponseMediaMarkdownMax).describe('Markdown'),
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
      .describe('Publication media'),
    excerpt: zod
      .string()
      .optional()
      .describe(
        "Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter."
      ),
    dateTime: zod.iso.datetime({ offset: true }).describe('Trip start date/time'),
    timezone: zod
      .string()
      .describe(
        "IANA zone the trip's times were entered in and read in: its first stage's, else its route's, else the team's. dateTime, endDate, endDateTime and publishAt are rendezvous in this zone."
      ),
    endDate: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        'Date of the last stage — the day the trip ends. Null when the trip has no stage, in which case it lasts a day and dateTime is both ends.'
      ),
    endDateTime: zod.iso
      .datetime({ offset: true })
      .describe(
        "When the trip is over, computed by the server: the end of its latest stage — its departure plus its route's length at its average speed, or plus 3 hours when the stage has no speed or no route — or dateTime plus 3 hours for a trip with no stage. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Publication status'),
    finished: zod
      .boolean()
      .describe(
        'Whether the trip is over, computed by the server when the response is built: its last stage (endDate, or dateTime when there is none) has started. Independent of status — a past cancelled trip is both CANCELLED and finished.'
      ),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    publishAt: zod.iso.datetime({ offset: true }).optional().describe('Publication timestamp'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Creation timestamp'),
    routeSlug: zod.string().optional().describe('Route slug'),
    participantCount: zod.int().describe('Number of participants'),
    stageCount: zod.int().describe('Number of stages'),
    totalDistance: zod
      .number()
      .optional()
      .describe(
        'Distance in metres over every stage that has a route. Null when no stage has one — an unrouted trip has no distance, which is not the same as a distance of zero.'
      ),
    totalElevationGain: zod
      .number()
      .optional()
      .describe(
        'Elevation gain in metres over every stage that has a route. Null when no stage has one.'
      ),
    stages: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Stage ID (TSID)'),
            slug: zod.string().describe('Stage slug'),
            name: zod.string().describe('Stage name'),
            dateTime: zod.iso.datetime({ offset: true }).describe('Stage date/time'),
            timezone: zod
              .string()
              .describe(
                "IANA zone the stage's time was entered in and is read in: its start place's, else its route's, else the previous stage's, else the trip route's, else the team's. A stage may differ from its trip."
              ),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            route: zod
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
                      .max(undeleteTripResponseStagesItemRouteMediaMarkdownMax)
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
              .optional()
              .describe('Route'),
            startPlace: zod
              .object({
                id: zod.string().describe('Place ID (TSID)'),
                name: zod.string(),
                address: zod.string().optional(),
                link: zod.string().optional(),
                startPlace: zod.boolean(),
                endPlace: zod.boolean(),
                geometry: zod
                  .object({
                    type: zod.enum(['Point']),
                    coordinates: zod
                      .array(zod.number())
                      .describe('Coordinates [longitude, latitude]'),
                  })
                  .optional()
                  .describe('Location coordinates [longitude, latitude]'),
              })
              .optional()
              .describe('Start place'),
            endPlace: zod
              .object({
                id: zod.string().describe('Place ID (TSID)'),
                name: zod.string(),
                address: zod.string().optional(),
                link: zod.string().optional(),
                startPlace: zod.boolean(),
                endPlace: zod.boolean(),
                geometry: zod
                  .object({
                    type: zod.enum(['Point']),
                    coordinates: zod
                      .array(zod.number())
                      .describe('Coordinates [longitude, latitude]'),
                  })
                  .optional()
                  .describe('Location coordinates [longitude, latitude]'),
              })
              .optional()
              .describe('End place'),
            media: zod
              .object({
                markdown: zod
                  .string()
                  .max(undeleteTripResponseStagesItemMediaMarkdownMax)
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
              .describe('Stage media'),
            sortOrder: zod.int().describe('Sort order'),
            stageIndex: zod
              .int()
              .describe(
                "Position of this stage among the trip's live stages, 1-based — the 'Day 2' of a stage header. Unlike sortOrder, which is a persisted rank that may have gaps, this is a rank a client can print."
              ),
            stageCount: zod
              .int()
              .describe("How many live stages the trip has — the '/ 5' of 'Day 2 / 5'."),
            commentCount: zod
              .int()
              .optional()
              .describe(
                "Number of comments on the stage's own thread. Absent when the caller cannot read comments (not a member of the team), like TripDto.commentCount."
              ),
          })
          .describe('Trip stage information')
      )
      .describe('Trip stages'),
    participants: zod
      .array(
        zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .describe('Public user information (limited fields)')
      )
      .describe(
        'The first participants of the trip (at most 8), earliest registrations first — enough to draw avatars; empty on a list row. participantCount is the total; the whole list is paginated and searched by GET …/trips/{tripSlug}/participants. Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.'
      ),
    thumbnailLightUrl: zod
      .string()
      .optional()
      .describe(
        'Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.'
      ),
    thumbnailDarkUrl: zod
      .string()
      .optional()
      .describe(
        'Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.'
      ),
    thumbnailUrl: zod
      .string()
      .optional()
      .describe(
        'The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.'
      ),
    deleted: zod.boolean().describe('Whether the trip is soft-deleted'),
    registered: zod
      .boolean()
      .describe('Whether the current user is registered for this trip. False if anonymous.'),
    commentCount: zod
      .int()
      .optional()
      .describe(
        'Number of comments, replies included. Absent when the caller may not read the comments of this trip — comments are members-only, so an outsider is told nothing, not even zero.'
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
        "The team's TRIP tags the trip carries, sorted by label. Empty when it carries none."
      ),
    weather: zod
      .object({
        status: zod
          .enum(['OK', 'STALE', 'NOT_YET_AVAILABLE', 'UNAVAILABLE', 'NO_LOCATION', 'OUT_OF_RANGE'])
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
        temperature: zod.number().optional().describe('Air temperature at the departure hour, °C'),
        temperatureMin: zod.number().optional().describe('Lowest temperature over the window, °C'),
        temperatureMax: zod.number().optional().describe('Highest temperature over the window, °C'),
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
        "The weather line of a list card: that of the trip's next leg — its first stage still to leave, else the trip itself when it has no stage — at the start of its route, over the window from its departure to its estimated arrival. Absent when there is nothing to show — trip finished, draft or cancelled, next stage without a route, forecast not in cache yet — and on the trip's own detail, which reads getTripWeather; present only with status OK, STALE or NOT_YET_AVAILABLE."
      ),
  })
  .describe('Trip data')

/**
 * The forecast for the trip, stage by stage: along each stage's route at its estimated passages (stage speed, else 25 km/h), each stage with its own state. Read from the server's cache only — the forecast is refreshed in the background, never on request. Readable by whoever may read the trip, and then always 200: the state is in status. Cache-Control: private, no-cache with an ETag (revalidate with If-None-Match, 304 when unchanged); no-store when status is UNAVAILABLE.
 * @summary Get trip weather
 */
export const GetTripWeatherParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
  tripSlug: zod.string().describe('Trip URL slug'),
})

export const GetTripWeatherResponse = zod
  .object({
    status: zod
      .enum(['OK', 'STALE', 'NOT_YET_AVAILABLE', 'UNAVAILABLE', 'NO_LOCATION', 'OUT_OF_RANGE'])
      .describe(
        'Overall state, over the stages yet to leave. OK and STALE (shown, flagged as old) carry a forecast for at least one stage; NOT_YET_AVAILABLE (every stage with a route is beyond the horizon) comes with availableFrom; UNAVAILABLE (nothing in cache yet, or the provider failing) offers to retry; NO_LOCATION (no stage yet to leave has a route) is worth a word to the organisers only; OUT_OF_RANGE (finished, cancelled, draft) shows nothing. Each stage also has its own, in its leg.'
      ),
    availableFrom: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe(
        'For NOT_YET_AVAILABLE: when the first forecast opens, seven days before the first stage with a route leaves'
      ),
    fetchedAt: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe('The oldest fetch among the forecasts read'),
    stages: zod
      .array(
        zod
          .object({
            stageId: zod
              .string()
              .optional()
              .describe(
                "The stage (TSID), as TripStageDto.id. Absent for the single leg of a trip without stages, which rides the trip's own route at its own time."
              ),
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
                "The stage's weather in one line, for its card: the first checkpoint's hour, the extremes over the checkpoints, the rain alert. Present when leg.status is OK, STALE or NOT_YET_AVAILABLE (then status and availableFrom only)."
              ),
            leg: zod
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
                    "State of this leg's forecast. NO_LOCATION when the leg has no route to sample: then no checkpoint, no segment. NOT_YET_AVAILABLE when it leaves beyond the seven-day horizon: checkpoints and times without weather, and availableFrom. OUT_OF_RANGE for a trip stage already gone: nothing to show."
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
                        index: zod
                          .int()
                          .describe('Position of the point on the leg, 0 for the start'),
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
                          .describe(
                            'Mean head component, km/h, signed: positive against the rider'
                          ),
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
              })
              .describe("The stage's route, at its estimated passages (stage speed, else 25 km/h)"),
          })
          .describe('One stage of a trip: its weather in one line, and along its route')
      )
      .describe(
        'One per live stage, in stage order (as TripDto.stages), stages already gone included with leg.status OUT_OF_RANGE; a single one without stageId for a trip without stages. Empty when the trip is not published.'
      ),
    attribution: zod
      .object({
        name: zod.string().describe('Name to display, e.g. "Open-Meteo.com"'),
        url: zod.string().describe('Link of the credit'),
      })
      .describe("The credit the forecast's licence asks for"),
  })
  .describe(
    "A trip's weather, stage by stage: each stage's route at its estimated passages. Read from the server's cache only — the forecast is refreshed in the background, never on request."
  )
