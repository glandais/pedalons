import type { RideTemplateGroupRequest } from './rideTemplateGroupRequest.ts'
import type { Status } from './status.ts'
import type { Visibility } from './visibility.ts'

/**
 * Ride template request
 */
export interface RideTemplateRequest {
  /**
   * Template name
   * @minLength 1
   * @maxLength 200
   * @pattern \S
   */
  name: string
  /**
   * Template description (markdown)
   * @maxLength 100000
   */
  markdown: string
  /** Visibility level */
  visibility: Visibility
  /** Default status for rides created from this template */
  status: Status
  /** Template groups */
  groups: RideTemplateGroupRequest[]
  /** IDs (TSID) of the team's RIDE tags the template carries (copied onto the rides created from it), replacing the whole set — at most 10, each a tag of this team and of kind RIDE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update. */
  tagIds?: string[]
  /**
   * The number the next ride created from this template takes: a client titles it « name #nextNumber » and the creation of that ride (RideRequest.templateId) raises it by one. Null: the template numbers nothing.
   * @minimum 0
   */
  nextNumber?: number
}
