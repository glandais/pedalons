import type { DeviceRouteSyncStatusDto } from './deviceRouteSyncStatusDto.ts'
import type { Instant } from './instant.ts'

/**
 * Upcoming ride group the user is registered in, with the route to load on the device
 */
export interface DeviceRegisteredGroupDto {
  /** Team slug */
  teamSlug: string
  /** Ride slug */
  rideSlug: string
  /** Ride name */
  rideName: string
  /** Name of the group the user is registered in */
  groupName: string
  /** Slug of the route to load: the group's own route, or the ride's when the group has none */
  routeSlug: string
  /** Route name */
  routeName: string
  /** Distance in meters */
  distance: number
  /** Elevation gain in meters */
  elevationGain: number
  /** When the group leaves, as an absolute instant (UTC): the group's startAt, the ride's own start when the group has no time. Devices render it in their own zone. */
  startDateTime: Instant
  /** IANA time zone of the ride (e.g. Europe/Paris) */
  timezone: string
  /** Where the route stands at each of the user's GPS services that hold it (sent automatically or uploaded by hand), so a device does not upload it again. Empty when no service holds it; a device only reads its own service's entry (Karoo: HAMMERHEAD, Garmin: GARMIN). */
  syncStatuses?: DeviceRouteSyncStatusDto[]
}
