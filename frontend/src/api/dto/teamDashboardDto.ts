import type { AdListResponse } from './adListResponse.ts'
import type { PublicationListResponse } from './publicationListResponse.ts'
import type { RouteListResponse } from './routeListResponse.ts'
import type { TeamDashboardAdminDto } from './teamDashboardAdminDto.ts'
import type { TeamDashboardOrganizerDto } from './teamDashboardOrganizerDto.ts'
import type { TeamDetailDto } from './teamDetailDto.ts'
import type { TeamRole } from './teamRole.ts'

/**
 * A team's dashboard for one of its members, or its public part for a visitor. Each section is a short page (at most 5 rows) of the matching list, compact rows, deleted content left out; its total is what the full list holds. A section is null when its module is disabled for the team. The organizer block is null for a MEMBER, the admin block null below ADMIN. For a visitor (role null) only team, upcomingRides, latestPosts and newRoutes are filled.
 */
export interface TeamDashboardDto {
  /** The team, as GET /api/teams/{teamSlug} returns it — header, feature flags, memberCount; memberCountByRole is filled for an administrator. */
  team: TeamDetailDto
  /** The caller's real role in the team; null for a visitor, anonymous or not a member — a platform admin who is not a member included. The organizer and admin blocks are what a platform admin's rights add. */
  role?: TeamRole
  /** « Vos prochaines sorties »: the team's rides and trips starting from now that the caller is registered to, soonest first (at most 3). A ride row's registeredGroup is the group joined, with its pace. Null when both rides and trips are disabled, and for a visitor. */
  myUpcoming?: PublicationListResponse
  /** « Sorties à venir »: the team's published rides starting from now, soonest first (at most 3). Each row carries groupSummaries (fill per group), distance, elevationGain, surfaceType, registered and commentCount. Null when rides are disabled. */
  upcomingRides?: PublicationListResponse
  /** « Dernières publications »: the team's latest published posts, newest first (at most 3). Null when posts are disabled. */
  latestPosts?: PublicationListResponse
  /** « Nouveaux parcours »: the team's latest routes, newest first (at most 3). Null when routes are disabled. */
  newRoutes?: RouteListResponse
  /** « Annonces »: the team's latest ads, newest first (at most 3). A null price reads « Prix à négocier »; the place is locationDescription, a sector — never a pin. Null when ads are disabled, and for a visitor. */
  latestAds?: AdListResponse
  /** What organizers and administrators see on top. Null for a MEMBER and a visitor; filled for a platform admin, member or not. */
  organizer?: TeamDashboardOrganizerDto
  /** The administration panel. Null below ADMIN, and for a visitor; filled for a platform admin, member or not. */
  admin?: TeamDashboardAdminDto
}
