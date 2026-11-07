import * as zod from 'zod'

/**
 * The current user's notifications, newest first. Each carries a type and structured fields, not rendered text: the client words it in its own language.
 * @summary List my notifications
 */
export const listMyNotificationsQueryPageDefault = 0
export const listMyNotificationsQuerySizeDefault = 20
export const listMyNotificationsQueryUnreadOnlyDefault = false

export const ListMyNotificationsQueryParams = zod.object({
  page: zod.int().default(listMyNotificationsQueryPageDefault).describe('Page number (0-indexed)'),
  size: zod.int().default(listMyNotificationsQuerySizeDefault).describe('Page size (max 200)'),
  unreadOnly: zod
    .boolean()
    .default(listMyNotificationsQueryUnreadOnlyDefault)
    .describe('Only unread notifications'),
})

export const ListMyNotificationsResponse = zod
  .object({
    items: zod
      .array(
        zod
          .object({
            id: zod.string().describe('Notification identifier'),
            type: zod
              .enum([
                'RIDE_PUBLISHED',
                'RIDE_CANCELLED',
                'TRIP_PUBLISHED',
                'TRIP_CANCELLED',
                'POST_PUBLISHED',
                'COMMENT_REPLY',
                'RIDE_REMINDER',
                'RIDE_UPDATED',
                'RIDE_GROUP_REMOVED',
                'RIDE_JOINED',
                'COMMENT_ON_MY_PUBLICATION',
                'TEAM_INVITATION',
                'CONTENT_REPORTED',
              ])
              .describe('What happened'),
            read: zod.boolean().describe('Whether the user has read it'),
            createdAt: zod.iso.datetime({ offset: true }).describe('When it was created'),
            actorName: zod
              .string()
              .optional()
              .describe(
                'Display name of whoever caused it, when someone did (a scheduled publication has no actor)'
              ),
            teamSlug: zod.string().describe('Slug of the team it happened in'),
            teamName: zod.string().describe('Name of the team it happened in'),
            subjectType: zod
              .enum(['RIDE', 'TRIP', 'POST', 'ROUTE', 'TEAM', 'REPORT'])
              .describe('Kind of page the notification opens'),
            subjectSlug: zod
              .string()
              .describe('Slug of the ride, trip, post or route — of the team, for TEAM'),
            subjectName: zod
              .string()
              .describe('Name of the ride, trip, post or route — of the team, for TEAM'),
            subjectDateTime: zod.iso
              .datetime({ offset: true })
              .optional()
              .describe(
                "Date of the ride or trip, publication date of a post. For a ride, the start of the recipient's own group when it concerns them: the group they are registered to (reminder, cancellation, change), joined (RIDE_JOINED) or lost (RIDE_GROUP_REMOVED); the ride's otherwise"
              ),
            subjectTimezone: zod
              .string()
              .optional()
              .describe(
                "IANA zone subjectDateTime reads in — the subject's own, as RideDto.timezone: a rendezvous, shown in it with a mention when the reader's differs. Present when subjectDateTime is, except on notifications sent before 10.20.0, which read in the reader's zone"
              ),
            excerpt: zod
              .string()
              .optional()
              .describe(
                'A short quote: the comment, for COMMENT_REPLY and COMMENT_ON_MY_PUBLICATION; the name of the group joined, for RIDE_JOINED'
              ),
            changes: zod
              .array(zod.enum(['DATE_TIME', 'START_PLACE']))
              .describe('What changed, for RIDE_UPDATED; empty otherwise'),
          })
          .describe("A notification in the current user's inbox")
      )
      .describe('The notifications of this page'),
    total: zod.int().describe('How many notifications match the query (unread only, if asked)'),
    unreadCount: zod.int().describe('How many notifications are unread, whatever the filter'),
    page: zod.int().describe('Page number (0-indexed)'),
    size: zod.int().describe('Page size applied'),
  })
  .describe("A page of the current user's notifications, newest first")

/**
 * A partial update: only the cells sent change. The full matrix is returned.
 * @summary Update my notification preferences
 */
export const updateMyNotificationPreferencesBodyPreferencesMax = 200

export const updateMyNotificationPreferencesBodyTeamsItemTeamSlugRegExp = new RegExp('\\S')
export const updateMyNotificationPreferencesBodyTeamsMax = 200

export const UpdateMyNotificationPreferencesBody = zod
  .object({
    preferences: zod
      .array(
        zod
          .object({
            type: zod
              .enum([
                'RIDE_PUBLISHED',
                'RIDE_CANCELLED',
                'TRIP_PUBLISHED',
                'TRIP_CANCELLED',
                'POST_PUBLISHED',
                'COMMENT_REPLY',
                'RIDE_REMINDER',
                'RIDE_UPDATED',
                'RIDE_GROUP_REMOVED',
                'RIDE_JOINED',
                'COMMENT_ON_MY_PUBLICATION',
                'TEAM_INVITATION',
                'CONTENT_REPORTED',
              ])
              .describe('Notification type'),
            channel: zod
              .enum(['IN_APP', 'EMAIL', 'PUSH'])
              .describe('Delivery channel. IN_APP is refused: the inbox is always on.'),
            enabled: zod.boolean().describe('Whether to deliver it'),
          })
          .describe('Switch one notification type on or off on one channel')
      )
      .max(updateMyNotificationPreferencesBodyPreferencesMax)
      .describe('The cells to change'),
    teams: zod
      .array(
        zod
          .object({
            teamSlug: zod
              .string()
              .regex(updateMyNotificationPreferencesBodyTeamsItemTeamSlugRegExp)
              .describe('Team slug — a team the user belongs to'),
            muted: zod.boolean().describe('Whether to mute its announcements'),
          })
          .describe("Mute or unmute one of the current user's teams")
      )
      .max(updateMyNotificationPreferencesBodyTeamsMax)
      .optional()
      .describe('The teams to mute or unmute'),
    emailDigest: zod
      .boolean()
      .optional()
      .describe('Switch the daily e-mail digest on or off; absent leaves it'),
  })
  .describe('Notification preference cells to change')

export const UpdateMyNotificationPreferencesResponse = zod
  .object({
    channels: zod
      .array(zod.enum(['IN_APP', 'EMAIL', 'PUSH']))
      .describe('Channels that can be configured on this server, in display order'),
    preferences: zod
      .array(
        zod
          .object({
            type: zod
              .enum([
                'RIDE_PUBLISHED',
                'RIDE_CANCELLED',
                'TRIP_PUBLISHED',
                'TRIP_CANCELLED',
                'POST_PUBLISHED',
                'COMMENT_REPLY',
                'RIDE_REMINDER',
                'RIDE_UPDATED',
                'RIDE_GROUP_REMOVED',
                'RIDE_JOINED',
                'COMMENT_ON_MY_PUBLICATION',
                'TEAM_INVITATION',
                'CONTENT_REPORTED',
              ])
              .describe('Notification type'),
            channel: zod.enum(['IN_APP', 'EMAIL', 'PUSH']).describe('Delivery channel'),
            enabled: zod.boolean().describe('Whether it is delivered, as currently in effect'),
            enabledByDefault: zod
              .boolean()
              .describe(
                "What applies when the user never touched this cell. Lets a client offer a 'restore defaults' without hard-coding them."
              ),
          })
          .describe('One cell of the notification preferences: a type on a channel')
      )
      .describe('One cell per type and configurable channel'),
    teams: zod
      .array(
        zod
          .object({
            teamSlug: zod.string().describe('Team slug'),
            teamName: zod.string().describe('Team name'),
            muted: zod
              .boolean()
              .describe(
                "Muted: none of the team's announcements (publications) reach the user, inbox included. What concerns them personally — a cancelled ride they joined, a reply — still does."
              ),
          })
          .describe('Whether the current user silenced one of their teams')
      )
      .describe(
        "The user's teams on this site, each with its mute switch. Offered whatever the channels: muting also keeps the team's announcements out of the inbox."
      ),
    emailDigest: zod
      .boolean()
      .describe(
        "Non-urgent e-mails are held and sent as one digest a day, at 7:00 in the user's time zone. Cancellations, changes and reminders still leave at once. Only meaningful when EMAIL is among the channels."
      ),
  })
  .describe("The current user's notification preferences")

/**
 * Every notification type on every channel this server can deliver on. The inbox is not listed: it always receives everything.
 * @summary Get my notification preferences
 */
export const GetMyNotificationPreferencesResponse = zod
  .object({
    channels: zod
      .array(zod.enum(['IN_APP', 'EMAIL', 'PUSH']))
      .describe('Channels that can be configured on this server, in display order'),
    preferences: zod
      .array(
        zod
          .object({
            type: zod
              .enum([
                'RIDE_PUBLISHED',
                'RIDE_CANCELLED',
                'TRIP_PUBLISHED',
                'TRIP_CANCELLED',
                'POST_PUBLISHED',
                'COMMENT_REPLY',
                'RIDE_REMINDER',
                'RIDE_UPDATED',
                'RIDE_GROUP_REMOVED',
                'RIDE_JOINED',
                'COMMENT_ON_MY_PUBLICATION',
                'TEAM_INVITATION',
                'CONTENT_REPORTED',
              ])
              .describe('Notification type'),
            channel: zod.enum(['IN_APP', 'EMAIL', 'PUSH']).describe('Delivery channel'),
            enabled: zod.boolean().describe('Whether it is delivered, as currently in effect'),
            enabledByDefault: zod
              .boolean()
              .describe(
                "What applies when the user never touched this cell. Lets a client offer a 'restore defaults' without hard-coding them."
              ),
          })
          .describe('One cell of the notification preferences: a type on a channel')
      )
      .describe('One cell per type and configurable channel'),
    teams: zod
      .array(
        zod
          .object({
            teamSlug: zod.string().describe('Team slug'),
            teamName: zod.string().describe('Team name'),
            muted: zod
              .boolean()
              .describe(
                "Muted: none of the team's announcements (publications) reach the user, inbox included. What concerns them personally — a cancelled ride they joined, a reply — still does."
              ),
          })
          .describe('Whether the current user silenced one of their teams')
      )
      .describe(
        "The user's teams on this site, each with its mute switch. Offered whatever the channels: muting also keeps the team's announcements out of the inbox."
      ),
    emailDigest: zod
      .boolean()
      .describe(
        "Non-urgent e-mails are held and sent as one digest a day, at 7:00 in the user's time zone. Cancellations, changes and reminders still leave at once. Only meaningful when EMAIL is among the channels."
      ),
  })
  .describe("The current user's notification preferences")

/**
 * @summary Mark all my notifications read
 */
export const MarkAllNotificationsReadResponse = zod.void()

/**
 * The badge on the bell. Cheap by design: clients poll it (on focus, at most once a minute) rather than reloading the list.
 * @summary Count my unread notifications
 */
export const CountMyUnreadNotificationsResponse = zod
  .object({
    count: zod.int().describe('Unread notifications'),
  })
  .describe('Number of unread notifications — the badge on the bell')

/**
 * Idempotent: marking an already-read notification read succeeds.
 * @summary Mark a notification read
 */
export const MarkNotificationReadParams = zod.object({
  notificationId: zod.string(),
})

export const MarkNotificationReadResponse = zod.void()

/**
 * Called at every app launch and whenever FCM rotates the token. Idempotent: a token already known is refreshed, and moved to the current user if it was someone else's.
 * @summary Register a device for push notifications
 */
export const registerPushDeviceBodyTokenMax = 512

export const registerPushDeviceBodyTokenRegExp = new RegExp('\\S')
export const registerPushDeviceBodyDeviceNameMax = 120

export const registerPushDeviceBodyAppVersionMax = 40

export const RegisterPushDeviceBody = zod
  .object({
    token: zod
      .string()
      .max(registerPushDeviceBodyTokenMax)
      .regex(registerPushDeviceBodyTokenRegExp)
      .describe(
        'The FCM registration token. Registering a token already known moves it to the current user and refreshes its last-seen date.'
      ),
    platform: zod.enum(['ANDROID', 'IOS', 'WEB']).describe("The device's platform"),
    deviceName: zod
      .string()
      .max(registerPushDeviceBodyDeviceNameMax)
      .optional()
      .describe("A human-readable device name, for the member's own device list"),
    appVersion: zod
      .string()
      .max(registerPushDeviceBodyAppVersionMax)
      .optional()
      .describe('The app version that registered, for support'),
  })
  .describe('A device to receive push notifications on')

export const RegisterPushDeviceResponse = zod.void()

/**
 * Called on sign-out. Idempotent, and silent about tokens that are not the caller's. The token is in the body so that it never reaches the access log.
 * @summary Stop sending push notifications to a device
 */
export const unregisterPushDeviceBodyTokenMax = 512

export const unregisterPushDeviceBodyTokenRegExp = new RegExp('\\S')

export const UnregisterPushDeviceBody = zod
  .object({
    token: zod
      .string()
      .max(unregisterPushDeviceBodyTokenMax)
      .regex(unregisterPushDeviceBodyTokenRegExp)
      .describe('The FCM registration token to drop'),
  })
  .describe('A device to stop sending push notifications to')

export const UnregisterPushDeviceResponse = zod.void()
