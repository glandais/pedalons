import type { Instant } from './instant.ts'
import type { RelativeWind } from './relativeWind.ts'
import type { WeatherCheckpointKind } from './weatherCheckpointKind.ts'
import type { WeatherConditionsDto } from './weatherConditionsDto.ts'

/**
 * A forecast point along a leg, about every 15 km plus the finish. Deliberately carries no coordinates: place it by distance on the route geometry the client may read.
 */
export interface WeatherCheckpointDto {
  /** Position of the point on the leg, 0 for the start */
  index: number
  /** Where the point stands on the leg */
  kind: WeatherCheckpointKind
  /** Distance from the start of the leg's route, metres: its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next. To place the point on the geometry, add up the lengths of the previous tracks: the 4th coordinate of a track geometry restarts at 0 on each track. */
  distance: number
  /** Elevation of the point, metres, from the track */
  elevation?: number
  /** Estimated passage, from the leg's start time and speed */
  time: Instant
  /** The forecast at the passage. Absent when nothing is in cache for that place yet. */
  weather?: WeatherConditionsDto
  /** How the rider meets the wind on the stretch that starts here (for the finish, the stretch that ends here). Absent without weather. */
  relativeWind?: RelativeWind
  /** Mean head component of the wind on that stretch, km/h, signed: positive against the rider, negative behind */
  headwind?: number
  /** Direction the wind blows TOWARDS, relative to the direction of travel, degrees clockwise: 0 = from behind (pushing), 90 = from the left, 180 = in the face. Draw the arrow pointing forward, then rotate it by this angle. */
  relativeWindAngle?: number
}
