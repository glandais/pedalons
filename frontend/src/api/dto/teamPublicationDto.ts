import type { Visibility } from './visibility.ts'

/**
 * Team information
 */
export interface TeamPublicationDto {
  /** Team ID (TSID) */
  id: string
  /** Team name */
  name: string
  /** Team URL slug */
  slug: string
  /** Whether the team is public */
  visibility: Visibility
  /** URL template of the team's logo (with a {size} placeholder), when it has one and the caller may download it. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team. Absent when accessible is false and the private team does not publish content by link: its logo is then closed to the caller. Opaque URL: may carry a query string; substitute {size} only. */
  logoUrl?: string
  /** Whether GET team answers the caller: the team is not private, or the caller is a member of it or a platform admin. A client loads the team, links to it or shows its header only when true; otherwise it renders this summary. The public content of a private team is read by link with this false. */
  accessible: boolean
}
