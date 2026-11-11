import type { Visibility } from './visibility.ts'

/**
 * The visibilities the team accepts for each type of content, in the order of the Visibility enum. What a creation form offers; an editor hides its selector when a list has a single value. Never empty: TEAM is always accepted.
 */
export interface ContentVisibilitiesDto {
  ride: Visibility[]
  rideTemplate: Visibility[]
  route: Visibility[]
  post: Visibility[]
  trip: Visibility[]
  teamPage: Visibility[]
  /** Always [TEAM]: ads are members-only in every team. */
  ad: Visibility[]
}
