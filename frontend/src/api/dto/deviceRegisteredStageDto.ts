import type { DeviceRouteSyncStatusDto } from './deviceRouteSyncStatusDto.ts'
import type { Instant } from './instant.ts'
import type { Status } from './status.ts'

/**
 * Upcoming stage of a trip the user is registered for, with the route to load on the device
 */
export interface DeviceRegisteredStageDto {
  /** Team slug */
  teamSlug: string
  /** Trip slug */
  tripSlug: string
  /** Trip name */
  tripName: string
  /** Stage name */
  stageName: string
  /** Slug of the route to load: the stage's own route, never the trip's (a stage without a route is left out) */
  routeSlug: string
  /** Route name */
  routeName: string
  /** Distance in meters */
  distance: number
  /** Elevation gain in meters */
  elevationGain: number
  /** When the stage leaves, as an absolute instant (UTC) */
  startDateTime: Instant
  /** IANA time zone of the stage (e.g. Europe/Paris) */
  timezone: string
  /** Name of the place the stage leaves from, when it has one */
  startPlaceName?: string
  /** Name of the place the stage ends at, when it has one */
  endPlaceName?: string
  /** Where the route stands at each of the user's GPS services that hold it, as DeviceRegisteredGroupDto.syncStatuses */
  syncStatuses: DeviceRouteSyncStatusDto[]
  /** Team name */
  teamName: string
  /** Status of the trip: PUBLISHED or CANCELLED (the stages of a cancelled trip are listed, for the device to say so) */
  status: Status
  /** When the stage is expected to end, as an absolute instant (UTC): its stored end, the departure plus three hours without one */
  endDateTime: Instant
}
