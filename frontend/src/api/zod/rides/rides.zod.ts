import * as zod from 'zod'

/**
 * Create a new ride with optional groups
 * @summary Create ride
 */
export const CreateRideParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const createRideBodyNameMin = 3
export const createRideBodyNameMax = 200

export const createRideBodyNameRegExp = new RegExp('\\S')
export const createRideBodyMediaMarkdownMax = 100000

export const createRideBodyGroupsItemNameMax = 200

export const createRideBodyGroupsItemNameRegExp = new RegExp('\\S')
export const createRideBodyGroupsItemAverageSpeedExclusiveMin = 0

export const createRideBodyGroupsItemMaxParticipantsExclusiveMin = 0

export const CreateRideBody = zod
  .object({
    name: zod
      .string()
      .min(createRideBodyNameMin)
      .max(createRideBodyNameMax)
      .regex(createRideBodyNameRegExp)
      .describe('Ride name'),
    media: zod
      .object({
        markdown: zod.string().max(createRideBodyMediaMarkdownMax).describe('Markdown'),
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
      .describe('Ride media'),
    dateTime: zod
      .string()
      .describe(
        "Ride date/time: a wall time without offset, read in the ride's zone (start place, else route, else team)."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Ride status'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    routeSlug: zod.string().optional().describe('Route slug'),
    startPlaceId: zod.string().optional().describe('Start place ID (TSID)'),
    endPlaceId: zod.string().optional().describe('End place ID (TSID)'),
    publishAt: zod
      .string()
      .optional()
      .describe(
        "Publication time (for scheduled publishing), a wall time in the ride's zone like dateTime."
      ),
    groups: zod
      .array(
        zod
          .object({
            id: zod.string().optional().describe('id'),
            name: zod
              .string()
              .min(1)
              .max(createRideBodyGroupsItemNameMax)
              .regex(createRideBodyGroupsItemNameRegExp)
              .describe('Group name'),
            time: zod.string().optional(),
            averageSpeed: zod
              .number()
              .gt(createRideBodyGroupsItemAverageSpeedExclusiveMin)
              .optional()
              .describe('Average speed in km/h'),
            maxParticipants: zod
              .int()
              .gt(createRideBodyGroupsItemMaxParticipantsExclusiveMin)
              .optional()
              .describe('Maximum participants'),
            routeSlug: zod.string().optional().describe('Route slug for this group'),
            leaderId: zod
              .string()
              .optional()
              .describe(
                "ID (TSID) of the member who leads this group. Must belong to the team owning the ride. Omit or send null for no designated leader — clients then show no leader at all rather than falling back on the ride's creator."
              ),
          })
          .describe('Ride group creation request')
      )
      .describe('Ride groups to create'),
    tagIds: zod
      .array(zod.string())
      .optional()
      .describe(
        "IDs (TSID) of the team's RIDE tags the ride carries, replacing the whole set — at most 10, each a tag of this team and of kind RIDE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update."
      ),
    templateId: zod
      .string()
      .optional()
      .describe(
        "ID (TSID) of the team's template the ride is created from. On a creation, raises the template's nextNumber by one when it has one; ignored on an update, and when the template no longer exists."
      ),
  })
  .describe('Ride request')

export const createRideResponseMediaMarkdownMax = 100000

export const CreateRideResponse = zod
  .object({
    type: zod.enum(['RIDE']),
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
        markdown: zod.string().max(createRideResponseMediaMarkdownMax).describe('Markdown'),
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
    dateTime: zod.iso.datetime({ offset: true }).describe('Publication date/time'),
    timezone: zod
      .string()
      .describe(
        "IANA zone the ride's times were entered in and read in: its start place's, else its route's, else the team's. dateTime, publishAt, endDateTime and the groups' startAt are rendezvous in this zone."
      ),
    endDateTime: zod.iso
      .datetime({ offset: true })
      .describe(
        "When the ride is over, computed by the server: the latest of its groups, each one its departure plus its route's length at its average speed — or plus 3 hours when the group has no speed or no route, and for a ride with no group. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Publication status'),
    finished: zod
      .boolean()
      .describe(
        'Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished.'
      ),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    publishAt: zod.iso.datetime({ offset: true }).optional().describe('Publication timestamp'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Creation timestamp'),
    routeSlug: zod.string().optional().describe('Route slug'),
    participantCount: zod.int().describe('Number of participants'),
    groupCount: zod.int().describe('Number of groups'),
    groups: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod
              .string()
              .optional()
              .describe(
                "Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time."
              ),
            startAt: zod.iso
              .datetime({ offset: true })
              .describe(
                "When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own."
              ),
            routeSlug: zod.string().optional().describe('Route slug'),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            maxParticipants: zod.int().optional().describe('Maximum participants'),
            countParticipants: zod.int().describe('Current number of participants'),
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
                'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.'
              ),
            sortOrder: zod.int().describe('Sort order'),
            registered: zod
              .boolean()
              .describe(
                'Whether the current user is registered in THIS group. False if anonymous.'
              ),
            full: zod
              .boolean()
              .describe(
                'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
              ),
            distance: zod
              .number()
              .optional()
              .describe('Distance in meters of the group route, if it has one'),
            elevationGain: zod
              .number()
              .optional()
              .describe('Total elevation gain in meters of the group route, if it has one'),
            leader: zod
              .object({
                id: zod.string().describe('User ID (TSID)'),
                displayName: zod.string().describe('User display name'),
                avatarUrl: zod.string().optional().describe('User avatar URL'),
              })
              .optional()
              .describe(
                "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride."
              ),
            thumbnailLightUrl: zod
              .string()
              .optional()
              .describe(
                'Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
              ),
            thumbnailDarkUrl: zod
              .string()
              .optional()
              .describe(
                'Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
              ),
            thumbnailUrl: zod
              .string()
              .optional()
              .describe(
                "The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only."
              ),
          })
          .describe('Ride group information')
      )
      .describe('Ride groups'),
    groupSummaries: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod
              .string()
              .optional()
              .describe("Start time of the group, when it differs from the ride's"),
            startAt: zod.iso
              .datetime({ offset: true })
              .describe(
                'When the group leaves, as RideGroupDto.startAt. Replaces time, kept for the clients that still read it.'
              ),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            countParticipants: zod.int().describe('Current number of participants'),
            maxParticipants: zod
              .int()
              .optional()
              .describe('Maximum participants, null when the group is uncapped'),
            full: zod
              .boolean()
              .describe(
                'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
              ),
            routeSlug: zod.string().optional().describe('Slug of the group route, if it has one'),
            distance: zod
              .number()
              .optional()
              .describe('Distance in meters of the group route, if it has one'),
            elevationGain: zod
              .number()
              .optional()
              .describe('Total elevation gain in meters of the group route, if it has one'),
            sortOrder: zod.int().describe('Sort order'),
          })
          .describe(
            "One group of a ride, as a list row shows it: name, pace and fill. Same figures as the matching entry of the detail's groups, without the participants nor the leader."
          )
      )
      .describe(
        'Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.'
      ),
    distance: zod
      .number()
      .optional()
      .describe(
        "Distance in meters of the ride's route — or, when the ride itself has none, of the route of its first group (in sort order) that has one. Null when no route is set anywhere."
      ),
    elevationGain: zod
      .number()
      .optional()
      .describe(
        'Total elevation gain in meters, from the same route as distance. Null when no route is set anywhere.'
      ),
    surfaceType: zod
      .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
      .optional()
      .describe(
        'Surface type, from the same route as distance. Null when no route is set anywhere.'
      ),
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
            coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
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
            coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
          })
          .optional()
          .describe('Location coordinates [longitude, latitude]'),
      })
      .optional()
      .describe('End place'),
    topParticipants: zod
      .array(
        zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .describe('Public user information (limited fields)')
      )
      .describe('Preview of first participants (max 5)'),
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
    deleted: zod.boolean().describe('Whether the ride is soft-deleted'),
    registered: zod
      .boolean()
      .describe(
        "Whether the current user is registered in one of this ride's groups. False if anonymous."
      ),
    registeredGroupId: zod
      .string()
      .optional()
      .describe('ID (TSID) of the group the current user joined, null if not registered'),
    registeredGroup: zod
      .object({
        id: zod.string().describe('Group ID (TSID)'),
        name: zod.string().describe('Group name'),
        time: zod
          .string()
          .optional()
          .describe(
            "Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time."
          ),
        startAt: zod.iso
          .datetime({ offset: true })
          .describe(
            "When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own."
          ),
        routeSlug: zod.string().optional().describe('Route slug'),
        averageSpeed: zod.number().optional().describe('Average speed in km/h'),
        maxParticipants: zod.int().optional().describe('Maximum participants'),
        countParticipants: zod.int().describe('Current number of participants'),
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
            'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.'
          ),
        sortOrder: zod.int().describe('Sort order'),
        registered: zod
          .boolean()
          .describe('Whether the current user is registered in THIS group. False if anonymous.'),
        full: zod
          .boolean()
          .describe(
            'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
          ),
        distance: zod
          .number()
          .optional()
          .describe('Distance in meters of the group route, if it has one'),
        elevationGain: zod
          .number()
          .optional()
          .describe('Total elevation gain in meters of the group route, if it has one'),
        leader: zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .optional()
          .describe(
            "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride."
          ),
        thumbnailLightUrl: zod
          .string()
          .optional()
          .describe(
            'Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
          ),
        thumbnailDarkUrl: zod
          .string()
          .optional()
          .describe(
            'Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
          ),
        thumbnailUrl: zod
          .string()
          .optional()
          .describe(
            "The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only."
          ),
      })
      .optional()
      .describe(
        'The group the current user joined, in full — the same object as the matching entry of groups. Null if not registered or anonymous. Set on list rows too, where groups is empty: a client rendering "my next ride" needs no second request for its group. Its leader is the group\'s own, null when none was designated.'
      ),
    full: zod
      .boolean()
      .describe(
        'Whether every group of the ride has reached its capacity. False when the ride has no group, or when at least one group has no maxParticipants.'
      ),
    maxParticipants: zod
      .int()
      .optional()
      .describe(
        'Capacity of the whole ride: the sum of its groups\' maxParticipants, to render participantCount against it ("12/40"). Null when the ride has no group, or when at least one group has no maxParticipants — the ride then has no overall limit, and is never full. Set on list rows too, where groups is empty.'
      ),
    commentCount: zod
      .int()
      .optional()
      .describe(
        'Number of comments, replies included. Absent when the caller may not read the comments of this ride — comments are members-only, so an outsider is told nothing, not even zero.'
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
        "The team's RIDE tags the ride carries, sorted by label. Empty when it carries none."
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
        'The weather line of a card: the meeting point, over the window from the departure to the estimated arrival of the last group. Absent when there is nothing to show — finished or cancelled ride, no place, forecast not in cache yet; present only with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather.'
      ),
  })
  .describe('Ride summary data')

/**
 * Update ride information. Requires organizer permissions.
 * @summary Update ride
 */
export const UpdateRideParams = zod.object({
  rideSlug: zod.string().describe('Ride URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const updateRideBodyNameMin = 3
export const updateRideBodyNameMax = 200

export const updateRideBodyNameRegExp = new RegExp('\\S')
export const updateRideBodyMediaMarkdownMax = 100000

export const updateRideBodyGroupsItemNameMax = 200

export const updateRideBodyGroupsItemNameRegExp = new RegExp('\\S')
export const updateRideBodyGroupsItemAverageSpeedExclusiveMin = 0

export const updateRideBodyGroupsItemMaxParticipantsExclusiveMin = 0

export const UpdateRideBody = zod
  .object({
    name: zod
      .string()
      .min(updateRideBodyNameMin)
      .max(updateRideBodyNameMax)
      .regex(updateRideBodyNameRegExp)
      .describe('Ride name'),
    media: zod
      .object({
        markdown: zod.string().max(updateRideBodyMediaMarkdownMax).describe('Markdown'),
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
      .describe('Ride media'),
    dateTime: zod
      .string()
      .describe(
        "Ride date/time: a wall time without offset, read in the ride's zone (start place, else route, else team)."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Ride status'),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    routeSlug: zod.string().optional().describe('Route slug'),
    startPlaceId: zod.string().optional().describe('Start place ID (TSID)'),
    endPlaceId: zod.string().optional().describe('End place ID (TSID)'),
    publishAt: zod
      .string()
      .optional()
      .describe(
        "Publication time (for scheduled publishing), a wall time in the ride's zone like dateTime."
      ),
    groups: zod
      .array(
        zod
          .object({
            id: zod.string().optional().describe('id'),
            name: zod
              .string()
              .min(1)
              .max(updateRideBodyGroupsItemNameMax)
              .regex(updateRideBodyGroupsItemNameRegExp)
              .describe('Group name'),
            time: zod.string().optional(),
            averageSpeed: zod
              .number()
              .gt(updateRideBodyGroupsItemAverageSpeedExclusiveMin)
              .optional()
              .describe('Average speed in km/h'),
            maxParticipants: zod
              .int()
              .gt(updateRideBodyGroupsItemMaxParticipantsExclusiveMin)
              .optional()
              .describe('Maximum participants'),
            routeSlug: zod.string().optional().describe('Route slug for this group'),
            leaderId: zod
              .string()
              .optional()
              .describe(
                "ID (TSID) of the member who leads this group. Must belong to the team owning the ride. Omit or send null for no designated leader — clients then show no leader at all rather than falling back on the ride's creator."
              ),
          })
          .describe('Ride group creation request')
      )
      .describe('Ride groups to create'),
    tagIds: zod
      .array(zod.string())
      .optional()
      .describe(
        "IDs (TSID) of the team's RIDE tags the ride carries, replacing the whole set — at most 10, each a tag of this team and of kind RIDE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update."
      ),
    templateId: zod
      .string()
      .optional()
      .describe(
        "ID (TSID) of the team's template the ride is created from. On a creation, raises the template's nextNumber by one when it has one; ignored on an update, and when the template no longer exists."
      ),
  })
  .describe('Ride request')

export const updateRideResponseMediaMarkdownMax = 100000

export const UpdateRideResponse = zod
  .object({
    type: zod.enum(['RIDE']),
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
        markdown: zod.string().max(updateRideResponseMediaMarkdownMax).describe('Markdown'),
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
    dateTime: zod.iso.datetime({ offset: true }).describe('Publication date/time'),
    timezone: zod
      .string()
      .describe(
        "IANA zone the ride's times were entered in and read in: its start place's, else its route's, else the team's. dateTime, publishAt, endDateTime and the groups' startAt are rendezvous in this zone."
      ),
    endDateTime: zod.iso
      .datetime({ offset: true })
      .describe(
        "When the ride is over, computed by the server: the latest of its groups, each one its departure plus its route's length at its average speed — or plus 3 hours when the group has no speed or no route, and for a ride with no group. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Publication status'),
    finished: zod
      .boolean()
      .describe(
        'Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished.'
      ),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    publishAt: zod.iso.datetime({ offset: true }).optional().describe('Publication timestamp'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Creation timestamp'),
    routeSlug: zod.string().optional().describe('Route slug'),
    participantCount: zod.int().describe('Number of participants'),
    groupCount: zod.int().describe('Number of groups'),
    groups: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod
              .string()
              .optional()
              .describe(
                "Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time."
              ),
            startAt: zod.iso
              .datetime({ offset: true })
              .describe(
                "When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own."
              ),
            routeSlug: zod.string().optional().describe('Route slug'),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            maxParticipants: zod.int().optional().describe('Maximum participants'),
            countParticipants: zod.int().describe('Current number of participants'),
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
                'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.'
              ),
            sortOrder: zod.int().describe('Sort order'),
            registered: zod
              .boolean()
              .describe(
                'Whether the current user is registered in THIS group. False if anonymous.'
              ),
            full: zod
              .boolean()
              .describe(
                'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
              ),
            distance: zod
              .number()
              .optional()
              .describe('Distance in meters of the group route, if it has one'),
            elevationGain: zod
              .number()
              .optional()
              .describe('Total elevation gain in meters of the group route, if it has one'),
            leader: zod
              .object({
                id: zod.string().describe('User ID (TSID)'),
                displayName: zod.string().describe('User display name'),
                avatarUrl: zod.string().optional().describe('User avatar URL'),
              })
              .optional()
              .describe(
                "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride."
              ),
            thumbnailLightUrl: zod
              .string()
              .optional()
              .describe(
                'Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
              ),
            thumbnailDarkUrl: zod
              .string()
              .optional()
              .describe(
                'Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
              ),
            thumbnailUrl: zod
              .string()
              .optional()
              .describe(
                "The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only."
              ),
          })
          .describe('Ride group information')
      )
      .describe('Ride groups'),
    groupSummaries: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod
              .string()
              .optional()
              .describe("Start time of the group, when it differs from the ride's"),
            startAt: zod.iso
              .datetime({ offset: true })
              .describe(
                'When the group leaves, as RideGroupDto.startAt. Replaces time, kept for the clients that still read it.'
              ),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            countParticipants: zod.int().describe('Current number of participants'),
            maxParticipants: zod
              .int()
              .optional()
              .describe('Maximum participants, null when the group is uncapped'),
            full: zod
              .boolean()
              .describe(
                'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
              ),
            routeSlug: zod.string().optional().describe('Slug of the group route, if it has one'),
            distance: zod
              .number()
              .optional()
              .describe('Distance in meters of the group route, if it has one'),
            elevationGain: zod
              .number()
              .optional()
              .describe('Total elevation gain in meters of the group route, if it has one'),
            sortOrder: zod.int().describe('Sort order'),
          })
          .describe(
            "One group of a ride, as a list row shows it: name, pace and fill. Same figures as the matching entry of the detail's groups, without the participants nor the leader."
          )
      )
      .describe(
        'Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.'
      ),
    distance: zod
      .number()
      .optional()
      .describe(
        "Distance in meters of the ride's route — or, when the ride itself has none, of the route of its first group (in sort order) that has one. Null when no route is set anywhere."
      ),
    elevationGain: zod
      .number()
      .optional()
      .describe(
        'Total elevation gain in meters, from the same route as distance. Null when no route is set anywhere.'
      ),
    surfaceType: zod
      .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
      .optional()
      .describe(
        'Surface type, from the same route as distance. Null when no route is set anywhere.'
      ),
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
            coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
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
            coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
          })
          .optional()
          .describe('Location coordinates [longitude, latitude]'),
      })
      .optional()
      .describe('End place'),
    topParticipants: zod
      .array(
        zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .describe('Public user information (limited fields)')
      )
      .describe('Preview of first participants (max 5)'),
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
    deleted: zod.boolean().describe('Whether the ride is soft-deleted'),
    registered: zod
      .boolean()
      .describe(
        "Whether the current user is registered in one of this ride's groups. False if anonymous."
      ),
    registeredGroupId: zod
      .string()
      .optional()
      .describe('ID (TSID) of the group the current user joined, null if not registered'),
    registeredGroup: zod
      .object({
        id: zod.string().describe('Group ID (TSID)'),
        name: zod.string().describe('Group name'),
        time: zod
          .string()
          .optional()
          .describe(
            "Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time."
          ),
        startAt: zod.iso
          .datetime({ offset: true })
          .describe(
            "When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own."
          ),
        routeSlug: zod.string().optional().describe('Route slug'),
        averageSpeed: zod.number().optional().describe('Average speed in km/h'),
        maxParticipants: zod.int().optional().describe('Maximum participants'),
        countParticipants: zod.int().describe('Current number of participants'),
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
            'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.'
          ),
        sortOrder: zod.int().describe('Sort order'),
        registered: zod
          .boolean()
          .describe('Whether the current user is registered in THIS group. False if anonymous.'),
        full: zod
          .boolean()
          .describe(
            'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
          ),
        distance: zod
          .number()
          .optional()
          .describe('Distance in meters of the group route, if it has one'),
        elevationGain: zod
          .number()
          .optional()
          .describe('Total elevation gain in meters of the group route, if it has one'),
        leader: zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .optional()
          .describe(
            "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride."
          ),
        thumbnailLightUrl: zod
          .string()
          .optional()
          .describe(
            'Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
          ),
        thumbnailDarkUrl: zod
          .string()
          .optional()
          .describe(
            'Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
          ),
        thumbnailUrl: zod
          .string()
          .optional()
          .describe(
            "The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only."
          ),
      })
      .optional()
      .describe(
        'The group the current user joined, in full — the same object as the matching entry of groups. Null if not registered or anonymous. Set on list rows too, where groups is empty: a client rendering "my next ride" needs no second request for its group. Its leader is the group\'s own, null when none was designated.'
      ),
    full: zod
      .boolean()
      .describe(
        'Whether every group of the ride has reached its capacity. False when the ride has no group, or when at least one group has no maxParticipants.'
      ),
    maxParticipants: zod
      .int()
      .optional()
      .describe(
        'Capacity of the whole ride: the sum of its groups\' maxParticipants, to render participantCount against it ("12/40"). Null when the ride has no group, or when at least one group has no maxParticipants — the ride then has no overall limit, and is never full. Set on list rows too, where groups is empty.'
      ),
    commentCount: zod
      .int()
      .optional()
      .describe(
        'Number of comments, replies included. Absent when the caller may not read the comments of this ride — comments are members-only, so an outsider is told nothing, not even zero.'
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
        "The team's RIDE tags the ride carries, sorted by label. Empty when it carries none."
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
        'The weather line of a card: the meeting point, over the window from the departure to the estimated arrival of the last group. Absent when there is nothing to show — finished or cancelled ride, no place, forecast not in cache yet; present only with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather.'
      ),
  })
  .describe('Ride summary data')

/**
 * Get detailed ride information including groups
 * @summary Get ride details
 */
export const GetRideParams = zod.object({
  rideSlug: zod.string().describe('Ride URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const getRideResponseMediaMarkdownMax = 100000

export const GetRideResponse = zod
  .object({
    type: zod.enum(['RIDE']),
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
        markdown: zod.string().max(getRideResponseMediaMarkdownMax).describe('Markdown'),
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
    dateTime: zod.iso.datetime({ offset: true }).describe('Publication date/time'),
    timezone: zod
      .string()
      .describe(
        "IANA zone the ride's times were entered in and read in: its start place's, else its route's, else the team's. dateTime, publishAt, endDateTime and the groups' startAt are rendezvous in this zone."
      ),
    endDateTime: zod.iso
      .datetime({ offset: true })
      .describe(
        "When the ride is over, computed by the server: the latest of its groups, each one its departure plus its route's length at its average speed — or plus 3 hours when the group has no speed or no route, and for a ride with no group. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Publication status'),
    finished: zod
      .boolean()
      .describe(
        'Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished.'
      ),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    publishAt: zod.iso.datetime({ offset: true }).optional().describe('Publication timestamp'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Creation timestamp'),
    routeSlug: zod.string().optional().describe('Route slug'),
    participantCount: zod.int().describe('Number of participants'),
    groupCount: zod.int().describe('Number of groups'),
    groups: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod
              .string()
              .optional()
              .describe(
                "Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time."
              ),
            startAt: zod.iso
              .datetime({ offset: true })
              .describe(
                "When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own."
              ),
            routeSlug: zod.string().optional().describe('Route slug'),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            maxParticipants: zod.int().optional().describe('Maximum participants'),
            countParticipants: zod.int().describe('Current number of participants'),
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
                'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.'
              ),
            sortOrder: zod.int().describe('Sort order'),
            registered: zod
              .boolean()
              .describe(
                'Whether the current user is registered in THIS group. False if anonymous.'
              ),
            full: zod
              .boolean()
              .describe(
                'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
              ),
            distance: zod
              .number()
              .optional()
              .describe('Distance in meters of the group route, if it has one'),
            elevationGain: zod
              .number()
              .optional()
              .describe('Total elevation gain in meters of the group route, if it has one'),
            leader: zod
              .object({
                id: zod.string().describe('User ID (TSID)'),
                displayName: zod.string().describe('User display name'),
                avatarUrl: zod.string().optional().describe('User avatar URL'),
              })
              .optional()
              .describe(
                "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride."
              ),
            thumbnailLightUrl: zod
              .string()
              .optional()
              .describe(
                'Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
              ),
            thumbnailDarkUrl: zod
              .string()
              .optional()
              .describe(
                'Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
              ),
            thumbnailUrl: zod
              .string()
              .optional()
              .describe(
                "The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only."
              ),
          })
          .describe('Ride group information')
      )
      .describe('Ride groups'),
    groupSummaries: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod
              .string()
              .optional()
              .describe("Start time of the group, when it differs from the ride's"),
            startAt: zod.iso
              .datetime({ offset: true })
              .describe(
                'When the group leaves, as RideGroupDto.startAt. Replaces time, kept for the clients that still read it.'
              ),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            countParticipants: zod.int().describe('Current number of participants'),
            maxParticipants: zod
              .int()
              .optional()
              .describe('Maximum participants, null when the group is uncapped'),
            full: zod
              .boolean()
              .describe(
                'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
              ),
            routeSlug: zod.string().optional().describe('Slug of the group route, if it has one'),
            distance: zod
              .number()
              .optional()
              .describe('Distance in meters of the group route, if it has one'),
            elevationGain: zod
              .number()
              .optional()
              .describe('Total elevation gain in meters of the group route, if it has one'),
            sortOrder: zod.int().describe('Sort order'),
          })
          .describe(
            "One group of a ride, as a list row shows it: name, pace and fill. Same figures as the matching entry of the detail's groups, without the participants nor the leader."
          )
      )
      .describe(
        'Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.'
      ),
    distance: zod
      .number()
      .optional()
      .describe(
        "Distance in meters of the ride's route — or, when the ride itself has none, of the route of its first group (in sort order) that has one. Null when no route is set anywhere."
      ),
    elevationGain: zod
      .number()
      .optional()
      .describe(
        'Total elevation gain in meters, from the same route as distance. Null when no route is set anywhere.'
      ),
    surfaceType: zod
      .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
      .optional()
      .describe(
        'Surface type, from the same route as distance. Null when no route is set anywhere.'
      ),
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
            coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
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
            coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
          })
          .optional()
          .describe('Location coordinates [longitude, latitude]'),
      })
      .optional()
      .describe('End place'),
    topParticipants: zod
      .array(
        zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .describe('Public user information (limited fields)')
      )
      .describe('Preview of first participants (max 5)'),
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
    deleted: zod.boolean().describe('Whether the ride is soft-deleted'),
    registered: zod
      .boolean()
      .describe(
        "Whether the current user is registered in one of this ride's groups. False if anonymous."
      ),
    registeredGroupId: zod
      .string()
      .optional()
      .describe('ID (TSID) of the group the current user joined, null if not registered'),
    registeredGroup: zod
      .object({
        id: zod.string().describe('Group ID (TSID)'),
        name: zod.string().describe('Group name'),
        time: zod
          .string()
          .optional()
          .describe(
            "Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time."
          ),
        startAt: zod.iso
          .datetime({ offset: true })
          .describe(
            "When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own."
          ),
        routeSlug: zod.string().optional().describe('Route slug'),
        averageSpeed: zod.number().optional().describe('Average speed in km/h'),
        maxParticipants: zod.int().optional().describe('Maximum participants'),
        countParticipants: zod.int().describe('Current number of participants'),
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
            'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.'
          ),
        sortOrder: zod.int().describe('Sort order'),
        registered: zod
          .boolean()
          .describe('Whether the current user is registered in THIS group. False if anonymous.'),
        full: zod
          .boolean()
          .describe(
            'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
          ),
        distance: zod
          .number()
          .optional()
          .describe('Distance in meters of the group route, if it has one'),
        elevationGain: zod
          .number()
          .optional()
          .describe('Total elevation gain in meters of the group route, if it has one'),
        leader: zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .optional()
          .describe(
            "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride."
          ),
        thumbnailLightUrl: zod
          .string()
          .optional()
          .describe(
            'Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
          ),
        thumbnailDarkUrl: zod
          .string()
          .optional()
          .describe(
            'Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
          ),
        thumbnailUrl: zod
          .string()
          .optional()
          .describe(
            "The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only."
          ),
      })
      .optional()
      .describe(
        'The group the current user joined, in full — the same object as the matching entry of groups. Null if not registered or anonymous. Set on list rows too, where groups is empty: a client rendering "my next ride" needs no second request for its group. Its leader is the group\'s own, null when none was designated.'
      ),
    full: zod
      .boolean()
      .describe(
        'Whether every group of the ride has reached its capacity. False when the ride has no group, or when at least one group has no maxParticipants.'
      ),
    maxParticipants: zod
      .int()
      .optional()
      .describe(
        'Capacity of the whole ride: the sum of its groups\' maxParticipants, to render participantCount against it ("12/40"). Null when the ride has no group, or when at least one group has no maxParticipants — the ride then has no overall limit, and is never full. Set on list rows too, where groups is empty.'
      ),
    commentCount: zod
      .int()
      .optional()
      .describe(
        'Number of comments, replies included. Absent when the caller may not read the comments of this ride — comments are members-only, so an outsider is told nothing, not even zero.'
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
        "The team's RIDE tags the ride carries, sorted by label. Empty when it carries none."
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
        'The weather line of a card: the meeting point, over the window from the departure to the estimated arrival of the last group. Absent when there is nothing to show — finished or cancelled ride, no place, forecast not in cache yet; present only with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather.'
      ),
  })
  .describe('Ride summary data')

/**
 * Soft delete a ride. Requires organizer permissions.
 * @summary Delete ride
 */
export const DeleteRideParams = zod.object({
  rideSlug: zod.string().describe('Ride URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const DeleteRideResponse = zod.void()

/**
 * Join a ride group
 * @summary Join ride group
 */
export const JoinGroupParams = zod.object({
  groupId: zod.string().describe('Group ID (TSID)'),
  rideSlug: zod.string().describe('Ride URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const JoinGroupResponse = zod
  .object({
    id: zod.string().describe('Participation ID (TSID)'),
    userId: zod.string().describe('User ID (TSID)'),
    registeredAt: zod.iso.datetime({ offset: true }).optional().describe('Registration timestamp'),
  })
  .describe('Ride participation information')

/**
 * Leave a ride group
 * @summary Leave ride group
 */
export const LeaveGroupParams = zod.object({
  groupId: zod.string().describe('Group ID (TSID)'),
  rideSlug: zod.string().describe('Ride URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const LeaveGroupResponse = zod.void()

/**
 * One VEVENT for the ride, to add it on its own to a calendar. Readable by whoever may read the ride; no calendar token.
 * @summary Download ride as a calendar file
 */
export const DownloadRideIcsParams = zod.object({
  rideSlug: zod.string().describe('Ride URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const DownloadRideIcsResponse = zod.unknown()

/**
 * One page of the people registered to the ride, or to one of its groups, earliest registrations first, searchable by display name. The ride detail only embeds the first few; this is the whole list, with its total. Readable by whoever may read the ride.
 * @summary List ride participants
 */
export const GetRideParticipantsParams = zod.object({
  rideSlug: zod.string().describe('Ride URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const getRideParticipantsQueryPageDefault = 0
export const getRideParticipantsQuerySizeDefault = 50

export const GetRideParticipantsQueryParams = zod.object({
  groupId: zod
    .string()
    .optional()
    .describe('Only this group of the ride (TSID); every group when absent'),
  page: zod.int().default(getRideParticipantsQueryPageDefault).describe('Page number (0-based)'),
  search: zod.string().optional().describe('Search by display name'),
  size: zod.int().default(getRideParticipantsQuerySizeDefault).describe('Page size'),
})

export const GetRideParticipantsResponse = zod
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
 * Change ride URL slug. Requires organizer permissions.
 * @summary Change ride slug
 */
export const ChangeRideSlugParams = zod.object({
  rideSlug: zod.string().describe('Current ride URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const changeRideSlugBodySlugMax = 200

export const changeRideSlugBodySlugRegExp = new RegExp('^[a-z0-9]+(-[a-z0-9]+)*$')

export const ChangeRideSlugBody = zod
  .object({
    slug: zod
      .string()
      .max(changeRideSlugBodySlugMax)
      .regex(changeRideSlugBodySlugRegExp)
      .describe('New slug (lowercase letters, numbers, and hyphens only)'),
  })
  .describe('Slug change request')

export const changeRideSlugResponseMediaMarkdownMax = 100000

export const ChangeRideSlugResponse = zod
  .object({
    type: zod.enum(['RIDE']),
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
        markdown: zod.string().max(changeRideSlugResponseMediaMarkdownMax).describe('Markdown'),
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
    dateTime: zod.iso.datetime({ offset: true }).describe('Publication date/time'),
    timezone: zod
      .string()
      .describe(
        "IANA zone the ride's times were entered in and read in: its start place's, else its route's, else the team's. dateTime, publishAt, endDateTime and the groups' startAt are rendezvous in this zone."
      ),
    endDateTime: zod.iso
      .datetime({ offset: true })
      .describe(
        "When the ride is over, computed by the server: the latest of its groups, each one its departure plus its route's length at its average speed — or plus 3 hours when the group has no speed or no route, and for a ride with no group. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Publication status'),
    finished: zod
      .boolean()
      .describe(
        'Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished.'
      ),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    publishAt: zod.iso.datetime({ offset: true }).optional().describe('Publication timestamp'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Creation timestamp'),
    routeSlug: zod.string().optional().describe('Route slug'),
    participantCount: zod.int().describe('Number of participants'),
    groupCount: zod.int().describe('Number of groups'),
    groups: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod
              .string()
              .optional()
              .describe(
                "Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time."
              ),
            startAt: zod.iso
              .datetime({ offset: true })
              .describe(
                "When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own."
              ),
            routeSlug: zod.string().optional().describe('Route slug'),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            maxParticipants: zod.int().optional().describe('Maximum participants'),
            countParticipants: zod.int().describe('Current number of participants'),
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
                'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.'
              ),
            sortOrder: zod.int().describe('Sort order'),
            registered: zod
              .boolean()
              .describe(
                'Whether the current user is registered in THIS group. False if anonymous.'
              ),
            full: zod
              .boolean()
              .describe(
                'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
              ),
            distance: zod
              .number()
              .optional()
              .describe('Distance in meters of the group route, if it has one'),
            elevationGain: zod
              .number()
              .optional()
              .describe('Total elevation gain in meters of the group route, if it has one'),
            leader: zod
              .object({
                id: zod.string().describe('User ID (TSID)'),
                displayName: zod.string().describe('User display name'),
                avatarUrl: zod.string().optional().describe('User avatar URL'),
              })
              .optional()
              .describe(
                "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride."
              ),
            thumbnailLightUrl: zod
              .string()
              .optional()
              .describe(
                'Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
              ),
            thumbnailDarkUrl: zod
              .string()
              .optional()
              .describe(
                'Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
              ),
            thumbnailUrl: zod
              .string()
              .optional()
              .describe(
                "The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only."
              ),
          })
          .describe('Ride group information')
      )
      .describe('Ride groups'),
    groupSummaries: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod
              .string()
              .optional()
              .describe("Start time of the group, when it differs from the ride's"),
            startAt: zod.iso
              .datetime({ offset: true })
              .describe(
                'When the group leaves, as RideGroupDto.startAt. Replaces time, kept for the clients that still read it.'
              ),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            countParticipants: zod.int().describe('Current number of participants'),
            maxParticipants: zod
              .int()
              .optional()
              .describe('Maximum participants, null when the group is uncapped'),
            full: zod
              .boolean()
              .describe(
                'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
              ),
            routeSlug: zod.string().optional().describe('Slug of the group route, if it has one'),
            distance: zod
              .number()
              .optional()
              .describe('Distance in meters of the group route, if it has one'),
            elevationGain: zod
              .number()
              .optional()
              .describe('Total elevation gain in meters of the group route, if it has one'),
            sortOrder: zod.int().describe('Sort order'),
          })
          .describe(
            "One group of a ride, as a list row shows it: name, pace and fill. Same figures as the matching entry of the detail's groups, without the participants nor the leader."
          )
      )
      .describe(
        'Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.'
      ),
    distance: zod
      .number()
      .optional()
      .describe(
        "Distance in meters of the ride's route — or, when the ride itself has none, of the route of its first group (in sort order) that has one. Null when no route is set anywhere."
      ),
    elevationGain: zod
      .number()
      .optional()
      .describe(
        'Total elevation gain in meters, from the same route as distance. Null when no route is set anywhere.'
      ),
    surfaceType: zod
      .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
      .optional()
      .describe(
        'Surface type, from the same route as distance. Null when no route is set anywhere.'
      ),
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
            coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
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
            coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
          })
          .optional()
          .describe('Location coordinates [longitude, latitude]'),
      })
      .optional()
      .describe('End place'),
    topParticipants: zod
      .array(
        zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .describe('Public user information (limited fields)')
      )
      .describe('Preview of first participants (max 5)'),
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
    deleted: zod.boolean().describe('Whether the ride is soft-deleted'),
    registered: zod
      .boolean()
      .describe(
        "Whether the current user is registered in one of this ride's groups. False if anonymous."
      ),
    registeredGroupId: zod
      .string()
      .optional()
      .describe('ID (TSID) of the group the current user joined, null if not registered'),
    registeredGroup: zod
      .object({
        id: zod.string().describe('Group ID (TSID)'),
        name: zod.string().describe('Group name'),
        time: zod
          .string()
          .optional()
          .describe(
            "Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time."
          ),
        startAt: zod.iso
          .datetime({ offset: true })
          .describe(
            "When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own."
          ),
        routeSlug: zod.string().optional().describe('Route slug'),
        averageSpeed: zod.number().optional().describe('Average speed in km/h'),
        maxParticipants: zod.int().optional().describe('Maximum participants'),
        countParticipants: zod.int().describe('Current number of participants'),
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
            'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.'
          ),
        sortOrder: zod.int().describe('Sort order'),
        registered: zod
          .boolean()
          .describe('Whether the current user is registered in THIS group. False if anonymous.'),
        full: zod
          .boolean()
          .describe(
            'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
          ),
        distance: zod
          .number()
          .optional()
          .describe('Distance in meters of the group route, if it has one'),
        elevationGain: zod
          .number()
          .optional()
          .describe('Total elevation gain in meters of the group route, if it has one'),
        leader: zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .optional()
          .describe(
            "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride."
          ),
        thumbnailLightUrl: zod
          .string()
          .optional()
          .describe(
            'Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
          ),
        thumbnailDarkUrl: zod
          .string()
          .optional()
          .describe(
            'Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
          ),
        thumbnailUrl: zod
          .string()
          .optional()
          .describe(
            "The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only."
          ),
      })
      .optional()
      .describe(
        'The group the current user joined, in full — the same object as the matching entry of groups. Null if not registered or anonymous. Set on list rows too, where groups is empty: a client rendering "my next ride" needs no second request for its group. Its leader is the group\'s own, null when none was designated.'
      ),
    full: zod
      .boolean()
      .describe(
        'Whether every group of the ride has reached its capacity. False when the ride has no group, or when at least one group has no maxParticipants.'
      ),
    maxParticipants: zod
      .int()
      .optional()
      .describe(
        'Capacity of the whole ride: the sum of its groups\' maxParticipants, to render participantCount against it ("12/40"). Null when the ride has no group, or when at least one group has no maxParticipants — the ride then has no overall limit, and is never full. Set on list rows too, where groups is empty.'
      ),
    commentCount: zod
      .int()
      .optional()
      .describe(
        'Number of comments, replies included. Absent when the caller may not read the comments of this ride — comments are members-only, so an outsider is told nothing, not even zero.'
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
        "The team's RIDE tags the ride carries, sorted by label. Empty when it carries none."
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
        'The weather line of a card: the meeting point, over the window from the departure to the estimated arrival of the last group. Absent when there is nothing to show — finished or cancelled ride, no place, forecast not in cache yet; present only with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather.'
      ),
  })
  .describe('Ride summary data')

/**
 * Change the ride's status and nothing else — what a list row can do without the full ride. Same side effects as a status change through the update. Requires organizer permissions.
 * @summary Change ride status
 */
export const ChangeRideStatusParams = zod.object({
  rideSlug: zod.string().describe('Ride URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const ChangeRideStatusBody = zod
  .object({
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('New status'),
  })
  .describe('Status change request')

export const changeRideStatusResponseMediaMarkdownMax = 100000

export const ChangeRideStatusResponse = zod
  .object({
    type: zod.enum(['RIDE']),
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
        markdown: zod.string().max(changeRideStatusResponseMediaMarkdownMax).describe('Markdown'),
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
    dateTime: zod.iso.datetime({ offset: true }).describe('Publication date/time'),
    timezone: zod
      .string()
      .describe(
        "IANA zone the ride's times were entered in and read in: its start place's, else its route's, else the team's. dateTime, publishAt, endDateTime and the groups' startAt are rendezvous in this zone."
      ),
    endDateTime: zod.iso
      .datetime({ offset: true })
      .describe(
        "When the ride is over, computed by the server: the latest of its groups, each one its departure plus its route's length at its average speed — or plus 3 hours when the group has no speed or no route, and for a ride with no group. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Publication status'),
    finished: zod
      .boolean()
      .describe(
        'Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished.'
      ),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    publishAt: zod.iso.datetime({ offset: true }).optional().describe('Publication timestamp'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Creation timestamp'),
    routeSlug: zod.string().optional().describe('Route slug'),
    participantCount: zod.int().describe('Number of participants'),
    groupCount: zod.int().describe('Number of groups'),
    groups: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod
              .string()
              .optional()
              .describe(
                "Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time."
              ),
            startAt: zod.iso
              .datetime({ offset: true })
              .describe(
                "When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own."
              ),
            routeSlug: zod.string().optional().describe('Route slug'),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            maxParticipants: zod.int().optional().describe('Maximum participants'),
            countParticipants: zod.int().describe('Current number of participants'),
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
                'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.'
              ),
            sortOrder: zod.int().describe('Sort order'),
            registered: zod
              .boolean()
              .describe(
                'Whether the current user is registered in THIS group. False if anonymous.'
              ),
            full: zod
              .boolean()
              .describe(
                'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
              ),
            distance: zod
              .number()
              .optional()
              .describe('Distance in meters of the group route, if it has one'),
            elevationGain: zod
              .number()
              .optional()
              .describe('Total elevation gain in meters of the group route, if it has one'),
            leader: zod
              .object({
                id: zod.string().describe('User ID (TSID)'),
                displayName: zod.string().describe('User display name'),
                avatarUrl: zod.string().optional().describe('User avatar URL'),
              })
              .optional()
              .describe(
                "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride."
              ),
            thumbnailLightUrl: zod
              .string()
              .optional()
              .describe(
                'Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
              ),
            thumbnailDarkUrl: zod
              .string()
              .optional()
              .describe(
                'Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
              ),
            thumbnailUrl: zod
              .string()
              .optional()
              .describe(
                "The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only."
              ),
          })
          .describe('Ride group information')
      )
      .describe('Ride groups'),
    groupSummaries: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod
              .string()
              .optional()
              .describe("Start time of the group, when it differs from the ride's"),
            startAt: zod.iso
              .datetime({ offset: true })
              .describe(
                'When the group leaves, as RideGroupDto.startAt. Replaces time, kept for the clients that still read it.'
              ),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            countParticipants: zod.int().describe('Current number of participants'),
            maxParticipants: zod
              .int()
              .optional()
              .describe('Maximum participants, null when the group is uncapped'),
            full: zod
              .boolean()
              .describe(
                'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
              ),
            routeSlug: zod.string().optional().describe('Slug of the group route, if it has one'),
            distance: zod
              .number()
              .optional()
              .describe('Distance in meters of the group route, if it has one'),
            elevationGain: zod
              .number()
              .optional()
              .describe('Total elevation gain in meters of the group route, if it has one'),
            sortOrder: zod.int().describe('Sort order'),
          })
          .describe(
            "One group of a ride, as a list row shows it: name, pace and fill. Same figures as the matching entry of the detail's groups, without the participants nor the leader."
          )
      )
      .describe(
        'Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.'
      ),
    distance: zod
      .number()
      .optional()
      .describe(
        "Distance in meters of the ride's route — or, when the ride itself has none, of the route of its first group (in sort order) that has one. Null when no route is set anywhere."
      ),
    elevationGain: zod
      .number()
      .optional()
      .describe(
        'Total elevation gain in meters, from the same route as distance. Null when no route is set anywhere.'
      ),
    surfaceType: zod
      .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
      .optional()
      .describe(
        'Surface type, from the same route as distance. Null when no route is set anywhere.'
      ),
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
            coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
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
            coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
          })
          .optional()
          .describe('Location coordinates [longitude, latitude]'),
      })
      .optional()
      .describe('End place'),
    topParticipants: zod
      .array(
        zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .describe('Public user information (limited fields)')
      )
      .describe('Preview of first participants (max 5)'),
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
    deleted: zod.boolean().describe('Whether the ride is soft-deleted'),
    registered: zod
      .boolean()
      .describe(
        "Whether the current user is registered in one of this ride's groups. False if anonymous."
      ),
    registeredGroupId: zod
      .string()
      .optional()
      .describe('ID (TSID) of the group the current user joined, null if not registered'),
    registeredGroup: zod
      .object({
        id: zod.string().describe('Group ID (TSID)'),
        name: zod.string().describe('Group name'),
        time: zod
          .string()
          .optional()
          .describe(
            "Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time."
          ),
        startAt: zod.iso
          .datetime({ offset: true })
          .describe(
            "When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own."
          ),
        routeSlug: zod.string().optional().describe('Route slug'),
        averageSpeed: zod.number().optional().describe('Average speed in km/h'),
        maxParticipants: zod.int().optional().describe('Maximum participants'),
        countParticipants: zod.int().describe('Current number of participants'),
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
            'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.'
          ),
        sortOrder: zod.int().describe('Sort order'),
        registered: zod
          .boolean()
          .describe('Whether the current user is registered in THIS group. False if anonymous.'),
        full: zod
          .boolean()
          .describe(
            'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
          ),
        distance: zod
          .number()
          .optional()
          .describe('Distance in meters of the group route, if it has one'),
        elevationGain: zod
          .number()
          .optional()
          .describe('Total elevation gain in meters of the group route, if it has one'),
        leader: zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .optional()
          .describe(
            "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride."
          ),
        thumbnailLightUrl: zod
          .string()
          .optional()
          .describe(
            'Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
          ),
        thumbnailDarkUrl: zod
          .string()
          .optional()
          .describe(
            'Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
          ),
        thumbnailUrl: zod
          .string()
          .optional()
          .describe(
            "The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only."
          ),
      })
      .optional()
      .describe(
        'The group the current user joined, in full — the same object as the matching entry of groups. Null if not registered or anonymous. Set on list rows too, where groups is empty: a client rendering "my next ride" needs no second request for its group. Its leader is the group\'s own, null when none was designated.'
      ),
    full: zod
      .boolean()
      .describe(
        'Whether every group of the ride has reached its capacity. False when the ride has no group, or when at least one group has no maxParticipants.'
      ),
    maxParticipants: zod
      .int()
      .optional()
      .describe(
        'Capacity of the whole ride: the sum of its groups\' maxParticipants, to render participantCount against it ("12/40"). Null when the ride has no group, or when at least one group has no maxParticipants — the ride then has no overall limit, and is never full. Set on list rows too, where groups is empty.'
      ),
    commentCount: zod
      .int()
      .optional()
      .describe(
        'Number of comments, replies included. Absent when the caller may not read the comments of this ride — comments are members-only, so an outsider is told nothing, not even zero.'
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
        "The team's RIDE tags the ride carries, sorted by label. Empty when it carries none."
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
        'The weather line of a card: the meeting point, over the window from the departure to the estimated arrival of the last group. Absent when there is nothing to show — finished or cancelled ride, no place, forecast not in cache yet; present only with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather.'
      ),
  })
  .describe('Ride summary data')

/**
 * Restore a soft-deleted ride. Requires organizer permissions.
 * @summary Restore ride
 */
export const UndeleteRideParams = zod.object({
  rideSlug: zod.string().describe('Ride URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const undeleteRideResponseMediaMarkdownMax = 100000

export const UndeleteRideResponse = zod
  .object({
    type: zod.enum(['RIDE']),
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
        markdown: zod.string().max(undeleteRideResponseMediaMarkdownMax).describe('Markdown'),
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
    dateTime: zod.iso.datetime({ offset: true }).describe('Publication date/time'),
    timezone: zod
      .string()
      .describe(
        "IANA zone the ride's times were entered in and read in: its start place's, else its route's, else the team's. dateTime, publishAt, endDateTime and the groups' startAt are rendezvous in this zone."
      ),
    endDateTime: zod.iso
      .datetime({ offset: true })
      .describe(
        "When the ride is over, computed by the server: the latest of its groups, each one its departure plus its route's length at its average speed — or plus 3 hours when the group has no speed or no route, and for a ride with no group. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read."
      ),
    status: zod.enum(['DRAFT', 'PUBLISHED', 'CANCELLED']).describe('Publication status'),
    finished: zod
      .boolean()
      .describe(
        'Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished.'
      ),
    visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).describe('Visibility level'),
    publishAt: zod.iso.datetime({ offset: true }).optional().describe('Publication timestamp'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Creation timestamp'),
    routeSlug: zod.string().optional().describe('Route slug'),
    participantCount: zod.int().describe('Number of participants'),
    groupCount: zod.int().describe('Number of groups'),
    groups: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod
              .string()
              .optional()
              .describe(
                "Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time."
              ),
            startAt: zod.iso
              .datetime({ offset: true })
              .describe(
                "When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own."
              ),
            routeSlug: zod.string().optional().describe('Route slug'),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            maxParticipants: zod.int().optional().describe('Maximum participants'),
            countParticipants: zod.int().describe('Current number of participants'),
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
                'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.'
              ),
            sortOrder: zod.int().describe('Sort order'),
            registered: zod
              .boolean()
              .describe(
                'Whether the current user is registered in THIS group. False if anonymous.'
              ),
            full: zod
              .boolean()
              .describe(
                'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
              ),
            distance: zod
              .number()
              .optional()
              .describe('Distance in meters of the group route, if it has one'),
            elevationGain: zod
              .number()
              .optional()
              .describe('Total elevation gain in meters of the group route, if it has one'),
            leader: zod
              .object({
                id: zod.string().describe('User ID (TSID)'),
                displayName: zod.string().describe('User display name'),
                avatarUrl: zod.string().optional().describe('User avatar URL'),
              })
              .optional()
              .describe(
                "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride."
              ),
            thumbnailLightUrl: zod
              .string()
              .optional()
              .describe(
                'Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
              ),
            thumbnailDarkUrl: zod
              .string()
              .optional()
              .describe(
                'Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
              ),
            thumbnailUrl: zod
              .string()
              .optional()
              .describe(
                "The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only."
              ),
          })
          .describe('Ride group information')
      )
      .describe('Ride groups'),
    groupSummaries: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Group ID (TSID)'),
            name: zod.string().describe('Group name'),
            time: zod
              .string()
              .optional()
              .describe("Start time of the group, when it differs from the ride's"),
            startAt: zod.iso
              .datetime({ offset: true })
              .describe(
                'When the group leaves, as RideGroupDto.startAt. Replaces time, kept for the clients that still read it.'
              ),
            averageSpeed: zod.number().optional().describe('Average speed in km/h'),
            countParticipants: zod.int().describe('Current number of participants'),
            maxParticipants: zod
              .int()
              .optional()
              .describe('Maximum participants, null when the group is uncapped'),
            full: zod
              .boolean()
              .describe(
                'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
              ),
            routeSlug: zod.string().optional().describe('Slug of the group route, if it has one'),
            distance: zod
              .number()
              .optional()
              .describe('Distance in meters of the group route, if it has one'),
            elevationGain: zod
              .number()
              .optional()
              .describe('Total elevation gain in meters of the group route, if it has one'),
            sortOrder: zod.int().describe('Sort order'),
          })
          .describe(
            "One group of a ride, as a list row shows it: name, pace and fill. Same figures as the matching entry of the detail's groups, without the participants nor the leader."
          )
      )
      .describe(
        'Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.'
      ),
    distance: zod
      .number()
      .optional()
      .describe(
        "Distance in meters of the ride's route — or, when the ride itself has none, of the route of its first group (in sort order) that has one. Null when no route is set anywhere."
      ),
    elevationGain: zod
      .number()
      .optional()
      .describe(
        'Total elevation gain in meters, from the same route as distance. Null when no route is set anywhere.'
      ),
    surfaceType: zod
      .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
      .optional()
      .describe(
        'Surface type, from the same route as distance. Null when no route is set anywhere.'
      ),
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
            coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
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
            coordinates: zod.array(zod.number()).describe('Coordinates [longitude, latitude]'),
          })
          .optional()
          .describe('Location coordinates [longitude, latitude]'),
      })
      .optional()
      .describe('End place'),
    topParticipants: zod
      .array(
        zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .describe('Public user information (limited fields)')
      )
      .describe('Preview of first participants (max 5)'),
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
    deleted: zod.boolean().describe('Whether the ride is soft-deleted'),
    registered: zod
      .boolean()
      .describe(
        "Whether the current user is registered in one of this ride's groups. False if anonymous."
      ),
    registeredGroupId: zod
      .string()
      .optional()
      .describe('ID (TSID) of the group the current user joined, null if not registered'),
    registeredGroup: zod
      .object({
        id: zod.string().describe('Group ID (TSID)'),
        name: zod.string().describe('Group name'),
        time: zod
          .string()
          .optional()
          .describe(
            "Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time."
          ),
        startAt: zod.iso
          .datetime({ offset: true })
          .describe(
            "When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own."
          ),
        routeSlug: zod.string().optional().describe('Route slug'),
        averageSpeed: zod.number().optional().describe('Average speed in km/h'),
        maxParticipants: zod.int().optional().describe('Maximum participants'),
        countParticipants: zod.int().describe('Current number of participants'),
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
            'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.'
          ),
        sortOrder: zod.int().describe('Sort order'),
        registered: zod
          .boolean()
          .describe('Whether the current user is registered in THIS group. False if anonymous.'),
        full: zod
          .boolean()
          .describe(
            'Whether the group has reached maxParticipants. False when maxParticipants is not set.'
          ),
        distance: zod
          .number()
          .optional()
          .describe('Distance in meters of the group route, if it has one'),
        elevationGain: zod
          .number()
          .optional()
          .describe('Total elevation gain in meters of the group route, if it has one'),
        leader: zod
          .object({
            id: zod.string().describe('User ID (TSID)'),
            displayName: zod.string().describe('User display name'),
            avatarUrl: zod.string().optional().describe('User avatar URL'),
          })
          .optional()
          .describe(
            "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride."
          ),
        thumbnailLightUrl: zod
          .string()
          .optional()
          .describe(
            'Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
          ),
        thumbnailDarkUrl: zod
          .string()
          .optional()
          .describe(
            'Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.'
          ),
        thumbnailUrl: zod
          .string()
          .optional()
          .describe(
            "The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only."
          ),
      })
      .optional()
      .describe(
        'The group the current user joined, in full — the same object as the matching entry of groups. Null if not registered or anonymous. Set on list rows too, where groups is empty: a client rendering "my next ride" needs no second request for its group. Its leader is the group\'s own, null when none was designated.'
      ),
    full: zod
      .boolean()
      .describe(
        'Whether every group of the ride has reached its capacity. False when the ride has no group, or when at least one group has no maxParticipants.'
      ),
    maxParticipants: zod
      .int()
      .optional()
      .describe(
        'Capacity of the whole ride: the sum of its groups\' maxParticipants, to render participantCount against it ("12/40"). Null when the ride has no group, or when at least one group has no maxParticipants — the ride then has no overall limit, and is never full. Set on list rows too, where groups is empty.'
      ),
    commentCount: zod
      .int()
      .optional()
      .describe(
        'Number of comments, replies included. Absent when the caller may not read the comments of this ride — comments are members-only, so an outsider is told nothing, not even zero.'
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
        "The team's RIDE tags the ride carries, sorted by label. Empty when it carries none."
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
        'The weather line of a card: the meeting point, over the window from the departure to the estimated arrival of the last group. Absent when there is nothing to show — finished or cancelled ride, no place, forecast not in cache yet; present only with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather.'
      ),
  })
  .describe('Ride summary data')

/**
 * The forecast for the ride: at the meeting point when it leaves, then along each group's route at its estimated passages (group speed, else 25 km/h). Read from the server's cache only — the forecast is refreshed in the background, never on request. Readable by whoever may read the ride, and then always 200: the state is in status. Cache-Control: private, no-cache with an ETag (revalidate with If-None-Match, 304 when unchanged); no-store when status is UNAVAILABLE.
 * @summary Get ride weather
 */
export const GetRideWeatherParams = zod.object({
  rideSlug: zod.string().describe('Ride URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const GetRideWeatherResponse = zod
  .object({
    status: zod
      .enum(['OK', 'STALE', 'NOT_YET_AVAILABLE', 'UNAVAILABLE', 'NO_LOCATION', 'OUT_OF_RANGE'])
      .describe(
        'Overall state. OK and STALE (shown, flagged as old) carry the forecast; NOT_YET_AVAILABLE comes with availableFrom; UNAVAILABLE (nothing in cache yet, or the provider failing) offers to retry; NO_LOCATION is worth a word to the organisers only; OUT_OF_RANGE (finished, cancelled) shows nothing.'
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
      .describe('The meeting point at departure'),
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
                    index: zod.int().describe('Position of the point on the leg, 0 for the start'),
                    kind: zod
                      .enum(['START', 'EN_ROUTE', 'FINISH'])
                      .describe('Where the point stands on the leg'),
                    distance: zod
                      .number()
                      .describe("Distance from the start of the leg's route, metres"),
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
                      .describe('Start of the stretch, metres from the start of the leg'),
                    toDistance: zod
                      .number()
                      .describe('End of the stretch, metres from the start of the leg'),
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
