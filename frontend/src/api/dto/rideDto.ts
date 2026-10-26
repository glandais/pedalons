import type { Instant } from './instant.ts'
import type { MediaDto } from './mediaDto.ts'
import type { PlaceDetailDto } from './placeDetailDto.ts'
import type { PublicUserDto } from './publicUserDto.ts'
import type { RideDtoType } from './rideDtoType.ts'
import type { RideGroupDto } from './rideGroupDto.ts'
import type { RideGroupSummaryDto } from './rideGroupSummaryDto.ts'
import type { RideWeatherSummaryDto } from './rideWeatherSummaryDto.ts'
import type { Status } from './status.ts'
import type { SurfaceType } from './surfaceType.ts'
import type { TagDto } from './tagDto.ts'
import type { TeamPublicationDto } from './teamPublicationDto.ts'
import type { Visibility } from './visibility.ts'

/**
 * Ride summary data
 */
export interface RideDto {
  type: RideDtoType
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
  /** Publication date/time */
  dateTime: Instant
  /** IANA zone the ride's times were entered in and read in: its start place's, else its route's, else the team's. dateTime, publishAt, endDateTime and the groups' startAt are rendezvous in this zone. */
  timezone: string
  /** When the ride is over, computed by the server: the latest of its groups, each one its departure plus its route's length at its average speed — or plus 3 hours when the group has no speed or no route, and for a ride with no group. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read. */
  endDateTime: Instant
  /** Publication status */
  status: Status
  /** Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished. */
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
  /** Number of groups */
  groupCount: number
  /** Ride groups */
  groups: RideGroupDto[]
  /** Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail. */
  groupSummaries: RideGroupSummaryDto[]
  /** Distance in meters of the ride's route — or, when the ride itself has none, of the route of its first group (in sort order) that has one. Null when no route is set anywhere. */
  distance?: number
  /** Total elevation gain in meters, from the same route as distance. Null when no route is set anywhere. */
  elevationGain?: number
  /** Surface type, from the same route as distance. Null when no route is set anywhere. */
  surfaceType?: SurfaceType
  /** Start place */
  startPlace?: PlaceDetailDto
  /** End place */
  endPlace?: PlaceDetailDto
  /** Preview of first participants (max 5). Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays. */
  topParticipants: PublicUserDto[]
  /** Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only. */
  thumbnailLightUrl?: string
  /** Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only. */
  thumbnailDarkUrl?: string
  /** The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only. */
  thumbnailUrl?: string
  /** Whether the ride is soft-deleted */
  deleted: boolean
  /** Whether the current user is registered in one of this ride's groups. False if anonymous. */
  registered: boolean
  /** ID (TSID) of the group the current user joined, null if not registered */
  registeredGroupId?: string
  /** The group the current user joined, in full — the same object as the matching entry of groups. Null if not registered or anonymous. Set on list rows too, where groups is empty: a client rendering "my next ride" needs no second request for its group. Its leader is the group's own, null when none was designated. */
  registeredGroup?: RideGroupDto
  /** Whether every group of the ride has reached its capacity. False when the ride has no group, or when at least one group has no maxParticipants. */
  full: boolean
  /** Capacity of the whole ride: the sum of its groups' maxParticipants, to render participantCount against it ("12/40"). Null when the ride has no group, or when at least one group has no maxParticipants — the ride then has no overall limit, and is never full. Set on list rows too, where groups is empty. */
  maxParticipants?: number
  /** Number of comments, replies included. Absent when the caller may not read the comments of this ride — comments are members-only, so an outsider is told nothing, not even zero. */
  commentCount?: number
  /** The team's RIDE tags the ride carries, sorted by label. Empty when it carries none. */
  tags: TagDto[]
  /** The weather line of a card: the meeting point, over the window from the departure to the estimated arrival of the last group. Absent when there is nothing to show — finished or cancelled ride, no place, forecast not in cache yet; present only with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather. */
  weather?: RideWeatherSummaryDto
}
