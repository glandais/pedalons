import type { RelativeWind } from './relativeWind.ts'

/**
 * The wind on the stretch between two checkpoints, as the rider meets it
 */
export interface WindSegmentDto {
  /** Start of the stretch, equal to its checkpoint's distance: metres from the start of the route, its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next (unlike the 4th coordinate of a track geometry, which restarts at 0 on each track). */
  fromDistance: number
  /** End of the stretch, equal to the next checkpoint's distance: metres from the start of the route, its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next (unlike the 4th coordinate of a track geometry, which restarts at 0 on each track). */
  toDistance: number
  /** HEAD when the head component exceeds half the wind speed, TAIL below minus half, CROSS otherwise. Always shown with its label and an arrow, not by colour alone. */
  relativeWind: RelativeWind
  /** Mean head component, km/h, signed: positive against the rider */
  headwind: number
}
