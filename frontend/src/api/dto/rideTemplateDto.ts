import type { Instant } from './instant.ts'
import type { RideTemplateGroupDto } from './rideTemplateGroupDto.ts'
import type { Status } from './status.ts'
import type { TagDto } from './tagDto.ts'
import type { TeamPublicationDto } from './teamPublicationDto.ts'
import type { Visibility } from './visibility.ts'

/**
 * Ride template response
 */
export interface RideTemplateDto {
  /** Team */
  team: TeamPublicationDto
  /** Template ID (TSID) */
  id: string
  /** Template slug */
  slug: string
  /** Template name */
  name: string
  /** Template description (markdown) */
  markdown: string
  /** Visibility level */
  visibility: Visibility
  /** Default status */
  status: Status
  /** Creation timestamp */
  createdAt: Instant
  /** Last update timestamp */
  updatedAt: Instant
  /** Number of groups */
  groupCount: number
  /** Template groups */
  groups: RideTemplateGroupDto[]
  /** The team's RIDE tags of the template, sorted by label. Copied onto a ride created from it: a client prefills the ride's tagIds with them, editable before and after. */
  tags: TagDto[]
  /** The number the next ride created from this template takes: a client prefills the ride's name with « name #nextNumber » and sends RideRequest.templateId, which raises it by one. Null: the template numbers nothing. */
  nextNumber?: number
}
