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
  /** URL template of the team's logo (with a {size} placeholder), when it has one. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team. Opaque URL: may carry a query string; substitute {size} only. */
  logoUrl?: string
}
