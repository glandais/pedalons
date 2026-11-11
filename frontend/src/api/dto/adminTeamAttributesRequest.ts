import type { TeamTier } from './teamTier.ts'

/**
 * Platform admin request to update team governance attributes
 */
export interface AdminTeamAttributesRequest {
  /** Whether team admins can change visibility */
  visibilityEditable: boolean
  /** Whether any domain user can join this public team */
  joinable: boolean
  /** Whether team admins can add members */
  addMemberAllowed: boolean
  /** Whether the interactive route planner is open to this team */
  enableRoutePlanner: boolean
  /** Whether a private team may publish content as public or unlisted, readable by link only and kept out of every listing. Omitted: left as it is (off for a new team). */
  publicContentAllowed?: boolean
  /** The team's plan: FREE caps the members and the route planner saves, UNLOCKED lifts both caps. Omitted: left as it is (FREE for a new team). */
  tier?: TeamTier
  /**
   * Why the team has its plan, for the platform admin only (« club pilote », « offert par … »). Omitted: left as it is; blank clears it.
   * @maxLength 500
   */
  tierNote?: string
}
