import type { IncompatibleRouteDto } from './incompatibleRouteDto.ts'
import type { IncompatibleRouteUsageDto } from './incompatibleRouteUsageDto.ts'
import type { IncompatibleVisibilityDetailsType } from './incompatibleVisibilityDetailsType.ts'

export interface IncompatibleVisibilityDetails {
  type: IncompatibleVisibilityDetailsType
  /** Saving a ride or a trip (creation, update, restore): its TEAM routes — its own, its groups' or its stages'. Replaying the creation or the update with alignVisibility = true raises each to its proposedVisibility in the same transaction. Empty when a route was saved. */
  routes: IncompatibleRouteDto[]
  /** Saving a route as TEAM: the rides and trips visible outside the team that use it — directly, through a group or through a stage — drafts included, deleted ones left out. There is no alignment in this direction: change them first. Empty when a ride or a trip was saved. */
  usages: IncompatibleRouteUsageDto[]
}
