import type { Instant } from './instant.ts'
import type { WeatherConditionsDto } from './weatherConditionsDto.ts'
import type { WeatherStatus } from './weatherStatus.ts'

/**
 * The weather at the departure point when the ride, or a trip stage, leaves
 */
export interface DepartureWeatherDto {
  /** State of the departure forecast. conditions is present for OK and STALE only. */
  status: WeatherStatus
  /** The forecast of the departure hour, for OK and STALE */
  conditions?: WeatherConditionsDto
  /** Sunrise at the meeting point, on the departure's local date */
  sunrise?: Instant
  /** Sunset at the meeting point, on the departure's local date */
  sunset?: Instant
  /** When the forecast of the meeting point was last fetched */
  fetchedAt?: Instant
}
