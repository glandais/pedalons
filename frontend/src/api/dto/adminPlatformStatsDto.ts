import type { AdminAuthMethodStatsDto } from './adminAuthMethodStatsDto.ts'
import type { AdminCalendarStatsDto } from './adminCalendarStatsDto.ts'
import type { AdminGpsServiceStatsDto } from './adminGpsServiceStatsDto.ts'
import type { AdminKeyCountDto } from './adminKeyCountDto.ts'
import type { AdminMonthCountDto } from './adminMonthCountDto.ts'
import type { AdminPasskeyStatsDto } from './adminPasskeyStatsDto.ts'
import type { AdminPushPlatformStatsDto } from './adminPushPlatformStatsDto.ts'
import type { AdminTeamStatsDto } from './adminTeamStatsDto.ts'
import type { AdminUserStatsDto } from './adminUserStatsDto.ts'
import type { Instant } from './instant.ts'

/**
 * Usage statistics of the platform or of one domain, for the platform administration. Counts only: no row names or identifies anyone. Deleted accounts and deleted domains are left out unless a field says otherwise.
 */
export interface AdminPlatformStatsDto {
  /** When the figures were computed */
  generatedAt: Instant
  /** The domain the figures are limited to; absent: all domains */
  domainId?: string
  users: AdminUserStatsDto
  authMethods: AdminAuthMethodStatsDto
  passkeys: AdminPasskeyStatsDto
  /** Accounts created per calendar month (UTC), the last 12 months, the current one included, oldest first, months without any included */
  signupsByMonth: AdminMonthCountDto[]
  teams: AdminTeamStatsDto
  gpsServices: AdminGpsServiceStatsDto[]
  /** Accounts with a connection to any GPS service */
  usersWithGpsService: number
  pushDevices: AdminPushPlatformStatsDto[]
  /** Distinct accounts per kind of client among the sessions used during the last 30 days. Keys: MOBILE_APP (the Pédalons app), OAUTH (a third-party application authorised through OAuth), the lowercase device client of a paired device (garmin, karoo), WEB_MOBILE (a browser on a phone or tablet), WEB_DESKTOP (any other browser). An account counts once per kind, so the total can exceed the number of accounts. */
  clientsLast30Days: AdminKeyCountDto[]
  calendarFeeds: AdminCalendarStatsDto
}
