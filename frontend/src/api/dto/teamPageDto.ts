import type { ContentPermissionsDto } from './contentPermissionsDto.ts'
import type { MediaDto } from './mediaDto.ts'
import type { TeamPublicationDto } from './teamPublicationDto.ts'
import type { Visibility } from './visibility.ts'

/**
 * Team page detail
 */
export interface TeamPageDto {
  /** Team */
  team: TeamPublicationDto
  /** Page ID (TSID) */
  id: string
  /** Page title */
  title: string
  /** Page URL slug */
  slug: string
  /** Page content */
  media: MediaDto
  /** Visibility level */
  visibility: Visibility
  /** Page order */
  order: number
  /** Whether the page is soft-deleted */
  deleted: boolean
  /** What the caller may do with the page: edit, delete (never the about page), and the visibilities it may be saved with. */
  permissions: ContentPermissionsDto
}
