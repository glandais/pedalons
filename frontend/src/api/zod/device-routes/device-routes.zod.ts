import * as zod from 'zod'

/**
 * Get routes for authenticated user. Prioritizes routes from upcoming rides, then latest routes from user's teams.
 * @summary List routes for user
 */
export const DeviceListRoutesQueryParams = zod.object({
  lat: zod.number().optional().describe("User's current latitude (for proximity sorting)"),
  lon: zod.number().optional().describe("User's current longitude (for proximity sorting)"),
})

export const DeviceListRoutesResponse = zod
  .object({
    rides: zod
      .array(
        zod
          .object({
            teamSlug: zod.string().describe('Team slug'),
            rideSlug: zod.string().describe('Ride slug'),
            rideName: zod.string().describe('Ride name'),
            startDateTime: zod.iso
              .datetime({ offset: true })
              .optional()
              .describe('Start date/time'),
            timezone: zod
              .string()
              .describe(
                'IANA zone of the ride, as RideDto.timezone; devices may ignore it and render in their own zone'
              ),
            entries: zod
              .array(
                zod
                  .object({
                    routeSlug: zod.string().describe('Route slug'),
                    routeName: zod.string().describe('Route name'),
                    groupName: zod
                      .string()
                      .optional()
                      .describe('Group name (null for ride-level route)'),
                    distance: zod.number().describe('Distance in meters'),
                    elevationGain: zod.number().describe('Elevation gain in meters'),
                    startLat: zod.number().optional().describe('Start latitude'),
                    startLon: zod.number().optional().describe('Start longitude'),
                    startDateTime: zod.iso
                      .datetime({ offset: true })
                      .describe(
                        "When this entry leaves, as an absolute instant (UTC): the group's startAt (its time on the ride's local date, in the ride's zone); the ride's own startDateTime for the ride-level route and for a group without a time. Devices render it in their own zone."
                      ),
                  })
                  .describe('Route entry within a ride for device applications')
              )
              .describe('Route entries for this ride'),
          })
          .describe('Ride information for device applications')
      )
      .describe('Upcoming rides with route entries'),
    routes: zod
      .array(
        zod
          .object({
            teamSlug: zod.string().describe('Team slug'),
            routeSlug: zod.string().describe('Route slug'),
            routeName: zod.string().describe('Route name'),
            distance: zod.number().describe('Distance in meters'),
            elevationGain: zod.number().describe('Elevation gain in meters'),
            startLat: zod.number().optional().describe('Start latitude'),
            startLon: zod.number().optional().describe('Start longitude'),
          })
          .describe('Standalone route information for device applications')
      )
      .describe('Latest standalone routes'),
    registeredGroups: zod
      .array(
        zod
          .object({
            teamSlug: zod.string().describe('Team slug'),
            rideSlug: zod.string().describe('Ride slug'),
            rideName: zod.string().describe('Ride name'),
            groupName: zod.string().describe('Name of the group the user is registered in'),
            routeSlug: zod
              .string()
              .describe(
                "Slug of the route to load: the group's own route, or the ride's when the group has none"
              ),
            routeName: zod.string().describe('Route name'),
            distance: zod.number().describe('Distance in meters'),
            elevationGain: zod.number().describe('Elevation gain in meters'),
            startDateTime: zod.iso
              .datetime({ offset: true })
              .describe(
                "When the group leaves, as an absolute instant (UTC): the group's startAt, the ride's own start when the group has no time. Devices render it in their own zone."
              ),
            timezone: zod.string().describe('IANA time zone of the ride (e.g. Europe/Paris)'),
            syncStatuses: zod
              .array(
                zod
                  .object({
                    serviceType: zod
                      .enum(['HAMMERHEAD', 'GARMIN', 'WAHOO'])
                      .describe('GPS service'),
                    state: zod
                      .enum(['SENT', 'OUTDATED', 'PENDING', 'FAILING', 'RECONNECT_REQUIRED'])
                      .describe(
                        'SENT: at the service, up to date; OUTDATED: at the service in an older version that nothing will update, send it again; PENDING: to be sent or updated shortly; FAILING: the last attempt failed (a few retries, then it waits for the route to change); RECONNECT_REQUIRED: the connection must be renewed'
                      ),
                  })
                  .describe("Where the route stands at one of the user's GPS services")
              )
              .optional()
              .describe(
                "Where the route stands at each of the user's GPS services that hold it (sent automatically or uploaded by hand), so a device does not upload it again. Empty when no service holds it; a device only reads its own service's entry (Karoo: HAMMERHEAD, Garmin: GARMIN)."
              ),
          })
          .describe(
            'Upcoming ride group the user is registered in, with the route to load on the device'
          )
      )
      .describe(
        'Upcoming ride groups the user is registered in (from 12 hours ago to 7 days ahead), earliest first, each with the route to load'
      ),
  })
  .describe('Response containing rides and routes for device applications')

/**
 * Download route as FIT file for GPS devices
 * @summary Download FIT file
 */
export const DeviceDownloadFitParams = zod.object({
  routeSlug: zod.string().describe('Route URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const DeviceDownloadFitResponse = zod.unknown()

/**
 * Download route as GPX file for GPS devices
 * @summary Download GPX file
 */
export const DeviceDownloadGpxParams = zod.object({
  routeSlug: zod.string().describe('Route URL slug'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const DeviceDownloadGpxResponse = zod.unknown()

/**
 * Upload route to a cloud GPS service (e.g., Hammerhead, Garmin Connect, Wahoo)
 * @summary Sync route to cloud service
 */
export const DeviceSyncRouteParams = zod.object({
  routeSlug: zod.string().describe('Route slug'),
  teamSlug: zod.string().describe('Team slug'),
})

export const DeviceSyncRouteQueryParams = zod.object({
  type: zod.string().describe('GPS service type (hammerhead, garmin, wahoo)'),
})

export const DeviceSyncRouteResponse = zod
  .object({
    success: zod.boolean().describe('Whether the upload was successful'),
    message: zod.string().optional().describe('Error message if upload failed'),
    externalRouteId: zod.string().optional().describe('External route ID on the GPS service'),
  })
  .describe('Result of uploading a route to a GPS service')
