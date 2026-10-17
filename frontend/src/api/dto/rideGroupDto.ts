import type { Instant } from './instant.ts'
import type { LocalTime } from './localTime.ts'
import type { PublicUserDto } from './publicUserDto.ts'

/**
 * Ride group information
 */
export interface RideGroupDto {
  /** Group ID (TSID) */
  id: string
  /** Group name */
  name: string
  /** Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time. */
  time?: LocalTime
  /** When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own. */
  startAt: Instant
  /** Route slug */
  routeSlug?: string
  /** Average speed in km/h */
  averageSpeed?: number
  /** Maximum participants */
  maxParticipants?: number
  /** Current number of participants */
  countParticipants: number
  /** The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=. */
  participants: PublicUserDto[]
  /** Sort order */
  sortOrder: number
  /** Whether the current user is registered in THIS group. False if anonymous. */
  registered: boolean
  /** Whether the group has reached maxParticipants. False when maxParticipants is not set. */
  full: boolean
  /** Distance in meters of the group route, if it has one */
  distance?: number
  /** Total elevation gain in meters of the group route, if it has one */
  elevationGain?: number
  /** The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride. */
  leader?: PublicUserDto
  /** Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only. */
  thumbnailLightUrl?: string
  /** Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only. */
  thumbnailDarkUrl?: string
  /** The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only. */
  thumbnailUrl?: string
}
