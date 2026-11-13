import type { DeviceRegisteredGroupDto } from './deviceRegisteredGroupDto.ts'
import type { DeviceRegisteredStageDto } from './deviceRegisteredStageDto.ts'
import type { DeviceRideDto } from './deviceRideDto.ts'
import type { DeviceRouteDto } from './deviceRouteDto.ts'

/**
 * Response containing rides and routes for device applications
 */
export interface DeviceRoutesResponse {
  /** Upcoming rides with route entries */
  rides: DeviceRideDto[]
  /** Latest standalone routes */
  routes: DeviceRouteDto[]
  /** Upcoming ride groups the user is registered in (from 12 hours ago to 7 days ahead), earliest first, each with the route to load */
  registeredGroups: DeviceRegisteredGroupDto[]
  /** Upcoming stages of the trips the user is registered for (each stage leaving from 12 hours ago to 7 days ahead), earliest first, each with the route to load. Present only when the request carries stages=true. */
  registeredStages?: DeviceRegisteredStageDto[]
}
