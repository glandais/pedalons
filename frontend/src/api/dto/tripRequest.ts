import type { EventDateTime } from './eventDateTime.ts'
import type { MediaDto } from './mediaDto.ts'
import type { StageRequest } from './stageRequest.ts'
import type { Status } from './status.ts'
import type { Visibility } from './visibility.ts'

/**
 * Trip request
 */
export interface TripRequest {
  /**
   * Trip name
   * @minLength 1
   * @maxLength 200
   * @pattern \S
   */
  name: string
  /** Trip media */
  media: MediaDto
  /** Trip start date/time: a wall time without offset, read in the trip's zone (first stage, else route, else team). */
  dateTime: EventDateTime
  /** Trip status */
  status: Status
  /** Visibility level */
  visibility: Visibility
  /** Overall route slug for the trip */
  routeSlug?: string
  /** Publication time (for scheduled publishing), a wall time in the trip's zone like dateTime. */
  publishAt?: EventDateTime
  /** Trip stages to create */
  stages: StageRequest[]
  /** IDs (TSID) of the team's TRIP tags the trip carries, replacing the whole set — at most 10, each a tag of this team and of kind TRIP, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update. */
  tagIds?: string[]
  /** When the trip is not TEAM and uses TEAM routes (its own, its stages'), the save is refused with INCOMPATIBLE_VISIBILITY, listing them. Replayed with true, it raises those routes to PUBLIC_UNLISTED in the same transaction, then saves. Omitted or false: refused as before. */
  alignVisibility?: boolean
}
