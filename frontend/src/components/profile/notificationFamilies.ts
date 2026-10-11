import { NotificationType } from '@/api/dto'
import type { NotificationChannel, NotificationPreferencesDto } from '@/api/dto'
import { tRegister, type TranslationKey } from '@/lib/i18nUtils'

export interface NotificationFamily {
  /** i18n key of the family's heading. */
  labelKey: TranslationKey
  types: NotificationType[]
}

/**
 * The rows of the notification settings, grouped by family — the same families, in the same order,
 * as the app's list. Not the enum's order, which is the order the types were added in. Every type
 * belongs to exactly one family (notificationFamilies.test.ts): a type left out would get no row.
 */
export const NOTIFICATION_FAMILIES: NotificationFamily[] = [
  {
    labelKey: tRegister('notifications.family.rides'),
    types: [
      NotificationType.RIDE_PUBLISHED,
      NotificationType.RIDE_UPDATED,
      NotificationType.RIDE_CANCELLED,
      NotificationType.RIDE_GROUP_REMOVED,
      NotificationType.RIDE_REMINDER,
      NotificationType.RIDE_JOINED,
    ],
  },
  {
    labelKey: tRegister('notifications.family.trips'),
    types: [NotificationType.TRIP_PUBLISHED, NotificationType.TRIP_CANCELLED],
  },
  {
    labelKey: tRegister('notifications.family.posts'),
    types: [
      NotificationType.POST_PUBLISHED,
      NotificationType.COMMENT_ON_MY_PUBLICATION,
      NotificationType.COMMENT_REPLY,
    ],
  },
  {
    labelKey: tRegister('notifications.family.teams'),
    types: [NotificationType.TEAM_INVITATION, NotificationType.CONTENT_REPORTED],
  },
]

/** The server's setting of `type` on `channel`, or undefined when it lists none. */
export function cellOf(
  preferences: NotificationPreferencesDto,
  type: NotificationType,
  channel: NotificationChannel
) {
  return preferences.preferences.find((cell) => cell.type === type && cell.channel === channel)
}

/**
 * The families as the settings show them: a type gets a row only when the server lists a cell for
 * it on one of the channels it declares, and a family left without rows has no heading.
 */
export function familiesWithRows(preferences: NotificationPreferencesDto): NotificationFamily[] {
  return NOTIFICATION_FAMILIES.map((family) => ({
    ...family,
    types: family.types.filter((type) =>
      preferences.channels.some((channel) => cellOf(preferences, type, channel))
    ),
  })).filter((family) => family.types.length > 0)
}
