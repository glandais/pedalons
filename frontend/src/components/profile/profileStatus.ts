import type { TFunction } from 'i18next'
import type {
  GpsServiceType,
  PairedDeviceType,
  ProfileSummaryDto,
  ThemePreference,
  UnitSystem,
  UserDto,
} from '@/api/dto'
import { NotificationChannel } from '@/api/dto'
import { languageNames, type SupportedLanguage } from '@/i18n'
import type { ProfileSection } from './profileNav'

/**
 * The state line of each subject of the profile overview: what the member will find behind the
 * shortcut, before opening it.
 *
 * Read from `GET /api/users/me` (display preferences, contact, connected services) and
 * `GET /api/users/me/profile-summary` (everything else) — the overview's two calls. A subject the
 * summary carries reads `undefined` until it lands, and the row shows no line rather than a guess.
 *
 * The timezone shows only when the member chose one: the zone the site falls back to is the
 * browser's, which the server rendering the page cannot know.
 */
export function profileStatusLines(
  t: TFunction,
  user: UserDto,
  summary: ProfileSummaryDto | undefined,
  language: string
): Partial<Record<ProfileSection, string>> {
  const join = (parts: (string | false | undefined | null)[]) =>
    parts.filter((part): part is string => !!part).join(' · ')

  const unit: UnitSystem = user.unitSystem ?? 'METRIC'
  const theme: ThemePreference = user.theme ?? 'SYSTEM'
  const languageName = languageNames[language as SupportedLanguage] ?? language

  const lines: Partial<Record<ProfileSection, string>> = {
    preferences: join([
      t(`profile.status.unit.${unit satisfies UnitSystem}`),
      user.timezone,
      t(`profile.status.theme.${theme satisfies ThemePreference}`),
      languageName,
    ]),
    privacy: join([
      user.contactableByMembers
        ? t('profile.status.contactable')
        : t('profile.status.notContactable'),
      summary &&
        summary.blockedUserCount > 0 &&
        t('profile.status.blocked', { count: summary.blockedUserCount }),
    ]),
    account: t('profile.status.account'),
    help: t('profile.status.help'),
  }

  if (summary) {
    lines.notifications = notificationLine(t, summary)
    lines.security =
      summary.passkeyCount === 0
        ? t('profile.status.noPasskey')
        : t('profile.status.passkeys', { count: summary.passkeyCount })
  }
  lines.devices = devicesLine(t, user, summary)

  return lines
}

function notificationLine(t: TFunction, summary: ProfileSummaryDto): string {
  const { enabledChannels, emailDigest } = summary.notifications
  const email = enabledChannels.includes(NotificationChannel.EMAIL)
  const push = enabledChannels.includes(NotificationChannel.PUSH)
  const channels =
    email && push
      ? t('profile.status.notifications.emailAndPush')
      : email
        ? t('profile.status.notifications.email')
        : push
          ? t('profile.status.notifications.push')
          : t('profile.status.notifications.inAppOnly')
  // The digest only holds e-mails back; the summary already says false without an e-mail channel.
  return emailDigest && email
    ? `${channels} · ${t('profile.status.notifications.digest')}`
    : channels
}

function devicesLine(
  t: TFunction,
  user: UserDto,
  summary: ProfileSummaryDto | undefined
): string | undefined {
  // A service that receives the rides' routes on its own says so (docs/LEDGER_*.md WEB-92).
  const services = (user.connectedServices ?? []).map((connection) =>
    t(connection.autoSync ? 'profile.status.serviceAutoSync' : 'profile.status.serviceConnected', {
      service: t(
        `gps.services.${connection.serviceType.toLowerCase() as Lowercase<GpsServiceType>}`
      ),
    })
  )
  if (!summary) return services.length > 0 ? services.join(' · ') : undefined

  // One count per kind of device, in the order the list first names them.
  const counts = new Map<PairedDeviceType, number>()
  for (const device of summary.pairedDevices) {
    counts.set(device.type, (counts.get(device.type) ?? 0) + 1)
  }
  const devices = [...counts].map(([type, count]) =>
    t('profile.status.devicePaired', {
      count,
      device: t(`gps.devices.types.${type.toLowerCase() as Lowercase<PairedDeviceType>}`),
    })
  )
  const parts = [...services, ...devices]
  return parts.length > 0 ? parts.join(' · ') : t('profile.status.noDevice')
}
