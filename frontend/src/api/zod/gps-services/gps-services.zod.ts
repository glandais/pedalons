import * as zod from 'zod'

/**
 * Get list of GPS service types configured for this domain
 * @summary Get available GPS services
 */
export const GetAvailableServicesResponseItem = zod.enum(['HAMMERHEAD', 'GARMIN', 'WAHOO'])
export const GetAvailableServicesResponse = zod.array(GetAvailableServicesResponseItem)

/**
 * Handles OAuth callback from GPS service and redirects to the frontend page chosen by the returnTo of the connect call (the profile by default). OAuth 2.0 brings code and state; OAuth 1.0a (Garmin, when the domain's credential says so) brings oauth_token and oauth_verifier.
 * @summary OAuth callback
 */
export const HandleCallbackParams = zod.object({
  serviceType: zod.enum(['HAMMERHEAD', 'GARMIN', 'WAHOO']).describe('GPS service type'),
})

export const HandleCallbackQueryParams = zod.object({
  code: zod.string().optional(),
  error: zod.string().optional(),
  oauth_token: zod.string().optional().describe('OAuth 1.0a request token'),
  oauth_verifier: zod.string().optional().describe('OAuth 1.0a verifier'),
  state: zod.string().optional(),
})

export const HandleCallbackResponse = zod.void()

/**
 * Get the OAuth authorization URL to connect a GPS service
 * @summary Get OAuth authorization URL
 */
export const GetConnectUrlParams = zod.object({
  serviceType: zod.enum(['HAMMERHEAD', 'GARMIN', 'WAHOO']).describe('GPS service type'),
})

export const GetConnectUrlQueryParams = zod.object({
  returnTo: zod
    .enum(['PROFILE', 'DEVICE_KAROO'])
    .optional()
    .describe('Where the OAuth callback sends the browser back to. PROFILE when absent.'),
})

export const GetConnectUrlResponse = zod
  .object({
    authorizationUrl: zod.string().describe('URL to redirect user for OAuth authorization'),
  })
  .describe('OAuth authorization URL response')

/**
 * Turns on or off, for one connected service, the automatic sending of the routes of the rides the user is registered in (from 7 days before the departure until a day after it), kept in sync with their changes. Turning it off removes from the service the upcoming routes it sent. A RECONNECT_REQUIRED state is only cleared by connecting the service again.
 * @summary Turn the automatic route sync on or off
 */
export const SetGpsAutoSyncParams = zod.object({
  serviceType: zod.enum(['HAMMERHEAD', 'GARMIN', 'WAHOO']).describe('GPS service type'),
})

export const SetGpsAutoSyncBody = zod
  .object({
    enabled: zod
      .boolean()
      .describe(
        "true to send the routes of the user's upcoming rides to this service automatically; false to stop, which also removes from the service the upcoming routes the sync sent"
      ),
  })
  .describe('Turns the automatic route sync of one GPS service on or off')

export const SetGpsAutoSyncResponse = zod
  .object({
    serviceType: zod.enum(['HAMMERHEAD', 'GARMIN', 'WAHOO']).describe('Service type identifier'),
    displayName: zod.string().describe('Display name of the service'),
    connectedAt: zod.iso.datetime({ offset: true }).describe('When the service was connected'),
    autoSync: zod
      .boolean()
      .describe(
        'Whether the routes of the rides the user is registered in are sent to this service automatically, and kept in sync (new route, corrected GPX, another group), from 7 days before the departure until a day after it'
      ),
    autoSyncState: zod
      .enum(['OFF', 'UP_TO_DATE', 'PENDING', 'FAILING', 'RECONNECT_REQUIRED'])
      .describe(
        'Where the automatic sync stands. OFF when autoSync is false; RECONNECT_REQUIRED is only cleared by connecting the service again'
      ),
    autoSyncRouteCount: zod
      .int()
      .describe(
        'How many routes the automatic sync currently has at the service (removed after the ride, or when the sync is turned off)'
      ),
    lastAutoSyncAt: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe('When the automatic sync last sent a route to this service'),
  })
  .describe('GPS service connection information')

/**
 * Disconnect a connected GPS service
 * @summary Disconnect GPS service
 */
export const DisconnectParams = zod.object({
  serviceType: zod.enum(['HAMMERHEAD', 'GARMIN', 'WAHOO']).describe('GPS service type'),
})

export const DisconnectResponse = zod.void()

/**
 * Upload a route to a connected GPS service
 * @summary Upload route to GPS service
 */
export const UploadRouteParams = zod.object({
  routeSlug: zod.string().describe('Route URL slug'),
  serviceType: zod.enum(['HAMMERHEAD', 'GARMIN', 'WAHOO']).describe('GPS service type'),
  teamSlug: zod.string().describe('Team URL slug'),
})

export const UploadRouteResponse = zod
  .object({
    success: zod.boolean().describe('Whether the upload was successful'),
    message: zod.string().optional().describe('Error message if upload failed'),
    externalRouteId: zod.string().optional().describe('External route ID on the GPS service'),
  })
  .describe('Result of uploading a route to a GPS service')
