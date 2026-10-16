import type { Instant } from './instant.ts'
import type { WeatherCondition } from './weatherCondition.ts'
import type { WindDto } from './windDto.ts'

/**
 * The forecast of one hour at one place
 */
export interface WeatherConditionsDto {
  /** The forecast hour used: the one nearest the moment asked about */
  time: Instant
  /** WMO weather interpretation code, as the model gives it. condition is its folding; a client reads condition, this is for the curious. */
  weatherCode: number
  /** weatherCode folded into what a rider decides on. WMO code → condition: 0 CLEAR; 1 MOSTLY_CLEAR; 2 PARTLY_CLOUDY; 3 OVERCAST; 45, 48 FOG; 51, 53, 55 DRIZZLE; 56, 57, 66, 67 FREEZING_RAIN; 61, 63 RAIN; 65 HEAVY_RAIN; 71, 73, 75, 77, 85, 86 SNOW; 80, 81, 82 SHOWERS; 95, 96, 99 THUNDERSTORM; any other OVERCAST. A client meeting a value it does not know shows a plain cloud. */
  condition: WeatherCondition
  /** Whether the moment asked about (the departure, the checkpoint's passage) falls between sunrise and sunset at that place — not time, the round model hour. Picks the day or night icon */
  daylight: boolean
  /** Air temperature at 2 m, °C */
  temperature: number
  /** Felt temperature (wind chill, humidity), °C */
  apparentTemperature: number
  /** Probability of precipitation, % (0–100). Absent when the model gives none. */
  precipitationProbability?: number
  /** Precipitation over the hour (rain, showers, snow), mm */
  precipitation: number
  /** Wind of that hour */
  wind: WindDto
}
