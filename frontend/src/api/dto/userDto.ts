import type { GpsServiceConnectionDto } from './gpsServiceConnectionDto.ts'
import type { Instant } from './instant.ts'
import type { PlannerQuotaDto } from './plannerQuotaDto.ts'
import type { PlatformRole } from './platformRole.ts'
import type { ThemePreference } from './themePreference.ts'
import type { UnitSystem } from './unitSystem.ts'

/**
 * User profile data
 */
export interface UserDto {
  /** User ID (TSID) */
  id: string
  /** User email address */
  email: string
  /** User display name */
  displayName: string
  /** User avatar URL */
  avatarUrl?: string
  /** Account creation timestamp */
  createdAt?: Instant
  /** Preferred unit system (metric or imperial) */
  unitSystem?: UnitSystem
  /** Preferred colour scheme. Null means the user never chose one — distinct from SYSTEM, which they did choose — so a client is free to follow the device. */
  theme?: ThemePreference
  /** Preferred language as a BCP-47 tag. Null means the user never chose one; the client then follows the device or the domain. */
  language?: string
  /** Preferred IANA timezone (e.g. 'Europe/Paris'). Null means the user never chose one; the client then follows the browser. */
  timezone?: string
  /** Whether team members may reach this user through the classified-ad relay. True unless they explicitly opted out, so an account that predates the preference is contactable. */
  contactableByMembers: boolean
  /** Platform role (null if regular user) */
  platformRole?: PlatformRole
  /** Whether the account's email has been verified */
  emailVerified: boolean
  /** Connected GPS services */
  connectedServices?: GpsServiceConnectionDto[]
  /** Where the user's personal route planner quota stands this month: the saves of a track drawn on the map in the GPX tools (docs/LEDGER_*.md BILL-10). limit is null — unlimited — for a member of an unlocked team of this site. Clients show no counter; they close « create a route » in the GPX tools when used >= limit already. */
  plannerQuota: PlannerQuotaDto
}
