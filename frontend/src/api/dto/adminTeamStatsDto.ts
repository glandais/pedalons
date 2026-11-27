import type { AdminKeyCountDto } from './adminKeyCountDto.ts'

/**
 * Teams and memberships
 */
export interface AdminTeamStatsDto {
  /** Teams that are not deleted */
  active: number
  /** Teams deleted */
  deleted: number
  /** Active teams per plan (FREE, UNLOCKED…) */
  byTier: AdminKeyCountDto[]
  /** Memberships per role (MEMBER, ORGANIZER, ADMIN), active teams and accounts that are not deleted */
  membershipsByRole: AdminKeyCountDto[]
  /** Accounts that are not deleted per number of active teams they belong to: keys "0", "1", "2", "3+" */
  usersByTeamCount: AdminKeyCountDto[]
}
