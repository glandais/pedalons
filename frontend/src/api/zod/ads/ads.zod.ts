import * as zod from 'zod'

/**
 * Get paginated list of ads for a team with optional filtering
 * @summary List ads
 */
export const ListAdsParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const listAdsQueryPageDefault = 0
export const listAdsQuerySizeDefault = 20

export const ListAdsQueryParams = zod.object({
  adType: zod.enum(['SALE', 'RENTAL', 'WANTED']).optional().describe('Filter by ad type'),
  from: zod.string().optional().describe('Start date filter (ISO format)'),
  maxPrice: zod.number().optional().describe('Highest asking price to include'),
  minPrice: zod
    .number()
    .optional()
    .describe(
      "Lowest asking price to include. Ads with no price ('à négocier') are excluded by either price bound."
    ),
  nearLat: zod.number().optional().describe('Latitude for proximity search'),
  nearLon: zod.number().optional().describe('Longitude for proximity search'),
  nearRadius: zod
    .number()
    .optional()
    .describe(
      'Search radius in metres around nearLat/nearLon (default 25000, capped at 500000). Ads with no location are excluded when a centre is given.'
    ),
  page: zod.int().default(listAdsQueryPageDefault).describe('Page number'),
  search: zod.string().optional().describe('Search by name/description'),
  size: zod.int().default(listAdsQuerySizeDefault).describe('Page size'),
  sortBy: zod
    .enum(['DATE_TIME', 'PRICE', 'NAME'])
    .optional()
    .describe('Sort column (default: publication date)'),
  sortDir: zod.enum(['ASC', 'DESC']).optional().describe('Sort direction (default: DESC)'),
  tags: zod
    .array(zod.string())
    .optional()
    .describe(
      "Only the ads carrying at least one of these tags — ids (TSID) of the team's AD tags, comma-separated or repeated. Unknown ids are ignored; a filter left with no known id filters nothing."
    ),
  to: zod.string().optional().describe('End date filter (ISO format)'),
  view: zod
    .enum(['FULL', 'COMPACT'])
    .optional()
    .describe(
      "How much of each row to send. COMPACT (case-insensitive) returns media.markdown empty and media.assets trimmed to the logo, the first image and the themed thumbnails — read 'excerpt', 'thumbnailUrl' and 'images' instead, all of which are present either way. The markdown body, the attachments, the GPX and FIT files and every image past the first are dropped. Omitted, or FULL, is the previous behaviour, byte for byte."
    ),
})

export const listAdsResponseAdsItemMediaMarkdownMax = 100000

export const ListAdsResponse = zod
  .object({
    ads: zod
      .array(
        zod
          .object({
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
            id: zod.string().describe('Ad ID (TSID)'),
            slug: zod.string().describe('Ad URL slug'),
            name: zod.string().describe('Ad name'),
            media: zod
              .object({
                markdown: zod
                  .string()
                  .max(listAdsResponseAdsItemMediaMarkdownMax)
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
              .describe('Ad media'),
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
                "URL template of the ad's first picture, the one a card shows. Saves a compact row from carrying media.assets just to find it. Opaque URL: may carry a query string; substitute {size} only."
              ),
            images: zod
              .array(zod.string())
              .describe(
                "URL templates of every picture on the ad, in editor order — the gallery. Present whatever the 'view', so a compact row can show a carousel without pulling media.assets. The first entry is the same picture as 'thumbnailUrl'."
              ),
            status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Ad status'),
            visibility: zod
              .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
              .describe('Visibility level'),
            adType: zod.enum(['SALE', 'RENTAL', 'WANTED']).describe('Ad type'),
            price: zod.number().optional().describe('Price'),
            rentalPeriod: zod
              .enum(['DAY', 'WEEK', 'MONTH'])
              .optional()
              .describe(
                "Period the price applies to, for a rental — render as 'price / period'. Null for a sale, and for a rental whose period has not been set."
              ),
            locationDescription: zod.string().optional().describe('Location description'),
            locationGeometry: zod
              .object({
                type: zod.enum(['Point']),
                coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
              })
              .optional()
              .describe(
                "Approximate location of the ad, deliberately blurred: the point is the centre of a fixed cell about 1 km across, not the seller's address. Enough to tell a nearby ad from a distant one, and the same value on every read so repeated calls cannot be averaged back to the exact position. Null when the ad has no location. The exact point stays on AdEditDto, and only for the seller: the team's admins get this blurred point there too. Proximity filters measure from this blurred point too, never from the exact one."
              ),
            createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
            updatedAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
            createdById: zod.string().describe('Creator ID (TSID)'),
            createdByDisplayName: zod
              .string()
              .describe(
                'Display name of the member who posted the ad. The only thing about them this DTO carries: there is no contact channel on an Ad, and inventing one (an email, a phone number) is a product decision, not a serialisation one.'
              ),
            deleted: zod.boolean().describe('Whether the ad is soft-deleted'),
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
                "The team's AD tags the ad carries, sorted by label. Empty when it carries none."
              ),
          })
          .describe('Ad data')
      )
      .describe('List of ads'),
    total: zod.int().describe('Total number of ads'),
    page: zod.int().describe('Current page number'),
    size: zod.int().describe('Page size'),
  })
  .describe('Paginated ad list response')

/**
 * Create a new ad. Any team member can create ads.
 * @summary Create ad
 */
export const CreateAdParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const createAdBodyNameMax = 200

export const createAdBodyNameRegExp = new RegExp('\\S')
export const createAdBodyMediaMarkdownMax = 100000

export const createAdBodyLocationDescriptionMax = 200

export const CreateAdBody = zod
  .object({
    name: zod
      .string()
      .min(1)
      .max(createAdBodyNameMax)
      .regex(createAdBodyNameRegExp)
      .describe('Ad name'),
    media: zod
      .object({
        markdown: zod.string().max(createAdBodyMediaMarkdownMax).describe('Markdown'),
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
      .describe('Ad description'),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Ad status'),
    adType: zod.enum(['SALE', 'RENTAL', 'WANTED']).describe('Ad type'),
    price: zod.number().optional().describe("Price (optional, null for 'contact for price')"),
    rentalPeriod: zod
      .enum(['DAY', 'WEEK', 'MONTH'])
      .optional()
      .describe('Rental period (required for RENTAL type)'),
    locationDescription: zod
      .string()
      .max(createAdBodyLocationDescriptionMax)
      .optional()
      .describe('Location description'),
    locationGeometry: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe('Location coordinates [longitude, latitude]'),
    tagIds: zod
      .array(zod.string())
      .optional()
      .describe(
        "IDs (TSID) of the team's AD tags the ad carries, replacing the whole set — at most 10, each a tag of this team and of kind AD, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update."
      ),
  })
  .describe('Ad request')

export const createAdResponseMediaMarkdownMax = 100000

export const CreateAdResponse = zod
  .object({
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
    id: zod.string().describe('Ad ID (TSID)'),
    slug: zod.string().describe('Ad URL slug'),
    name: zod.string().describe('Ad name'),
    media: zod
      .object({
        markdown: zod.string().max(createAdResponseMediaMarkdownMax).describe('Markdown'),
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
      .describe('Ad media'),
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
        "URL template of the ad's first picture, the one a card shows. Saves a compact row from carrying media.assets just to find it. Opaque URL: may carry a query string; substitute {size} only."
      ),
    images: zod
      .array(zod.string())
      .describe(
        "URL templates of every picture on the ad, in editor order — the gallery. Present whatever the 'view', so a compact row can show a carousel without pulling media.assets. The first entry is the same picture as 'thumbnailUrl'."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Ad status'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    adType: zod.enum(['SALE', 'RENTAL', 'WANTED']).describe('Ad type'),
    price: zod.number().optional().describe('Price'),
    rentalPeriod: zod
      .enum(['DAY', 'WEEK', 'MONTH'])
      .optional()
      .describe(
        "Period the price applies to, for a rental — render as 'price / period'. Null for a sale, and for a rental whose period has not been set."
      ),
    locationDescription: zod.string().optional().describe('Location description'),
    locationGeometry: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe(
        "Approximate location of the ad, deliberately blurred: the point is the centre of a fixed cell about 1 km across, not the seller's address. Enough to tell a nearby ad from a distant one, and the same value on every read so repeated calls cannot be averaged back to the exact position. Null when the ad has no location. The exact point stays on AdEditDto, and only for the seller: the team's admins get this blurred point there too. Proximity filters measure from this blurred point too, never from the exact one."
      ),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    updatedAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    createdById: zod.string().describe('Creator ID (TSID)'),
    createdByDisplayName: zod
      .string()
      .describe(
        'Display name of the member who posted the ad. The only thing about them this DTO carries: there is no contact channel on an Ad, and inventing one (an email, a phone number) is a product decision, not a serialisation one.'
      ),
    deleted: zod.boolean().describe('Whether the ad is soft-deleted'),
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
      .describe("The team's AD tags the ad carries, sorted by label. Empty when it carries none."),
  })
  .describe('Ad data')

/**
 * How many of the team's classifieds match the filters, with none of them read. Accepts exactly the same filters as the classifieds list, minus sorting and pagination, so the figure and the list it opens can never disagree. Meant for a filter sheet that wants to announce its result count before the user commits to it.
 * @summary Count ads
 */
export const CountAdsParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const CountAdsQueryParams = zod.object({
  adType: zod.enum(['SALE', 'RENTAL', 'WANTED']).optional().describe('Filter by ad type'),
  from: zod.string().optional().describe('Start date filter (ISO format)'),
  maxPrice: zod.number().optional().describe('Highest asking price to include'),
  minPrice: zod
    .number()
    .optional()
    .describe(
      "Lowest asking price to include. Ads with no price ('à négocier') are excluded by either price bound."
    ),
  nearLat: zod.number().optional().describe('Latitude for proximity search'),
  nearLon: zod.number().optional().describe('Longitude for proximity search'),
  nearRadius: zod
    .number()
    .optional()
    .describe(
      'Search radius in metres around nearLat/nearLon (default 25000, capped at 500000). Ads with no location are excluded when a centre is given.'
    ),
  search: zod.string().optional().describe('Search by name/description'),
  tags: zod
    .array(zod.string())
    .optional()
    .describe(
      "Only the ads carrying at least one of these tags — ids (TSID) of the team's AD tags, comma-separated or repeated. Unknown ids are ignored; a filter left with no known id filters nothing."
    ),
  to: zod.string().optional().describe('End date filter (ISO format)'),
})

export const CountAdsResponse = zod
  .object({
    total: zod.int().describe('Total number of matching items'),
  })
  .describe('Number of items matching a filter set')

/**
 * Update ad information. Only the creator or an admin can update.
 * @summary Update ad
 */
export const UpdateAdParams = zod.object({
  slug: zod.string().describe('Ad URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const updateAdBodyNameMax = 200

export const updateAdBodyNameRegExp = new RegExp('\\S')
export const updateAdBodyMediaMarkdownMax = 100000

export const updateAdBodyLocationDescriptionMax = 200

export const UpdateAdBody = zod
  .object({
    name: zod
      .string()
      .min(1)
      .max(updateAdBodyNameMax)
      .regex(updateAdBodyNameRegExp)
      .describe('Ad name'),
    media: zod
      .object({
        markdown: zod.string().max(updateAdBodyMediaMarkdownMax).describe('Markdown'),
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
      .describe('Ad description'),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Ad status'),
    adType: zod.enum(['SALE', 'RENTAL', 'WANTED']).describe('Ad type'),
    price: zod.number().optional().describe("Price (optional, null for 'contact for price')"),
    rentalPeriod: zod
      .enum(['DAY', 'WEEK', 'MONTH'])
      .optional()
      .describe('Rental period (required for RENTAL type)'),
    locationDescription: zod
      .string()
      .max(updateAdBodyLocationDescriptionMax)
      .optional()
      .describe('Location description'),
    locationGeometry: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe('Location coordinates [longitude, latitude]'),
    tagIds: zod
      .array(zod.string())
      .optional()
      .describe(
        "IDs (TSID) of the team's AD tags the ad carries, replacing the whole set — at most 10, each a tag of this team and of kind AD, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update."
      ),
  })
  .describe('Ad request')

export const updateAdResponseMediaMarkdownMax = 100000

export const UpdateAdResponse = zod
  .object({
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
    id: zod.string().describe('Ad ID (TSID)'),
    slug: zod.string().describe('Ad URL slug'),
    name: zod.string().describe('Ad name'),
    media: zod
      .object({
        markdown: zod.string().max(updateAdResponseMediaMarkdownMax).describe('Markdown'),
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
      .describe('Ad media'),
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
        "URL template of the ad's first picture, the one a card shows. Saves a compact row from carrying media.assets just to find it. Opaque URL: may carry a query string; substitute {size} only."
      ),
    images: zod
      .array(zod.string())
      .describe(
        "URL templates of every picture on the ad, in editor order — the gallery. Present whatever the 'view', so a compact row can show a carousel without pulling media.assets. The first entry is the same picture as 'thumbnailUrl'."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Ad status'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    adType: zod.enum(['SALE', 'RENTAL', 'WANTED']).describe('Ad type'),
    price: zod.number().optional().describe('Price'),
    rentalPeriod: zod
      .enum(['DAY', 'WEEK', 'MONTH'])
      .optional()
      .describe(
        "Period the price applies to, for a rental — render as 'price / period'. Null for a sale, and for a rental whose period has not been set."
      ),
    locationDescription: zod.string().optional().describe('Location description'),
    locationGeometry: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe(
        "Approximate location of the ad, deliberately blurred: the point is the centre of a fixed cell about 1 km across, not the seller's address. Enough to tell a nearby ad from a distant one, and the same value on every read so repeated calls cannot be averaged back to the exact position. Null when the ad has no location. The exact point stays on AdEditDto, and only for the seller: the team's admins get this blurred point there too. Proximity filters measure from this blurred point too, never from the exact one."
      ),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    updatedAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    createdById: zod.string().describe('Creator ID (TSID)'),
    createdByDisplayName: zod
      .string()
      .describe(
        'Display name of the member who posted the ad. The only thing about them this DTO carries: there is no contact channel on an Ad, and inventing one (an email, a phone number) is a product decision, not a serialisation one.'
      ),
    deleted: zod.boolean().describe('Whether the ad is soft-deleted'),
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
      .describe("The team's AD tags the ad carries, sorted by label. Empty when it carries none."),
  })
  .describe('Ad data')

/**
 * Get detailed ad information
 * @summary Get ad details
 */
export const GetAdParams = zod.object({
  slug: zod.string().describe('Ad URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const getAdResponseMediaMarkdownMax = 100000

export const GetAdResponse = zod
  .object({
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
    id: zod.string().describe('Ad ID (TSID)'),
    slug: zod.string().describe('Ad URL slug'),
    name: zod.string().describe('Ad name'),
    media: zod
      .object({
        markdown: zod.string().max(getAdResponseMediaMarkdownMax).describe('Markdown'),
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
      .describe('Ad media'),
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
        "URL template of the ad's first picture, the one a card shows. Saves a compact row from carrying media.assets just to find it. Opaque URL: may carry a query string; substitute {size} only."
      ),
    images: zod
      .array(zod.string())
      .describe(
        "URL templates of every picture on the ad, in editor order — the gallery. Present whatever the 'view', so a compact row can show a carousel without pulling media.assets. The first entry is the same picture as 'thumbnailUrl'."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Ad status'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    adType: zod.enum(['SALE', 'RENTAL', 'WANTED']).describe('Ad type'),
    price: zod.number().optional().describe('Price'),
    rentalPeriod: zod
      .enum(['DAY', 'WEEK', 'MONTH'])
      .optional()
      .describe(
        "Period the price applies to, for a rental — render as 'price / period'. Null for a sale, and for a rental whose period has not been set."
      ),
    locationDescription: zod.string().optional().describe('Location description'),
    locationGeometry: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe(
        "Approximate location of the ad, deliberately blurred: the point is the centre of a fixed cell about 1 km across, not the seller's address. Enough to tell a nearby ad from a distant one, and the same value on every read so repeated calls cannot be averaged back to the exact position. Null when the ad has no location. The exact point stays on AdEditDto, and only for the seller: the team's admins get this blurred point there too. Proximity filters measure from this blurred point too, never from the exact one."
      ),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    updatedAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    createdById: zod.string().describe('Creator ID (TSID)'),
    createdByDisplayName: zod
      .string()
      .describe(
        'Display name of the member who posted the ad. The only thing about them this DTO carries: there is no contact channel on an Ad, and inventing one (an email, a phone number) is a product decision, not a serialisation one.'
      ),
    deleted: zod.boolean().describe('Whether the ad is soft-deleted'),
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
      .describe("The team's AD tags the ad carries, sorted by label. Empty when it carries none."),
  })
  .describe('Ad data')

/**
 * Soft delete an ad. Only the creator or an admin can delete.
 * @summary Delete ad
 */
export const DeleteAdParams = zod.object({
  slug: zod.string().describe('Ad URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const DeleteAdResponse = zod.void()

/**
 * Relays a message to the author of an ad. Neither party's address appears anywhere in this API: the server sends the email and sets Reply-To to the caller, so the author can answer directly. Writing therefore discloses the caller's address to the author — a one-way disclosure the caller chose — while the author's address is never disclosed at all. Requires the same access as reading the ad.
 * @summary Contact an ad's author
 */
export const ContactAdAuthorParams = zod.object({
  slug: zod.string().describe('Ad URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const contactAdAuthorBodyMessageMin = 10
export const contactAdAuthorBodyMessageMax = 2000

export const contactAdAuthorBodyMessageRegExp = new RegExp('\\S')

export const ContactAdAuthorBody = zod
  .object({
    message: zod
      .string()
      .min(contactAdAuthorBodyMessageMin)
      .max(contactAdAuthorBodyMessageMax)
      .regex(contactAdAuthorBodyMessageRegExp)
      .describe(
        'The message body, plain text. Rendered as text in the email: any markup is escaped rather than interpreted.'
      ),
  })
  .describe('A message to relay to the author of an ad')

export const ContactAdAuthorResponse = zod.void()

/**
 * Get detailed ad information
 * @summary Get ad details for edit
 */
export const GetAdEditParams = zod.object({
  slug: zod.string().describe('Ad URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const getAdEditResponseMediaMarkdownMax = 100000

export const GetAdEditResponse = zod
  .object({
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
    id: zod.string().describe('Ad ID (TSID)'),
    slug: zod.string().describe('Ad URL slug'),
    name: zod.string().describe('Ad name'),
    media: zod
      .object({
        markdown: zod.string().max(getAdEditResponseMediaMarkdownMax).describe('Markdown'),
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
      .describe('Ad media'),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Ad status'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    adType: zod.enum(['SALE', 'RENTAL', 'WANTED']).describe('Ad type'),
    price: zod.number().optional().describe('Price'),
    rentalPeriod: zod.enum(['DAY', 'WEEK', 'MONTH']).optional().describe('Rental period'),
    locationGeometry: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe(
        "Location coordinates [longitude, latitude]. Exact for the ad's author only; any other editor (a team admin, a platform admin) gets the same blurred point as AdDto, the centre of a cell about 1 km across. Sending that blurred point back unchanged in an update by a non-author keeps the stored exact point; any other value replaces it."
      ),
    locationDescription: zod.string().optional().describe('Location description'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    updatedAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    createdById: zod.string().describe('Creator ID (TSID)'),
    deleted: zod.boolean().describe('Whether the ad is soft-deleted'),
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
        "The team's AD tags the ad carries, sorted by label — what the edit form's tagIds starts from."
      ),
  })
  .describe('Ad data')

/**
 * Change ad URL slug. Requires admin permissions.
 * @summary Change ad slug
 */
export const ChangeAdSlugParams = zod.object({
  slug: zod.string().describe('Current ad URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const changeAdSlugBodySlugMax = 200

export const changeAdSlugBodySlugRegExp = new RegExp('^[a-z0-9]+(-[a-z0-9]+)*$')

export const ChangeAdSlugBody = zod
  .object({
    slug: zod
      .string()
      .max(changeAdSlugBodySlugMax)
      .regex(changeAdSlugBodySlugRegExp)
      .describe('New slug (lowercase letters, numbers, and hyphens only)'),
  })
  .describe('Slug change request')

export const changeAdSlugResponseMediaMarkdownMax = 100000

export const ChangeAdSlugResponse = zod
  .object({
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
    id: zod.string().describe('Ad ID (TSID)'),
    slug: zod.string().describe('Ad URL slug'),
    name: zod.string().describe('Ad name'),
    media: zod
      .object({
        markdown: zod.string().max(changeAdSlugResponseMediaMarkdownMax).describe('Markdown'),
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
      .describe('Ad media'),
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
        "URL template of the ad's first picture, the one a card shows. Saves a compact row from carrying media.assets just to find it. Opaque URL: may carry a query string; substitute {size} only."
      ),
    images: zod
      .array(zod.string())
      .describe(
        "URL templates of every picture on the ad, in editor order — the gallery. Present whatever the 'view', so a compact row can show a carousel without pulling media.assets. The first entry is the same picture as 'thumbnailUrl'."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Ad status'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    adType: zod.enum(['SALE', 'RENTAL', 'WANTED']).describe('Ad type'),
    price: zod.number().optional().describe('Price'),
    rentalPeriod: zod
      .enum(['DAY', 'WEEK', 'MONTH'])
      .optional()
      .describe(
        "Period the price applies to, for a rental — render as 'price / period'. Null for a sale, and for a rental whose period has not been set."
      ),
    locationDescription: zod.string().optional().describe('Location description'),
    locationGeometry: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe(
        "Approximate location of the ad, deliberately blurred: the point is the centre of a fixed cell about 1 km across, not the seller's address. Enough to tell a nearby ad from a distant one, and the same value on every read so repeated calls cannot be averaged back to the exact position. Null when the ad has no location. The exact point stays on AdEditDto, and only for the seller: the team's admins get this blurred point there too. Proximity filters measure from this blurred point too, never from the exact one."
      ),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    updatedAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    createdById: zod.string().describe('Creator ID (TSID)'),
    createdByDisplayName: zod
      .string()
      .describe(
        'Display name of the member who posted the ad. The only thing about them this DTO carries: there is no contact channel on an Ad, and inventing one (an email, a phone number) is a product decision, not a serialisation one.'
      ),
    deleted: zod.boolean().describe('Whether the ad is soft-deleted'),
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
      .describe("The team's AD tags the ad carries, sorted by label. Empty when it carries none."),
  })
  .describe('Ad data')

/**
 * Change the ad's status and nothing else — what a list row can do without the full ad. Same side effects as a status change through the update. Requires the team admin or the ad's author.
 * @summary Change ad status
 */
export const ChangeAdStatusParams = zod.object({
  slug: zod.string().describe('Ad URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const ChangeAdStatusBody = zod
  .object({
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('New status'),
  })
  .describe('Status change request')

export const changeAdStatusResponseMediaMarkdownMax = 100000

export const ChangeAdStatusResponse = zod
  .object({
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
    id: zod.string().describe('Ad ID (TSID)'),
    slug: zod.string().describe('Ad URL slug'),
    name: zod.string().describe('Ad name'),
    media: zod
      .object({
        markdown: zod.string().max(changeAdStatusResponseMediaMarkdownMax).describe('Markdown'),
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
      .describe('Ad media'),
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
        "URL template of the ad's first picture, the one a card shows. Saves a compact row from carrying media.assets just to find it. Opaque URL: may carry a query string; substitute {size} only."
      ),
    images: zod
      .array(zod.string())
      .describe(
        "URL templates of every picture on the ad, in editor order — the gallery. Present whatever the 'view', so a compact row can show a carousel without pulling media.assets. The first entry is the same picture as 'thumbnailUrl'."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Ad status'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    adType: zod.enum(['SALE', 'RENTAL', 'WANTED']).describe('Ad type'),
    price: zod.number().optional().describe('Price'),
    rentalPeriod: zod
      .enum(['DAY', 'WEEK', 'MONTH'])
      .optional()
      .describe(
        "Period the price applies to, for a rental — render as 'price / period'. Null for a sale, and for a rental whose period has not been set."
      ),
    locationDescription: zod.string().optional().describe('Location description'),
    locationGeometry: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe(
        "Approximate location of the ad, deliberately blurred: the point is the centre of a fixed cell about 1 km across, not the seller's address. Enough to tell a nearby ad from a distant one, and the same value on every read so repeated calls cannot be averaged back to the exact position. Null when the ad has no location. The exact point stays on AdEditDto, and only for the seller: the team's admins get this blurred point there too. Proximity filters measure from this blurred point too, never from the exact one."
      ),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    updatedAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    createdById: zod.string().describe('Creator ID (TSID)'),
    createdByDisplayName: zod
      .string()
      .describe(
        'Display name of the member who posted the ad. The only thing about them this DTO carries: there is no contact channel on an Ad, and inventing one (an email, a phone number) is a product decision, not a serialisation one.'
      ),
    deleted: zod.boolean().describe('Whether the ad is soft-deleted'),
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
      .describe("The team's AD tags the ad carries, sorted by label. Empty when it carries none."),
  })
  .describe('Ad data')

/**
 * Restore a soft-deleted ad. Only the creator or an admin can restore.
 * @summary Restore ad
 */
export const UndeleteAdParams = zod.object({
  slug: zod.string().describe('Ad URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const undeleteAdResponseMediaMarkdownMax = 100000

export const UndeleteAdResponse = zod
  .object({
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
    id: zod.string().describe('Ad ID (TSID)'),
    slug: zod.string().describe('Ad URL slug'),
    name: zod.string().describe('Ad name'),
    media: zod
      .object({
        markdown: zod.string().max(undeleteAdResponseMediaMarkdownMax).describe('Markdown'),
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
      .describe('Ad media'),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Ad status'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    adType: zod.enum(['SALE', 'RENTAL', 'WANTED']).describe('Ad type'),
    price: zod.number().optional().describe('Price'),
    rentalPeriod: zod.enum(['DAY', 'WEEK', 'MONTH']).optional().describe('Rental period'),
    locationGeometry: zod
      .object({
        type: zod.enum(['Point']),
        coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
      })
      .optional()
      .describe(
        "Location coordinates [longitude, latitude]. Exact for the ad's author only; any other editor (a team admin, a platform admin) gets the same blurred point as AdDto, the centre of a cell about 1 km across. Sending that blurred point back unchanged in an update by a non-author keeps the stored exact point; any other value replaces it."
      ),
    locationDescription: zod.string().optional().describe('Location description'),
    createdAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    updatedAt: zod.iso.datetime({ offset: true }).describe('Creation timestamp'),
    createdById: zod.string().describe('Creator ID (TSID)'),
    deleted: zod.boolean().describe('Whether the ad is soft-deleted'),
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
        "The team's AD tags the ad carries, sorted by label — what the edit form's tagIds starts from."
      ),
  })
  .describe('Ad data')
