import type { Instant } from './instant.ts'
import type { TrackDto } from './trackDto.ts'
import type { WaypointDto } from './waypointDto.ts'

/**
 * Analysed GPX file, not attached to any team
 */
export interface GpxPreviewDto {
  /** Public identifier used in URLs */
  id: string
  /** Track name */
  name: string
  /** Distance in meters */
  distance: number
  /** Total elevation gain in meters */
  elevationGain: number
  /** Total elevation loss in meters */
  elevationLoss: number
  /** Elevation gain per kilometer */
  hilliness: number
  /** Whether the current user created this preview */
  owned: boolean
  /** Creation timestamp */
  createdAt: Instant
  /** Rendered map thumbnail template URL (with a {size} placeholder), used for link previews; null when no thumbnail was generated */
  thumbnailUrl?: string
  /** URL to download the analysed GPX file */
  gpxUrl: string
  /** URL to download the analysed track as a FIT file */
  fitUrl: string
  /** Whether the track was drawn in the route planner (true) rather than imported from a GPX file. A drawn preview can only become a route of a team whose route planner is enabled; false when the origin is unknown */
  drawn: boolean
  /** Tracks */
  tracks: TrackDto[]
  /** Waypoints */
  waypoints: WaypointDto[]
}
