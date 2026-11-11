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
}
