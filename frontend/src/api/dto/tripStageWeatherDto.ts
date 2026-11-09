import type { DepartureWeatherDto } from './departureWeatherDto.ts'
import type { RideWeatherSummaryDto } from './rideWeatherSummaryDto.ts'
import type { WeatherLegDto } from './weatherLegDto.ts'

/**
 * One stage of a trip: its weather in one line, and along its route
 */
export interface TripStageWeatherDto {
  /** The stage (TSID), as TripStageDto.id. Absent for the single leg of a trip without stages, which rides the trip's own route at its own time. */
  stageId?: string
  /** The stage's weather in one line, for its card: the first checkpoint's hour, the extremes over the checkpoints, the rain alert. Present when leg.status is OK, STALE or NOT_YET_AVAILABLE (then status and availableFrom only). */
  summary?: RideWeatherSummaryDto
  /** The stage's route, at its estimated passages (stage speed, else 25 km/h) */
  leg: WeatherLegDto
  /** The weather when the stage leaves, at its first forecast point: conditions, sunrise and sunset, as RideWeatherDto.departure for a ride. OUT_OF_RANGE once the stage has left, NO_LOCATION without a route, NOT_YET_AVAILABLE beyond the horizon. */
  departure: DepartureWeatherDto
}
