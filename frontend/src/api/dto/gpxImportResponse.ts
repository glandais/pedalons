import type { GpxImportTrack } from './gpxImportTrack.ts'

/**
 * A GPX file processed for the route editor
 */
export interface GpxImportResponse {
  /** Name of the file: its metadata, else its first track, else its file name */
  name: string
  /** Tracks in the order of the file, 1 to 8 */
  tracks: GpxImportTrack[]
  /** Number of waypoints of the file, which the editor does not keep */
  waypointCount: number
  /** True when the elevations of a track could not all be read from the elevation source and part of them are the file's own */
  elevationFallback: boolean
}
