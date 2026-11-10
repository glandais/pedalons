import type { Instant } from './instant.ts'
import type { MediaDto } from './mediaDto.ts'
import type { PlaceDetailDto } from './placeDetailDto.ts'
import type { RouteDto } from './routeDto.ts'

/**
 * Trip stage information
 */
export interface TripStageDto {
  /** Stage ID (TSID) */
  id: string
  /** Stage slug */
  slug: string
  /** Stage name */
  name: string
  /** Stage date/time */
  dateTime: Instant
  /** IANA zone the stage's time was entered in and is read in: its start place's, else its route's, else the previous stage's, else the trip route's, else the team's. A stage may differ from its trip. */
  timezone: string
  /** Average speed in km/h */
  averageSpeed?: number
  /** Route */
  route?: RouteDto
  /** Start place */
  startPlace?: PlaceDetailDto
  /** End place */
  endPlace?: PlaceDetailDto
  /** Stage media */
  media: MediaDto
  /** Sort order */
  sortOrder: number
  /** Position of this stage among the trip's live stages, 1-based — the 'Day 2' of a stage header. Unlike sortOrder, which is a persisted rank that may have gaps, this is a rank a client can print. */
  stageIndex: number
  /** How many live stages the trip has — the '/ 5' of 'Day 2 / 5'. */
  stageCount: number
  /** Number of comments on the stage's own thread. Absent when the caller cannot read comments (not a member of the team), like TripDto.commentCount. */
  commentCount?: number
  /** When the stage is expected to end: dateTime plus its route's length at its averageSpeed. Absent when it has no route or no averageSpeed — no default speed here. Known whatever the forecast window, unlike WeatherLegDto.arrivalTime. */
  estimatedArrival?: Instant
  /** Minutes from dateTime to estimatedArrival, rounded. Absent when estimatedArrival is. */
  estimatedDurationMinutes?: number
}
