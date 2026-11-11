import type { Instant } from './instant.ts'
import type { TeamTier } from './teamTier.ts'
import type { Visibility } from './visibility.ts'

/**
 * Admin team view with domain info
 */
export interface AdminTeamDto {
  /** Team ID (TSID) */
  id: string
  /** Team name */
  name: string
  /** Team URL slug */
  slug: string
  /** Domain ID this team belongs to */
  domainId: string
  /** Domain hostname */
  domainName: string
  /** Team visibility */
  visibility: Visibility
  /** Whether visibility is editable by team admins */
  visibilityEditable: boolean
  /** Whether any domain user can join this team */
  joinable: boolean
  /** Whether team admins can add members */
  addMemberAllowed: boolean
  /** Whether the interactive route planner is open to this team */
  enableRoutePlanner: boolean
  /** Whether a private team may publish content as public or unlisted, readable by link only and kept out of every listing */
  publicContentAllowed: boolean
  /** The team's plan: FREE caps the members and the route planner saves, UNLOCKED lifts both caps */
  tier: TeamTier
  /** Why the team has its plan, for the platform admin only */
  tierNote?: string
  /** Is team soft-deleted */
  deleted: boolean
  /** Number of members */
  memberCount: number
  /** Team creation timestamp */
  createdAt: Instant
}
