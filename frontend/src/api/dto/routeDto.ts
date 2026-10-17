import type { Instant } from './instant.ts'
import type { MediaDto } from './mediaDto.ts'
import type { SurfaceType } from './surfaceType.ts'
import type { TagDto } from './tagDto.ts'
import type { TeamPublicationDto } from './teamPublicationDto.ts'
import type { Visibility } from './visibility.ts'

/**
 * Route summary data
 */
export interface RouteDto {
  /** Route ID (TSID) */
  id: string
  /** Route slug */
  slug: string
  /** Team */
  team: TeamPublicationDto
  /** Route name */
  name: string
  /** Route description */
  media: MediaDto
  /** Plain-text opening of the description, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the description holds no text. Lets a list row render its two lines without the description being sent at all — see the 'view' parameter. */
  excerpt?: string
  /** URL template of the route's thumbnail, light variant if there is one, else dark. Saves a compact row from carrying media.assets just to find the map preview. Opaque URL: may carry a query string; substitute {size} only. */
  thumbnailUrl?: string
  /** Distance in meters */
  distance: number
  /** Total elevation gain in meters */
  elevationGain: number
  /** Total elevation loss in meters */
  elevationLoss: number
  /** Surface type */
  surfaceType: SurfaceType
  /** Whether the route is public */
  visibility: Visibility
  /** Creation timestamp */
  createdAt: Instant
  /** Whether the route is soft-deleted */
  deleted: boolean
  /** Number of comments, replies included. Absent when the caller may not read the comments of this route — comments are members-only, so an outsider is told nothing, not even zero. */
  commentCount?: number
  /** The team's ROUTE tags the route carries, sorted by label. Empty when it carries none. */
  tags: TagDto[]
}
