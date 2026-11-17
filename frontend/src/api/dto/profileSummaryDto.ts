import type { PairedDeviceDto } from './pairedDeviceDto.ts'
import type { ProfileNotificationSummaryDto } from './profileNotificationSummaryDto.ts'
import type { ProfileTeamDto } from './profileTeamDto.ts'

/**
 * The state of each subject of the current user's profile, for its overview
 */
export interface ProfileSummaryDto {
  /** The user's teams on this site, in name order, each with the user's role in it */
  teams: ProfileTeamDto[]
  /** Number of passkeys registered on the account */
  passkeyCount: number
  /** Devices (Karoo, Garmin) paired with the account, newest first — the same rows as GET /api/users/me/devices */
  pairedDevices: PairedDeviceDto[]
  /** Number of live accounts the user blocked */
  blockedUserCount: number
  /** Where the user's notifications go */
  notifications: ProfileNotificationSummaryDto
}
