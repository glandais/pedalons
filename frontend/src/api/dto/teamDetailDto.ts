import type { Instant } from './instant.ts'
import type { MediaDto } from './mediaDto.ts'
import type { MemberCountByRoleDto } from './memberCountByRoleDto.ts'
import type { TeamDetailDtoGeometry } from './teamDetailDtoGeometry.ts'
import type { TeamPageSummaryDto } from './teamPageSummaryDto.ts'
import type { TeamRole } from './teamRole.ts'
import type { Visibility } from './visibility.ts'

/**
 * Detailed team information
 */
export interface TeamDetailDto {
  /** Team ID (TSID) */
  id: string
  /** Team name */
  name: string
  /** Team URL slug */
  slug: string
  /** About page content */
  about: MediaDto
  /** Plain-text opening of the about page, flattened and cut on a word boundary at about 200 characters. Null when the about page holds no text. Lets a team card render its two lines without parsing the markdown client-side. */
  excerpt?: string
  /** URL template of the team's logo, when it has one. Same picture as about.assets.logo, hoisted so a card does not have to walk the asset inventory to find it. Opaque URL: may carry a query string; substitute {size} only. */
  logoUrl?: string
  /** Additional team pages */
  pages?: TeamPageSummaryDto[]
  /** Whether the team is public */
  visibility: Visibility
  /** Trips enabled */
  enableTrips: boolean
  /** Ads enabled */
  enableAds: boolean
  /** Posts enabled */
  enablePosts: boolean
  /** Rides enabled */
  enableRides: boolean
  /** Routes enabled */
  enableRoutes: boolean
  /** Whether the member directory is readable by every member and not just by administrators. Clients use it to decide whether to offer the directory at all: an entry that always leads to a 403 is worse than no entry. Organisers see the directory whatever its value, but only get each member's role and join date when it is true. */
  enableMemberDirectory: boolean
  /** Whether a new post starts signed by the team rather than by its author — the initial value of the editor's « on behalf of the team » box. */
  postsAsTeamByDefault: boolean
  /** Whether visibility is editable by team admins */
  visibilityEditable: boolean
  /** Whether any domain user can join this team */
  joinable: boolean
  /** Whether team admins can add members */
  addMemberAllowed: boolean
  /** Whether the interactive route planner is open to this team. Unlike enableRoutes it never hides the routes section: when false the track can still be imported or replaced from a GPX file, only drawing is closed. Platform-admin only. */
  enableRoutePlanner: boolean
  /** Number of team members */
  memberCount: number
  /** Rides of this team dated in the future that the caller may open. Follows the same visibility rules as the ride listing, so it never announces more than the caller can actually see. */
  upcomingRideCount: number
  /** Routes of this team the caller may open, under the same visibility rules as the route listing. */
  routeCount: number
  /** Trips of this team starting in the future that the caller may open, under the same visibility rules as the trip listing. 0 when trips are disabled. */
  upcomingTripCount: number
  /** Published posts of this team dated within the last 7 days (and not in the future) that the caller may open, under the same visibility rules as the post listing. Feeds the activity line of a member's team card. 0 when posts are disabled. */
  recentPostCount: number
  /** Members per role. Only for the team's administrators (platform admins included): null for everyone else, and in the team listings. */
  memberCountByRole?: MemberCountByRoleDto
  /** Current user's role (null if not a member) */
  role?: TeamRole
  /** Team creation timestamp */
  createdAt: Instant
  /** Team location coordinates [longitude, latitude] */
  geometry?: TeamDetailDtoGeometry
  /** The team's IANA zone: the one its rides, trips and posts fall back on when no place locates them. Administrators change it through TeamRequest.timezone. */
  timezone: string
}
