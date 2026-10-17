import * as zod from 'zod'

/**
 * Get calendar events for all teams the user belongs to
 * @summary Get calendar events
 */
export const GetEventsQueryParams = zod.object({
  from: zod.string().optional().describe('Start date (ISO 8601)'),
  to: zod.string().optional().describe('End date (ISO 8601)'),
})

export const GetEventsResponse = zod
  .object({
    events: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Event ID (TSID)'),
            title: zod.string().describe('Event title'),
            start: zod.iso.datetime({ offset: true }).describe('Event start date/time'),
            end: zod.iso
              .datetime({ offset: true })
              .optional()
              .describe(
                'Event end date/time: the end the server computes for a ride (its latest group at its pace, 3 hours when nothing tells) or for a trip stage (its route at its pace, likewise) — the same as RideDto.endDateTime. On an all-day stage it is still that instant: the stage occupies every day up to it.'
              ),
            allDay: zod.boolean().describe('Is all-day event'),
            type: zod.enum(['RIDE', 'TRIP_STAGE']).describe('Event type'),
            teamSlug: zod.string().describe('Team slug'),
            teamName: zod.string().describe('Team name'),
            entitySlug: zod.string().describe('Entity slug (ride or stage)'),
            tripSlug: zod.string().optional().describe('Parent trip slug (for stages only)'),
            startPlaceName: zod
              .string()
              .optional()
              .describe(
                'Name of the meeting place, null when the ride or stage has no start place'
              ),
            distance: zod
              .number()
              .optional()
              .describe('Distance in meters of the attached route, null when there is no route'),
            elevationGain: zod
              .number()
              .optional()
              .describe(
                'Total elevation gain in meters of the attached route, null when there is no route'
              ),
            thumbnailUrl: zod
              .string()
              .optional()
              .describe(
                "Thumbnail image URL template (contains a {size} placeholder), light variant preferred. Falls back to the route's thumbnail when the ride or stage has none of its own. For a client that renders one picture and does not follow a colour scheme; prefer thumbnailLightUrl/thumbnailDarkUrl otherwise. Opaque URL: may carry a query string; substitute {size} only."
              ),
            thumbnailLightUrl: zod
              .string()
              .optional()
              .describe(
                "Light-scheme thumbnail image URL template (contains a {size} placeholder). Null when the event's picture exists only in a dark variant. Opaque URL: may carry a query string; substitute {size} only."
              ),
            thumbnailDarkUrl: zod
              .string()
              .optional()
              .describe(
                "Dark-scheme thumbnail image URL template (contains a {size} placeholder). Null when the event's picture exists only in a light variant. Opaque URL: may carry a query string; substitute {size} only."
              ),
            registered: zod
              .boolean()
              .describe(
                'Whether the current user is registered to this ride, or to the trip this stage belongs to. False for an anonymous caller.'
              ),
            groupName: zod
              .string()
              .optional()
              .describe(
                'Name of the ride group the current user joined. Null when not registered, and always null for trip stages, which have no groups.'
              ),
            status: zod
              .enum(['DRAFT', 'PUBLISHED', 'CANCELLED'])
              .describe('Publication status of the ride or stage'),
            timezone: zod
              .string()
              .describe(
                "IANA zone of the ride or stage, as RideDto.timezone / TripStageDto.timezone: start and end are rendezvous in it. The calendar grid itself stays in the reader's zone."
              ),
            finished: zod
              .boolean()
              .describe(
                'Whether the ride or stage is over, computed by the server when the response is built: its end (or its start, when it has no end) has passed. Independent of status.'
              ),
          })
          .describe('Calendar event data')
      )
      .describe('List of calendar events'),
  })
  .describe('Calendar events response')

/**
 * Get ICS calendar feed for all user's teams (requires token)
 * @summary Get global ICS feed
 */
export const GetGlobalIcsFeedQueryParams = zod.object({
  token: zod.string().optional().describe('Calendar access token'),
})

export const GetGlobalIcsFeedResponse = zod.unknown()

/**
 * Get or create the user's calendar token for ICS feed access
 * @summary Get calendar token
 */
export const GetTokenResponse = zod
  .object({
    token: zod.string().describe('ICS feed token (include in URL)'),
    globalFeedUrl: zod.string().describe('Global ICS feed URL'),
    teamFeedUrlTemplate: zod.string().describe('Team-specific feed URL template'),
  })
  .describe('Calendar token information')

/**
 * Regenerate the user's calendar token, invalidating the old one
 * @summary Regenerate calendar token
 */
export const RegenerateTokenResponse = zod
  .object({
    token: zod.string().describe('ICS feed token (include in URL)'),
    globalFeedUrl: zod.string().describe('Global ICS feed URL'),
    teamFeedUrlTemplate: zod.string().describe('Team-specific feed URL template'),
  })
  .describe('Calendar token information')

/**
 * Get calendar events for a specific team
 * @summary Get team calendar events
 */
export const GetTeamEventsParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const GetTeamEventsQueryParams = zod.object({
  from: zod.string().optional().describe('Start date (ISO 8601)'),
  to: zod.string().optional().describe('End date (ISO 8601)'),
})

export const GetTeamEventsResponse = zod
  .object({
    events: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Event ID (TSID)'),
            title: zod.string().describe('Event title'),
            start: zod.iso.datetime({ offset: true }).describe('Event start date/time'),
            end: zod.iso
              .datetime({ offset: true })
              .optional()
              .describe(
                'Event end date/time: the end the server computes for a ride (its latest group at its pace, 3 hours when nothing tells) or for a trip stage (its route at its pace, likewise) — the same as RideDto.endDateTime. On an all-day stage it is still that instant: the stage occupies every day up to it.'
              ),
            allDay: zod.boolean().describe('Is all-day event'),
            type: zod.enum(['RIDE', 'TRIP_STAGE']).describe('Event type'),
            teamSlug: zod.string().describe('Team slug'),
            teamName: zod.string().describe('Team name'),
            entitySlug: zod.string().describe('Entity slug (ride or stage)'),
            tripSlug: zod.string().optional().describe('Parent trip slug (for stages only)'),
            startPlaceName: zod
              .string()
              .optional()
              .describe(
                'Name of the meeting place, null when the ride or stage has no start place'
              ),
            distance: zod
              .number()
              .optional()
              .describe('Distance in meters of the attached route, null when there is no route'),
            elevationGain: zod
              .number()
              .optional()
              .describe(
                'Total elevation gain in meters of the attached route, null when there is no route'
              ),
            thumbnailUrl: zod
              .string()
              .optional()
              .describe(
                "Thumbnail image URL template (contains a {size} placeholder), light variant preferred. Falls back to the route's thumbnail when the ride or stage has none of its own. For a client that renders one picture and does not follow a colour scheme; prefer thumbnailLightUrl/thumbnailDarkUrl otherwise. Opaque URL: may carry a query string; substitute {size} only."
              ),
            thumbnailLightUrl: zod
              .string()
              .optional()
              .describe(
                "Light-scheme thumbnail image URL template (contains a {size} placeholder). Null when the event's picture exists only in a dark variant. Opaque URL: may carry a query string; substitute {size} only."
              ),
            thumbnailDarkUrl: zod
              .string()
              .optional()
              .describe(
                "Dark-scheme thumbnail image URL template (contains a {size} placeholder). Null when the event's picture exists only in a light variant. Opaque URL: may carry a query string; substitute {size} only."
              ),
            registered: zod
              .boolean()
              .describe(
                'Whether the current user is registered to this ride, or to the trip this stage belongs to. False for an anonymous caller.'
              ),
            groupName: zod
              .string()
              .optional()
              .describe(
                'Name of the ride group the current user joined. Null when not registered, and always null for trip stages, which have no groups.'
              ),
            status: zod
              .enum(['DRAFT', 'PUBLISHED', 'CANCELLED'])
              .describe('Publication status of the ride or stage'),
            timezone: zod
              .string()
              .describe(
                "IANA zone of the ride or stage, as RideDto.timezone / TripStageDto.timezone: start and end are rendezvous in it. The calendar grid itself stays in the reader's zone."
              ),
            finished: zod
              .boolean()
              .describe(
                'Whether the ride or stage is over, computed by the server when the response is built: its end (or its start, when it has no end) has passed. Independent of status.'
              ),
          })
          .describe('Calendar event data')
      )
      .describe('List of calendar events'),
  })
  .describe('Calendar events response')

/**
 * Get ICS calendar feed for a specific team (requires token)
 * @summary Get team ICS feed
 */
export const GetTeamIcsFeedParams = zod.object({
  teamSlug: zod.string().describe('Team URL slug'),
})

export const GetTeamIcsFeedQueryParams = zod.object({
  token: zod.string().optional().describe('Calendar access token'),
})

export const GetTeamIcsFeedResponse = zod.unknown()
