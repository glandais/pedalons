import type { DeviceRouteSyncStatusDto } from './deviceRouteSyncStatusDto.ts'
import type { Instant } from './instant.ts'
import type { Status } from './status.ts'

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
  /** When the group leaves, as an absolute instant (UTC): the group's startAt, the ride's own start when the group has no time. The Karoo renders it in timezone, the Garmin app in its own zone. */
  startDateTime: Instant
  /** IANA time zone of the ride (e.g. Europe/Paris) */
  timezone: string
  /** Where the route stands at each of the user's GPS services that hold it (sent automatically or uploaded by hand), so a device does not upload it again. Empty when no service holds it; a device only reads its own service's entry (Karoo: HAMMERHEAD, Garmin: GARMIN). */
  syncStatuses?: DeviceRouteSyncStatusDto[]
  /** Team name. Only with details=true. */
  teamName?: string
  /** Name of the place the ride leaves from, when it has one. Only with details=true. */
  startPlaceName?: string
  /** Status of the ride: PUBLISHED or CANCELLED. Only with details=true — which also lists the groups of a cancelled ride, left out otherwise. */
  status?: Status
  /** When the group is expected to arrive, as an absolute instant (UTC): its route's length at its speed, the departure plus three hours when either is missing. Only with details=true. */
  endDateTime?: Instant
}
