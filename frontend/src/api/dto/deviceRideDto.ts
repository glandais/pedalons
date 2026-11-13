import type { DeviceRideEntryDto } from './deviceRideEntryDto.ts'
import type { Instant } from './instant.ts'

/**
 * Ride information for device applications
 */
export interface DeviceRideDto {
  /** Team slug */
  teamSlug: string
  /** Ride slug */
  rideSlug: string
  /** Ride name */
  rideName: string
  /** Start date/time */
  startDateTime?: Instant
  /** IANA zone of the ride, as RideDto.timezone: the Karoo renders the starts in it, the Garmin app ignores it and renders in its own zone */
  timezone: string
  /** Route entries for this ride */
  entries: DeviceRideEntryDto[]
}
