import type { ElevationState } from './elevationState.ts'
import type { GeoJsonPoint } from './geoJsonPoint.ts'
import type { Instant } from './instant.ts'
import type { MediaDto } from './mediaDto.ts'
import type { PublicUserDto } from './publicUserDto.ts'
import type { SurfaceType } from './surfaceType.ts'
import type { TagDto } from './tagDto.ts'
import type { TeamPublicationDto } from './teamPublicationDto.ts'
import type { TrackDto } from './trackDto.ts'
import type { Visibility } from './visibility.ts'
import type { WaypointDto } from './waypointDto.ts'

/**
 * Detailed route information
 */
export interface RouteDetailDto {
  /** Route ID (TSID) */
  id: string
  /** Route slug */
  slug: string
  /** Team */
  team: TeamPublicationDto
  /** Route name */
  name: string
  /** Media */
  media: MediaDto
  /** Distance in meters */
  distance: number
  /** Total elevation gain in meters */
  elevationGain: number
  /** Total elevation loss in meters */
  elevationLoss: number
  /** Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed. */
  elevationState: ElevationState
  /** Surface type */
  surfaceType: SurfaceType
  /** Whether the route is public */
  visibility: Visibility
  start?: GeoJsonPoint
  end?: GeoJsonPoint
  /** Creator user. Absent when the caller is not a member of the team: member names are never sent to anyone else. */
  createdBy?: PublicUserDto
  /** Creation timestamp */
  createdAt: Instant
  /** Last update timestamp */
  updatedAt: Instant
  /** Tracks, with the stored geometry untouched — every coordinate carries longitude, latitude, elevation and cumulative distance in meters. Empty when the bulk endpoint was called with 'geometry=false'. */
  tracks: TrackDto[]
  /** Waypoints */
  waypoints: WaypointDto[]
  /** Whether the route is soft-deleted */
  deleted: boolean
  /** Number of comments, replies included. Absent when the caller may not read the comments of this route — comments are members-only, so an outsider is told nothing, not even zero. */
  commentCount?: number
  /** The team's ROUTE tags the route carries, sorted by label. Empty when it carries none. */
  tags: TagDto[]
}
