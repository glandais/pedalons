import type { Instant } from './instant.ts'
import type { MediaDto } from './mediaDto.ts'
import type { PublicUserDto } from './publicUserDto.ts'
import type { RideWeatherSummaryDto } from './rideWeatherSummaryDto.ts'
import type { Status } from './status.ts'
import type { TagDto } from './tagDto.ts'
import type { TeamPublicationDto } from './teamPublicationDto.ts'
import type { TripDtoType } from './tripDtoType.ts'
import type { TripStageDto } from './tripStageDto.ts'
import type { Visibility } from './visibility.ts'

/**
 * Trip data
 */
export interface TripDto {
  type: TripDtoType
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
  /** Trip start date/time */
  dateTime: Instant
  /** IANA zone the trip's times were entered in and read in: its first stage's, else its route's, else the team's. dateTime, endDate, endDateTime and publishAt are rendezvous in this zone. */
  timezone: string
  /** Date of the last stage — the day the trip ends. Null when the trip has no stage, in which case it lasts a day and dateTime is both ends. */
  endDate?: Instant
  /** When the trip is over, computed by the server: the end of its latest stage — its departure plus its route's length at its average speed, or plus 3 hours when the stage has no speed or no route — or dateTime plus 3 hours for a trip with no stage. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read. */
  endDateTime: Instant
  /** Publication status */
  status: Status
  /** Whether the trip is over, computed by the server when the response is built: its last stage (endDate, or dateTime when there is none) has started. Independent of status — a past cancelled trip is both CANCELLED and finished. */
  finished: boolean
  /** Visibility level */
  visibility: Visibility
  /** Publication timestamp */
  publishAt?: Instant
  /** Creation timestamp */
  createdAt?: Instant
  /** Route slug */
  routeSlug?: string
  /** Number of participants */
  participantCount: number
  /** Number of stages */
  stageCount: number
  /** Distance in metres over every stage that has a route. Null when no stage has one — an unrouted trip has no distance, which is not the same as a distance of zero. */
  totalDistance?: number
  /** Elevation gain in metres over every stage that has a route. Null when no stage has one. */
  totalElevationGain?: number
  /** Trip stages */
  stages: TripStageDto[]
  /** The first participants of the trip (at most 8), earliest registrations first — enough to draw avatars; empty on a list row. participantCount is the total; the whole list is paginated and searched by GET …/trips/{tripSlug}/participants. */
  participants: PublicUserDto[]
  /** Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only. */
  thumbnailLightUrl?: string
  /** Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only. */
  thumbnailDarkUrl?: string
  /** The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only. */
  thumbnailUrl?: string
  /** Whether the trip is soft-deleted */
  deleted: boolean
  /** Whether the current user is registered for this trip. False if anonymous. */
  registered: boolean
  /** Number of comments, replies included. Absent when the caller may not read the comments of this trip — comments are members-only, so an outsider is told nothing, not even zero. */
  commentCount?: number
  /** The team's TRIP tags the trip carries, sorted by label. Empty when it carries none. */
  tags: TagDto[]
  /** The weather line of a list card: that of the trip's next leg — its first stage still to leave, else the trip itself when it has no stage — at the start of its route, over the window from its departure to its estimated arrival. Absent when there is nothing to show — trip finished, draft or cancelled, next stage without a route, forecast not in cache yet — and on the trip's own detail, which reads getTripWeather; present only with status OK, STALE or NOT_YET_AVAILABLE. */
  weather?: RideWeatherSummaryDto
}
