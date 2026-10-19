import type { TrackSurface } from './trackSurface.ts'

/**
 * A stretch of a track with one surface class, in metres along the track (the M of its line)
 */
export interface SurfaceSpanDto {
  /** Start, metres along the track */
  from: number
  /** End, metres along the track */
  to: number
  surface: TrackSurface
}
