import type { Instant } from './instant.ts'
import type { MediaDto } from './mediaDto.ts'
import type { PostDtoType } from './postDtoType.ts'
import type { PublicUserDto } from './publicUserDto.ts'
import type { Status } from './status.ts'
import type { TagDto } from './tagDto.ts'
import type { TeamPublicationDto } from './teamPublicationDto.ts'
import type { Visibility } from './visibility.ts'

/**
 * Post summary data
 */
export interface PostDto {
  type: PostDtoType
  /** Team */
  team: TeamPublicationDto
  /** Publication ID (TSID) */
  id: string
  /** Publication URL slug */
  slug: string
  /** Publication name */
  name: string
  /** Publication media */
  media: MediaDto
  /** Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter. */
  excerpt?: string
  /** URL template of the post's first image, the one a card shows. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only. */
  thumbnailUrl?: string
  /** Publication date/time */
  dateTime: Instant
  /** IANA zone the post's times were entered in and read in: the team's at its last save. dateTime, publishAt are rendezvous in this zone. */
  timezone: string
  /** Publication status */
  status: Status
  /** Visibility level */
  visibility: Visibility
  /** Publication timestamp */
  publishAt?: Instant
  /** Creation timestamp */
  createdAt?: Instant
  /** Whether the post is soft-deleted */
  deleted: boolean
  /** Number of comments, replies included. Absent when the caller may not read the comments of this post — comments are members-only, so an outsider is told nothing, not even zero. */
  commentCount?: number
  /** Whether the post is signed by the team rather than by its author. Readers are then not told who wrote it: createdBy is absent unless the caller administers the team or wrote the post. */
  signedAsTeam: boolean
  /** Who wrote the post. Absent when the caller is not a member of the team — member names are never sent to anyone else — and when the post is signed by the team (signedAsTeam) and the caller neither administers the team nor wrote it: render the team instead. */
  createdBy?: PublicUserDto
  /** The team's POST tags the post carries, sorted by label. Empty when it carries none. */
  tags: TagDto[]
}
