import type { GpxImportTrack } from './gpxImportTrack.ts'

/**
 * The relief of straight lines, processed with the FAST elevations
 */
export interface LineElevationResponse {
  /** One track per requested line, in the same order, from its start to its end */
  lines: GpxImportTrack[]
  /** True when part of the elevations could not be read from the elevation source */
  elevationFallback: boolean
}
