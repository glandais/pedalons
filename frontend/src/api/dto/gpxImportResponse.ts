import type { GpxImportTrack } from './gpxImportTrack.ts'
import type { WaypointDto } from './waypointDto.ts'

/**
 * A GPX file processed for the route editor
 */
export interface GpxImportResponse {
  /** Name of the file: its metadata, else its first track, else its file name */
  name: string
  /** Tracks in the order of the file, 1 to 8 */
  tracks: GpxImportTrack[]
  /** Number of waypoints of the file (the first 500 are in waypoints) */
  waypointCount: number
  /** True when the elevations of a track could not all be read from the elevation source and part of them are the file's own */
  elevationFallback: boolean
  /** The waypoints of the file, typed from their symbol, at most 500, in file order: imported, with no identifier and no distance (the server places them when the route is saved) */
  waypoints?: WaypointDto[]
}
