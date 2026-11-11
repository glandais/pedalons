import type { TeamMemberLimitDetailsType } from './teamMemberLimitDetailsType.ts'

export interface TeamMemberLimitDetails {
  type: TeamMemberLimitDetailsType
  /** Member cap of the team's tier */
  limit: number
  /** What was counted against the cap: active members, plus pending invitations when sending one */
  current: number
}
