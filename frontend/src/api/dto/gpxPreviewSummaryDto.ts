import type { Instant } from './instant.ts'

/**
 * Summary of an analysed GPX file, for listing
 */
export interface GpxPreviewSummaryDto {
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
  /** Creation timestamp */
  createdAt: Instant
  /** Departure instant, when the person gave a date. The wall time at the start of the track is this instant in departureTimezone. Present together with departureTimezone */
  departureTime?: Instant
  /** IANA time zone of the first point of the track, the one the departure was entered in */
  departureTimezone?: string
}
