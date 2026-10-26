import * as zod from 'zod'

/**
 * Download a prepared data export archive using the token from the notification email. Only its owner, signed in, may download it. The token is a query parameter, which the access log masks; a path segment would be logged in clear.
 * @summary Download a personal data export
 */
export const DownloadDataExportQueryParams = zod.object({
  token: zod.string().describe('Download token from the notification email'),
})

export const DownloadDataExportResponse = zod.unknown()

/**
 * Update the current user's profile
 * @summary Update current user
 */
export const updateMeBodyDisplayNameMax = 200

export const UpdateMeBody = zod
  .object({
    displayName: zod
      .string()
      .min(1)
      .max(updateMeBodyDisplayNameMax)
      .optional()
      .describe('User display name'),
    unitSystem: zod.enum(['METRIC', 'IMPERIAL']).optional().describe('Preferred unit system'),
  })
  .describe('User profile update request')

export const UpdateMeResponse = zod
  .object({
    id: zod.string().describe('User ID (TSID)'),
    email: zod.string().describe('User email address'),
    displayName: zod.string().describe('User display name'),
    avatarUrl: zod.string().optional().describe('User avatar URL'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Account creation timestamp'),
    unitSystem: zod
      .enum(['METRIC', 'IMPERIAL'])
      .optional()
      .describe('Preferred unit system (metric or imperial)'),
    theme: zod
      .enum(['SYSTEM', 'LIGHT', 'DARK'])
      .optional()
      .describe(
        'Preferred colour scheme. Null means the user never chose one — distinct from SYSTEM, which they did choose — so a client is free to follow the device.'
      ),
    language: zod
      .string()
      .optional()
      .describe(
        'Preferred language as a BCP-47 tag. Null means the user never chose one; the client then follows the device or the domain.'
      ),
    timezone: zod
      .string()
      .optional()
      .describe(
        "Preferred IANA timezone (e.g. 'Europe/Paris'). Null means the user never chose one; the client then follows the browser."
      ),
    contactableByMembers: zod
      .boolean()
      .describe(
        'Whether team members may reach this user through the classified-ad relay. True unless they explicitly opted out, so an account that predates the preference is contactable.'
      ),
    platformRole: zod
      .enum(['PLATFORM_ADMIN'])
      .optional()
      .describe('Platform role (null if regular user)'),
    emailVerified: zod.boolean().describe("Whether the account's email has been verified"),
    connectedServices: zod
      .array(
        zod
          .object({
            serviceType: zod
              .enum(['HAMMERHEAD', 'GARMIN', 'WAHOO'])
              .describe('Service type identifier'),
            displayName: zod.string().describe('Display name of the service'),
            connectedAt: zod.iso
              .datetime({ offset: true })
              .describe('When the service was connected'),
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
      )
      .optional()
      .describe('Connected GPS services'),
  })
  .describe('User profile data')

/**
 * Get the current authenticated user's profile.
 * @summary Get current user
 */
export const GetMeResponse = zod
  .object({
    id: zod.string().describe('User ID (TSID)'),
    email: zod.string().describe('User email address'),
    displayName: zod.string().describe('User display name'),
    avatarUrl: zod.string().optional().describe('User avatar URL'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Account creation timestamp'),
    unitSystem: zod
      .enum(['METRIC', 'IMPERIAL'])
      .optional()
      .describe('Preferred unit system (metric or imperial)'),
    theme: zod
      .enum(['SYSTEM', 'LIGHT', 'DARK'])
      .optional()
      .describe(
        'Preferred colour scheme. Null means the user never chose one — distinct from SYSTEM, which they did choose — so a client is free to follow the device.'
      ),
    language: zod
      .string()
      .optional()
      .describe(
        'Preferred language as a BCP-47 tag. Null means the user never chose one; the client then follows the device or the domain.'
      ),
    timezone: zod
      .string()
      .optional()
      .describe(
        "Preferred IANA timezone (e.g. 'Europe/Paris'). Null means the user never chose one; the client then follows the browser."
      ),
    contactableByMembers: zod
      .boolean()
      .describe(
        'Whether team members may reach this user through the classified-ad relay. True unless they explicitly opted out, so an account that predates the preference is contactable.'
      ),
    platformRole: zod
      .enum(['PLATFORM_ADMIN'])
      .optional()
      .describe('Platform role (null if regular user)'),
    emailVerified: zod.boolean().describe("Whether the account's email has been verified"),
    connectedServices: zod
      .array(
        zod
          .object({
            serviceType: zod
              .enum(['HAMMERHEAD', 'GARMIN', 'WAHOO'])
              .describe('Service type identifier'),
            displayName: zod.string().describe('Display name of the service'),
            connectedAt: zod.iso
              .datetime({ offset: true })
              .describe('When the service was connected'),
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
      )
      .optional()
      .describe('Connected GPS services'),
  })
  .describe('User profile data')

/**
 * Delete the current user's account. The teams they administer and are the only member of are deleted with it; see GET /api/users/me/deletion-impact.
 * @summary Delete current user
 */
export const DeleteCurrentUserResponse = zod.void()

/**
 * Upload a new avatar image for the current user. Image will be resized to 256x256.
 * @summary Upload user avatar
 */
export const UploadAvatarBody = zod.object({
  file: zod.instanceof(Blob).optional(),
})

export const UploadAvatarResponse = zod
  .object({
    id: zod.string().describe('User ID (TSID)'),
    email: zod.string().describe('User email address'),
    displayName: zod.string().describe('User display name'),
    avatarUrl: zod.string().optional().describe('User avatar URL'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Account creation timestamp'),
    unitSystem: zod
      .enum(['METRIC', 'IMPERIAL'])
      .optional()
      .describe('Preferred unit system (metric or imperial)'),
    theme: zod
      .enum(['SYSTEM', 'LIGHT', 'DARK'])
      .optional()
      .describe(
        'Preferred colour scheme. Null means the user never chose one — distinct from SYSTEM, which they did choose — so a client is free to follow the device.'
      ),
    language: zod
      .string()
      .optional()
      .describe(
        'Preferred language as a BCP-47 tag. Null means the user never chose one; the client then follows the device or the domain.'
      ),
    timezone: zod
      .string()
      .optional()
      .describe(
        "Preferred IANA timezone (e.g. 'Europe/Paris'). Null means the user never chose one; the client then follows the browser."
      ),
    contactableByMembers: zod
      .boolean()
      .describe(
        'Whether team members may reach this user through the classified-ad relay. True unless they explicitly opted out, so an account that predates the preference is contactable.'
      ),
    platformRole: zod
      .enum(['PLATFORM_ADMIN'])
      .optional()
      .describe('Platform role (null if regular user)'),
    emailVerified: zod.boolean().describe("Whether the account's email has been verified"),
    connectedServices: zod
      .array(
        zod
          .object({
            serviceType: zod
              .enum(['HAMMERHEAD', 'GARMIN', 'WAHOO'])
              .describe('Service type identifier'),
            displayName: zod.string().describe('Display name of the service'),
            connectedAt: zod.iso
              .datetime({ offset: true })
              .describe('When the service was connected'),
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
      )
      .optional()
      .describe('Connected GPS services'),
  })
  .describe('User profile data')

/**
 * Remove the current user's avatar
 * @summary Delete user avatar
 */
export const DeleteAvatarResponse = zod
  .object({
    id: zod.string().describe('User ID (TSID)'),
    email: zod.string().describe('User email address'),
    displayName: zod.string().describe('User display name'),
    avatarUrl: zod.string().optional().describe('User avatar URL'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Account creation timestamp'),
    unitSystem: zod
      .enum(['METRIC', 'IMPERIAL'])
      .optional()
      .describe('Preferred unit system (metric or imperial)'),
    theme: zod
      .enum(['SYSTEM', 'LIGHT', 'DARK'])
      .optional()
      .describe(
        'Preferred colour scheme. Null means the user never chose one — distinct from SYSTEM, which they did choose — so a client is free to follow the device.'
      ),
    language: zod
      .string()
      .optional()
      .describe(
        'Preferred language as a BCP-47 tag. Null means the user never chose one; the client then follows the device or the domain.'
      ),
    timezone: zod
      .string()
      .optional()
      .describe(
        "Preferred IANA timezone (e.g. 'Europe/Paris'). Null means the user never chose one; the client then follows the browser."
      ),
    contactableByMembers: zod
      .boolean()
      .describe(
        'Whether team members may reach this user through the classified-ad relay. True unless they explicitly opted out, so an account that predates the preference is contactable.'
      ),
    platformRole: zod
      .enum(['PLATFORM_ADMIN'])
      .optional()
      .describe('Platform role (null if regular user)'),
    emailVerified: zod.boolean().describe("Whether the account's email has been verified"),
    connectedServices: zod
      .array(
        zod
          .object({
            serviceType: zod
              .enum(['HAMMERHEAD', 'GARMIN', 'WAHOO'])
              .describe('Service type identifier'),
            displayName: zod.string().describe('Display name of the service'),
            connectedAt: zod.iso
              .datetime({ offset: true })
              .describe('When the service was connected'),
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
      )
      .optional()
      .describe('Connected GPS services'),
  })
  .describe('User profile data')

/**
 * What deleting the current user's account would do to their teams: the teams deleted with it (they administer them alone), and the teams that refuse the deletion (SOLE_TEAM_ADMIN, or SOLE_MIGRATED_TEAM_ADMIN for a team migrated from biketeam). Read-only.
 * @summary Preview the deletion of the current user
 */
export const GetMyDeletionImpactResponse = zod
  .object({
    blocked: zod
      .boolean()
      .describe(
        'Whether the deletion is refused: the user is the only admin of at least one team that has other members (SOLE_TEAM_ADMIN), or of a team migrated from biketeam (SOLE_MIGRATED_TEAM_ADMIN)'
      ),
    blockingTeams: zod
      .array(
        zod
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
          .describe('Team information')
      )
      .describe(
        'Teams the user is the only admin of while other members remain; they must name another admin, or delete the team, before deleting their account. Excludes the teams listed in migratedTeams'
      ),
    deletedTeams: zod
      .array(
        zod
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
          .describe('Team information')
      )
      .describe(
        'Teams the user administers and is the only member of; they are deleted with the account. Excludes the teams listed in migratedTeams'
      ),
    migratedTeams: zod
      .array(
        zod
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
          .describe('Team information')
      )
      .describe(
        'Teams the user is the only admin of, with or without other members, that were migrated from biketeam: their old biketeam addresses redirect to them. Each one refuses the deletion until another admin is named (or, for a platform admin, the switch-over is cancelled on biketeam and the team deleted)'
      ),
  })
  .describe("What deleting the current user's account would do to their teams")

/**
 * The devices (Karoo, Garmin) paired with the current account by code and still able to renew their access, newest first. The GPS services the account is connected to are on the profile (connectedServices), not here.
 * @summary List paired devices
 */
export const ListPairedDevicesResponseItem = zod
  .object({
    id: zod.string().describe('Pairing ID, to unpair the device'),
    type: zod.enum(['KAROO', 'GARMIN', 'OTHER']).describe('Kind of device'),
    pairedAt: zod.iso.datetime({ offset: true }).describe('When the device was paired'),
    lastUsedAt: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe('When the device last renewed its access'),
  })
  .describe('A device (Karoo, Garmin) paired with the account by code')
export const ListPairedDevicesResponse = zod.array(ListPairedDevicesResponseItem)

/**
 * Revoke the pairing of one device: its access token is refused at once (401), its renewal fails, and it must be paired again.
 * @summary Unpair a device
 */
export const UnpairDeviceParams = zod.object({
  deviceId: zod.string().describe('Pairing ID (TSID)'),
})

export const UnpairDeviceResponse = zod.void()

/**
 * Queue a GDPR export of the current user's data. The archive is built in the background and a download link is emailed when it is ready. Limited to one export per hour.
 * @summary Request a personal data export
 */
export const RequestExportResponse = zod
  .object({
    id: zod.string().describe('Export job identifier'),
    status: zod
      .enum(['PENDING', 'PROCESSING', 'READY', 'FAILED', 'EXPIRED'])
      .describe('Current status'),
    requestedAt: zod.iso.datetime({ offset: true }).describe('When the export was requested'),
    completedAt: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe('When the export finished building'),
    expiresAt: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe('When the download link stops working'),
    fileSize: zod.int().optional().describe('Size of the archive in bytes'),
  })
  .describe('Status of a personal data export request')

/**
 * Status of the current user's most recent export request, if any.
 * @summary Get the latest data export
 */
export const GetLatestExportResponse = zod
  .object({
    id: zod.string().describe('Export job identifier'),
    status: zod
      .enum(['PENDING', 'PROCESSING', 'READY', 'FAILED', 'EXPIRED'])
      .describe('Current status'),
    requestedAt: zod.iso.datetime({ offset: true }).describe('When the export was requested'),
    completedAt: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe('When the export finished building'),
    expiresAt: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe('When the download link stops working'),
    fileSize: zod.int().optional().describe('Size of the archive in bytes'),
  })
  .describe('Status of a personal data export request')

/**
 * Status of one of the current user's export requests.
 * @summary Get a data export
 */
export const GetExportParams = zod.object({
  exportId: zod.string().describe('Export job identifier'),
})

export const GetExportResponse = zod
  .object({
    id: zod.string().describe('Export job identifier'),
    status: zod
      .enum(['PENDING', 'PROCESSING', 'READY', 'FAILED', 'EXPIRED'])
      .describe('Current status'),
    requestedAt: zod.iso.datetime({ offset: true }).describe('When the export was requested'),
    completedAt: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe('When the export finished building'),
    expiresAt: zod.iso
      .datetime({ offset: true })
      .optional()
      .describe('When the download link stops working'),
    fileSize: zod.int().optional().describe('Size of the archive in bytes'),
  })
  .describe('Status of a personal data export request')

/**
 * The rides and trips the current user is registered to, soonest first. Only publications the user may still see are returned: leaving a team removes its outings from this list.
 * @summary List my participations
 */
export const listMyParticipationsQueryPageDefault = 0
export const listMyParticipationsQuerySizeDefault = 20

export const ListMyParticipationsQueryParams = zod.object({
  from: zod.string().optional().describe('Start date filter (ISO format)'),
  page: zod.int().default(listMyParticipationsQueryPageDefault).describe('Page number'),
  size: zod.int().default(listMyParticipationsQuerySizeDefault).describe('Page size'),
  status: zod
    .enum(['DRAFT', 'PUBLISHED', 'CANCELLED'])
    .optional()
    .describe('Only publications with this status'),
  to: zod.string().optional().describe('End date filter (ISO format)'),
  view: zod
    .enum(['FULL', 'COMPACT'])
    .optional()
    .describe(
      "How much of each row to send. COMPACT (case-insensitive) returns media.markdown empty and media.assets trimmed to the logo, the first image and the themed thumbnails — read 'excerpt' and 'thumbnailUrl' instead, both of which are present either way. The markdown body, the attachments, the GPX and FIT files and every image past the first are dropped. Omitted, or FULL, is the previous behaviour, byte for byte."
    ),
})

export const listMyParticipationsResponsePublicationsItemOneMediaMarkdownMax = 100000

export const listMyParticipationsResponsePublicationsItemTwoMediaMarkdownMax = 100000

export const listMyParticipationsResponsePublicationsItemThreeMediaMarkdownMax = 100000

export const listMyParticipationsResponsePublicationsItemThreeStagesItemRouteMediaMarkdownMax = 100000

export const listMyParticipationsResponsePublicationsItemThreeStagesItemMediaMarkdownMax = 100000

export const ListMyParticipationsResponse = zod
  .object({
    publications: zod
      .array(
        zod
          .union([
            zod
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
                    markdown: zod
                      .string()
                      .max(listMyParticipationsResponsePublicationsItemOneMediaMarkdownMax)
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
                status: zod
                  .enum(['DRAFT', 'PUBLISHED', 'CANCELLED'])
                  .describe('Publication status'),
                finished: zod
                  .boolean()
                  .describe(
                    'Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished.'
                  ),
                visibility: zod
                  .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
                  .describe('Visibility level'),
                publishAt: zod.iso
                  .datetime({ offset: true })
                  .optional()
                  .describe('Publication timestamp'),
                createdAt: zod.iso
                  .datetime({ offset: true })
                  .optional()
                  .describe('Creation timestamp'),
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
                            'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=. Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.'
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
                          .describe(
                            'Total elevation gain in meters of the group route, if it has one'
                          ),
                        leader: zod
                          .object({
                            id: zod.string().describe('User ID (TSID)'),
                            displayName: zod.string().describe('User display name'),
                            avatarUrl: zod.string().optional().describe('User avatar URL'),
                          })
                          .optional()
                          .describe(
                            "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride. Also null for a caller who is not a member of the team: member names are never sent to anyone else."
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
                        routeSlug: zod
                          .string()
                          .optional()
                          .describe('Slug of the group route, if it has one'),
                        distance: zod
                          .number()
                          .optional()
                          .describe('Distance in meters of the group route, if it has one'),
                        elevationGain: zod
                          .number()
                          .optional()
                          .describe(
                            'Total elevation gain in meters of the group route, if it has one'
                          ),
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
                  .describe(
                    'Preview of first participants (max 5). Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.'
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
                deleted: zod.boolean().describe('Whether the ride is soft-deleted'),
                registered: zod
                  .boolean()
                  .describe(
                    "Whether the current user is registered in one of this ride's groups. False if anonymous."
                  ),
                registeredGroupId: zod
                  .string()
                  .optional()
                  .describe(
                    'ID (TSID) of the group the current user joined, null if not registered'
                  ),
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
                        'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=. Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.'
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
                        "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride. Also null for a caller who is not a member of the team: member names are never sent to anyone else."
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
                    "The team's RIDE tags the ride carries, sorted by label. Empty when it carries none."
                  ),
                weather: zod
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
                        probability: zod
                          .int()
                          .describe('Probability of precipitation then, % (0–100)'),
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
              .describe('Ride summary data'),
            zod
              .object({
                type: zod.enum(['POST']),
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
                    markdown: zod
                      .string()
                      .max(listMyParticipationsResponsePublicationsItemTwoMediaMarkdownMax)
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
                  .describe('Publication media'),
                excerpt: zod
                  .string()
                  .optional()
                  .describe(
                    "Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter."
                  ),
                thumbnailUrl: zod
                  .string()
                  .optional()
                  .describe(
                    "URL template of the post's first image, the one a card shows. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only."
                  ),
                dateTime: zod.iso.datetime({ offset: true }).describe('Publication date/time'),
                timezone: zod
                  .string()
                  .describe(
                    "IANA zone the post's times were entered in and read in: the team's at its last save. dateTime, publishAt are rendezvous in this zone."
                  ),
                status: zod
                  .enum(['DRAFT', 'PUBLISHED', 'CANCELLED'])
                  .describe('Publication status'),
                visibility: zod
                  .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
                  .describe('Visibility level'),
                publishAt: zod.iso
                  .datetime({ offset: true })
                  .optional()
                  .describe('Publication timestamp'),
                createdAt: zod.iso
                  .datetime({ offset: true })
                  .optional()
                  .describe('Creation timestamp'),
                deleted: zod.boolean().describe('Whether the post is soft-deleted'),
                commentCount: zod
                  .int()
                  .optional()
                  .describe(
                    'Number of comments, replies included. Absent when the caller may not read the comments of this post — comments are members-only, so an outsider is told nothing, not even zero.'
                  ),
                signedAsTeam: zod
                  .boolean()
                  .describe(
                    'Whether the post is signed by the team rather than by its author. Readers are then not told who wrote it: createdBy is absent unless the caller administers the team or wrote the post.'
                  ),
                createdBy: zod
                  .object({
                    id: zod.string().describe('User ID (TSID)'),
                    displayName: zod.string().describe('User display name'),
                    avatarUrl: zod.string().optional().describe('User avatar URL'),
                  })
                  .optional()
                  .describe(
                    'Who wrote the post. Absent when the caller is not a member of the team — member names are never sent to anyone else — and when the post is signed by the team (signedAsTeam) and the caller neither administers the team nor wrote it: render the team instead.'
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
                    "The team's POST tags the post carries, sorted by label. Empty when it carries none."
                  ),
              })
              .describe('Post summary data'),
            zod
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
                    markdown: zod
                      .string()
                      .max(listMyParticipationsResponsePublicationsItemThreeMediaMarkdownMax)
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
                status: zod
                  .enum(['DRAFT', 'PUBLISHED', 'CANCELLED'])
                  .describe('Publication status'),
                finished: zod
                  .boolean()
                  .describe(
                    'Whether the trip is over, computed by the server when the response is built: its last stage (endDate, or dateTime when there is none) has started. Independent of status — a past cancelled trip is both CANCELLED and finished.'
                  ),
                visibility: zod
                  .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
                  .describe('Visibility level'),
                publishAt: zod.iso
                  .datetime({ offset: true })
                  .optional()
                  .describe('Publication timestamp'),
                createdAt: zod.iso
                  .datetime({ offset: true })
                  .optional()
                  .describe('Creation timestamp'),
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
                                  .max(
                                    listMyParticipationsResponsePublicationsItemThreeStagesItemRouteMediaMarkdownMax
                                  )
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
                            surfaceType: zod
                              .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
                              .describe('Surface type'),
                            visibility: zod
                              .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
                              .describe('Whether the route is public'),
                            createdAt: zod.iso
                              .datetime({ offset: true })
                              .describe('Creation timestamp'),
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
                              .max(
                                listMyParticipationsResponsePublicationsItemThreeStagesItemMediaMarkdownMax
                              )
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
                          .describe(
                            "How many live stages the trip has — the '/ 5' of 'Day 2 / 5'."
                          ),
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
                  .describe(
                    'Whether the current user is registered for this trip. False if anonymous.'
                  ),
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
                    "The team's TRIP tags the trip carries, sorted by label. Empty when it carries none."
                  ),
                weather: zod
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
                        probability: zod
                          .int()
                          .describe('Probability of precipitation then, % (0–100)'),
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
              .describe('Trip data'),
          ])
          .and(
            zod.object({
              type: zod.enum(['RIDE', 'POST', 'TRIP']).optional(),
              visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).optional(),
              name: zod.string().optional(),
            })
          )
          .describe('Publication data')
      )
      .describe('List of publications'),
    total: zod.int().describe('Total number of publications'),
    page: zod.int().describe('Current page number'),
    size: zod.int().describe('Page size'),
  })
  .describe('Paginated publication list response')

/**
 * Set the current user's unit system, colour scheme and language. A partial update: fields omitted (or sent null) are left unchanged. These live on the server so that a member who picks imperial units on their phone sees them on the web too, and so that reinstalling the app does not lose them.
 * @summary Update display preferences
 */
export const updateMyPreferencesBodyLanguageMin = 2
export const updateMyPreferencesBodyLanguageMax = 10

export const updateMyPreferencesBodyLanguageRegExp = new RegExp(
  '^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$'
)
export const updateMyPreferencesBodyTimezoneMax = 64

export const UpdateMyPreferencesBody = zod
  .object({
    unitSystem: zod
      .enum(['METRIC', 'IMPERIAL'])
      .optional()
      .describe('Preferred unit system. Omit or send null to leave it unchanged.'),
    theme: zod
      .enum(['SYSTEM', 'LIGHT', 'DARK'])
      .optional()
      .describe('Preferred colour scheme. Omit or send null to leave it unchanged.'),
    language: zod
      .string()
      .min(updateMyPreferencesBodyLanguageMin)
      .max(updateMyPreferencesBodyLanguageMax)
      .regex(updateMyPreferencesBodyLanguageRegExp)
      .optional()
      .describe(
        "Preferred language as a BCP-47 tag ('fr', 'en', 'fr-CA'). Omit or send null to leave it unchanged. Not validated against the set of translations the app ships: a client asking for a language nobody has translated yet falls back on its own, which is better than a 400 the day a translation lands."
      ),
    timezone: zod
      .string()
      .max(updateMyPreferencesBodyTimezoneMax)
      .optional()
      .describe(
        "Preferred IANA timezone (e.g. 'Europe/Paris'). Omit or send null to leave it unchanged. Validated against the JDK's own timezone database, not a regex."
      ),
    contactableByMembers: zod
      .boolean()
      .optional()
      .describe(
        'Whether team members may reach you through the classified-ad relay. Omit or send null to leave it unchanged. Setting it to false stops the relay from delivering to you; your ads stay visible, they simply stop being answerable.'
      ),
  })
  .describe("Partial update of the current user's display preferences")

export const UpdateMyPreferencesResponse = zod
  .object({
    id: zod.string().describe('User ID (TSID)'),
    email: zod.string().describe('User email address'),
    displayName: zod.string().describe('User display name'),
    avatarUrl: zod.string().optional().describe('User avatar URL'),
    createdAt: zod.iso.datetime({ offset: true }).optional().describe('Account creation timestamp'),
    unitSystem: zod
      .enum(['METRIC', 'IMPERIAL'])
      .optional()
      .describe('Preferred unit system (metric or imperial)'),
    theme: zod
      .enum(['SYSTEM', 'LIGHT', 'DARK'])
      .optional()
      .describe(
        'Preferred colour scheme. Null means the user never chose one — distinct from SYSTEM, which they did choose — so a client is free to follow the device.'
      ),
    language: zod
      .string()
      .optional()
      .describe(
        'Preferred language as a BCP-47 tag. Null means the user never chose one; the client then follows the device or the domain.'
      ),
    timezone: zod
      .string()
      .optional()
      .describe(
        "Preferred IANA timezone (e.g. 'Europe/Paris'). Null means the user never chose one; the client then follows the browser."
      ),
    contactableByMembers: zod
      .boolean()
      .describe(
        'Whether team members may reach this user through the classified-ad relay. True unless they explicitly opted out, so an account that predates the preference is contactable.'
      ),
    platformRole: zod
      .enum(['PLATFORM_ADMIN'])
      .optional()
      .describe('Platform role (null if regular user)'),
    emailVerified: zod.boolean().describe("Whether the account's email has been verified"),
    connectedServices: zod
      .array(
        zod
          .object({
            serviceType: zod
              .enum(['HAMMERHEAD', 'GARMIN', 'WAHOO'])
              .describe('Service type identifier'),
            displayName: zod.string().describe('Display name of the service'),
            connectedAt: zod.iso
              .datetime({ offset: true })
              .describe('When the service was connected'),
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
      )
      .optional()
      .describe('Connected GPS services'),
  })
  .describe('User profile data')

/**
 * What the profile overview shows next to each shortcut, in one request: the next outing and the outing counts, the teams with the user's role, the passkey count, the paired devices, the number of blocked users and where notifications go. The display preferences, contactableByMembers and the connected GPS services are on GET /api/users/me and are not repeated. A fixed number of queries, whatever the amount of data.
 * @summary Summarise the current user's profile
 */
export const getMyProfileSummaryResponseParticipationsNextItemOneMediaMarkdownMax = 100000

export const getMyProfileSummaryResponseParticipationsNextItemTwoMediaMarkdownMax = 100000

export const getMyProfileSummaryResponseParticipationsNextItemThreeMediaMarkdownMax = 100000

export const getMyProfileSummaryResponseParticipationsNextItemThreeStagesItemRouteMediaMarkdownMax = 100000

export const getMyProfileSummaryResponseParticipationsNextItemThreeStagesItemMediaMarkdownMax = 100000

export const GetMyProfileSummaryResponse = zod
  .object({
    participations: zod
      .object({
        upcomingCount: zod.int().describe('Outings starting from now on'),
        pastCount: zod.int().describe('Outings that started before now'),
        next: zod
          .array(
            zod
              .union([
                zod
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
                        markdown: zod
                          .string()
                          .max(getMyProfileSummaryResponseParticipationsNextItemOneMediaMarkdownMax)
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
                    status: zod
                      .enum(['DRAFT', 'PUBLISHED', 'CANCELLED'])
                      .describe('Publication status'),
                    finished: zod
                      .boolean()
                      .describe(
                        'Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished.'
                      ),
                    visibility: zod
                      .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
                      .describe('Visibility level'),
                    publishAt: zod.iso
                      .datetime({ offset: true })
                      .optional()
                      .describe('Publication timestamp'),
                    createdAt: zod.iso
                      .datetime({ offset: true })
                      .optional()
                      .describe('Creation timestamp'),
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
                                'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=. Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.'
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
                              .describe(
                                'Total elevation gain in meters of the group route, if it has one'
                              ),
                            leader: zod
                              .object({
                                id: zod.string().describe('User ID (TSID)'),
                                displayName: zod.string().describe('User display name'),
                                avatarUrl: zod.string().optional().describe('User avatar URL'),
                              })
                              .optional()
                              .describe(
                                "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride. Also null for a caller who is not a member of the team: member names are never sent to anyone else."
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
                            routeSlug: zod
                              .string()
                              .optional()
                              .describe('Slug of the group route, if it has one'),
                            distance: zod
                              .number()
                              .optional()
                              .describe('Distance in meters of the group route, if it has one'),
                            elevationGain: zod
                              .number()
                              .optional()
                              .describe(
                                'Total elevation gain in meters of the group route, if it has one'
                              ),
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
                      .describe(
                        'Preview of first participants (max 5). Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.'
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
                    deleted: zod.boolean().describe('Whether the ride is soft-deleted'),
                    registered: zod
                      .boolean()
                      .describe(
                        "Whether the current user is registered in one of this ride's groups. False if anonymous."
                      ),
                    registeredGroupId: zod
                      .string()
                      .optional()
                      .describe(
                        'ID (TSID) of the group the current user joined, null if not registered'
                      ),
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
                            'The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=. Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.'
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
                          .describe(
                            'Total elevation gain in meters of the group route, if it has one'
                          ),
                        leader: zod
                          .object({
                            id: zod.string().describe('User ID (TSID)'),
                            displayName: zod.string().describe('User display name'),
                            avatarUrl: zod.string().optional().describe('User avatar URL'),
                          })
                          .optional()
                          .describe(
                            "The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride. Also null for a caller who is not a member of the team: member names are never sent to anyone else."
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
                        "The team's RIDE tags the ride carries, sorted by label. Empty when it carries none."
                      ),
                    weather: zod
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
                        weatherCode: zod
                          .int()
                          .optional()
                          .describe('WMO code at the departure hour'),
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
                            probability: zod
                              .int()
                              .describe('Probability of precipitation then, % (0–100)'),
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
                  .describe('Ride summary data'),
                zod
                  .object({
                    type: zod.enum(['POST']),
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
                        markdown: zod
                          .string()
                          .max(getMyProfileSummaryResponseParticipationsNextItemTwoMediaMarkdownMax)
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
                      .describe('Publication media'),
                    excerpt: zod
                      .string()
                      .optional()
                      .describe(
                        "Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter."
                      ),
                    thumbnailUrl: zod
                      .string()
                      .optional()
                      .describe(
                        "URL template of the post's first image, the one a card shows. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only."
                      ),
                    dateTime: zod.iso.datetime({ offset: true }).describe('Publication date/time'),
                    timezone: zod
                      .string()
                      .describe(
                        "IANA zone the post's times were entered in and read in: the team's at its last save. dateTime, publishAt are rendezvous in this zone."
                      ),
                    status: zod
                      .enum(['DRAFT', 'PUBLISHED', 'CANCELLED'])
                      .describe('Publication status'),
                    visibility: zod
                      .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
                      .describe('Visibility level'),
                    publishAt: zod.iso
                      .datetime({ offset: true })
                      .optional()
                      .describe('Publication timestamp'),
                    createdAt: zod.iso
                      .datetime({ offset: true })
                      .optional()
                      .describe('Creation timestamp'),
                    deleted: zod.boolean().describe('Whether the post is soft-deleted'),
                    commentCount: zod
                      .int()
                      .optional()
                      .describe(
                        'Number of comments, replies included. Absent when the caller may not read the comments of this post — comments are members-only, so an outsider is told nothing, not even zero.'
                      ),
                    signedAsTeam: zod
                      .boolean()
                      .describe(
                        'Whether the post is signed by the team rather than by its author. Readers are then not told who wrote it: createdBy is absent unless the caller administers the team or wrote the post.'
                      ),
                    createdBy: zod
                      .object({
                        id: zod.string().describe('User ID (TSID)'),
                        displayName: zod.string().describe('User display name'),
                        avatarUrl: zod.string().optional().describe('User avatar URL'),
                      })
                      .optional()
                      .describe(
                        'Who wrote the post. Absent when the caller is not a member of the team — member names are never sent to anyone else — and when the post is signed by the team (signedAsTeam) and the caller neither administers the team nor wrote it: render the team instead.'
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
                        "The team's POST tags the post carries, sorted by label. Empty when it carries none."
                      ),
                  })
                  .describe('Post summary data'),
                zod
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
                        markdown: zod
                          .string()
                          .max(
                            getMyProfileSummaryResponseParticipationsNextItemThreeMediaMarkdownMax
                          )
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
                    status: zod
                      .enum(['DRAFT', 'PUBLISHED', 'CANCELLED'])
                      .describe('Publication status'),
                    finished: zod
                      .boolean()
                      .describe(
                        'Whether the trip is over, computed by the server when the response is built: its last stage (endDate, or dateTime when there is none) has started. Independent of status — a past cancelled trip is both CANCELLED and finished.'
                      ),
                    visibility: zod
                      .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
                      .describe('Visibility level'),
                    publishAt: zod.iso
                      .datetime({ offset: true })
                      .optional()
                      .describe('Publication timestamp'),
                    createdAt: zod.iso
                      .datetime({ offset: true })
                      .optional()
                      .describe('Creation timestamp'),
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
                            dateTime: zod.iso
                              .datetime({ offset: true })
                              .describe('Stage date/time'),
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
                                      .max(
                                        getMyProfileSummaryResponseParticipationsNextItemThreeStagesItemRouteMediaMarkdownMax
                                      )
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
                                elevationGain: zod
                                  .number()
                                  .describe('Total elevation gain in meters'),
                                elevationLoss: zod
                                  .number()
                                  .describe('Total elevation loss in meters'),
                                elevationState: zod
                                  .enum(['PENDING', 'HD', 'FAST'])
                                  .describe(
                                    'Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed.'
                                  ),
                                surfaceType: zod
                                  .enum(['ROAD', 'GRAVEL', 'MTB', 'MIXED'])
                                  .describe('Surface type'),
                                visibility: zod
                                  .enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC'])
                                  .describe('Whether the route is public'),
                                createdAt: zod.iso
                                  .datetime({ offset: true })
                                  .describe('Creation timestamp'),
                                deleted: zod
                                  .boolean()
                                  .describe('Whether the route is soft-deleted'),
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
                                        label: zod
                                          .string()
                                          .describe('Label, at most 32 characters'),
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
                                  .max(
                                    getMyProfileSummaryResponseParticipationsNextItemThreeStagesItemMediaMarkdownMax
                                  )
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
                              .describe(
                                "How many live stages the trip has — the '/ 5' of 'Day 2 / 5'."
                              ),
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
                      .describe(
                        'Whether the current user is registered for this trip. False if anonymous.'
                      ),
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
                        "The team's TRIP tags the trip carries, sorted by label. Empty when it carries none."
                      ),
                    weather: zod
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
                        weatherCode: zod
                          .int()
                          .optional()
                          .describe('WMO code at the departure hour'),
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
                            probability: zod
                              .int()
                              .describe('Probability of precipitation then, % (0–100)'),
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
                  .describe('Trip data'),
              ])
              .and(
                zod.object({
                  type: zod.enum(['RIDE', 'POST', 'TRIP']).optional(),
                  visibility: zod.enum(['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']).optional(),
                  name: zod.string().optional(),
                })
              )
              .describe('Publication data')
          )
          .describe(
            'The next outing, in the compact list view (no markdown body): empty when nothing is coming up, never more than one row'
          ),
      })
      .describe('Rides and trips the user is registered to'),
    teams: zod
      .array(
        zod
          .object({
            slug: zod.string().describe('Team URL slug'),
            name: zod.string().describe('Team name'),
            role: zod
              .enum(['MEMBER', 'ORGANIZER', 'ADMIN'])
              .describe("The user's role in the team"),
          })
          .describe("One of the current user's teams, with the user's role in it")
      )
      .describe("The user's teams on this site, in name order, each with the user's role in it"),
    passkeyCount: zod.int().describe('Number of passkeys registered on the account'),
    pairedDevices: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Pairing ID, to unpair the device'),
            type: zod.enum(['KAROO', 'GARMIN', 'OTHER']).describe('Kind of device'),
            pairedAt: zod.iso.datetime({ offset: true }).describe('When the device was paired'),
            lastUsedAt: zod.iso
              .datetime({ offset: true })
              .optional()
              .describe('When the device last renewed its access'),
          })
          .describe('A device (Karoo, Garmin) paired with the account by code')
      )
      .describe(
        'Devices (Karoo, Garmin) paired with the account, newest first — the same rows as GET /api/users/me/devices'
      ),
    blockedUserCount: zod.int().describe('Number of live accounts the user blocked'),
    notifications: zod
      .object({
        channels: zod
          .array(zod.enum(['IN_APP', 'EMAIL', 'PUSH']))
          .describe('Channels that can be configured on this server, in display order'),
        enabledChannels: zod
          .array(zod.enum(['IN_APP', 'EMAIL', 'PUSH']))
          .describe(
            'Among channels, those on which at least one notification type is turned on for the user (their choices, or the defaults they never changed)'
          ),
        emailDigest: zod
          .boolean()
          .describe(
            'Whether non-urgent e-mails are held for a daily digest. Always false when EMAIL is not among channels.'
          ),
      })
      .describe("Where the user's notifications go"),
  })
  .describe("The state of each subject of the current user's profile, for its overview")
