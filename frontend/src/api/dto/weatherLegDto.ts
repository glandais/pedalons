import type { DepartureWeatherDto } from './departureWeatherDto.ts'
import type { Instant } from './instant.ts'
import type { RideWeatherSummaryDto } from './rideWeatherSummaryDto.ts'
import type { WeatherCheckpointDto } from './weatherCheckpointDto.ts'
import type { WeatherRainAlertDto } from './weatherRainAlertDto.ts'
import type { WeatherStatus } from './weatherStatus.ts'
import type { WindDto } from './windDto.ts'
import type { WindExposureDto } from './windExposureDto.ts'
import type { WindSegmentDto } from './windSegmentDto.ts'

/**
 * The weather along one ridden route: a group of a ride, or a stage of a trip. Passages are estimated from startTime at averageSpeed.
 */
export interface WeatherLegDto {
  /** The ride group (TSID). Absent for a ride without groups — the leg rides the ride's own route — and for a trip's legs, which TripStageWeatherDto.stageId names. */
  groupId?: string
  /** State of this leg's forecast. NO_LOCATION when the leg has no route to sample: then no checkpoint, no segment. NOT_YET_AVAILABLE when it leaves beyond the seven-day horizon: checkpoints and times without weather, and availableFrom. OUT_OF_RANGE for a trip stage already over (its estimated end passed): nothing to show. */
  status: WeatherStatus
  /** For NOT_YET_AVAILABLE: when this leg's forecast opens, seven days before it leaves */
  availableFrom?: Instant
  /** When the leg leaves */
  startTime: Instant
  /** Speed used for the passages, km/h */
  averageSpeed: number
  /** Whether averageSpeed is the 25 km/h default, the group or stage having none — to be said on screen */
  speedIsDefault: boolean
  /** Length of the leg's route, metres */
  distance: number
  /** Estimated arrival */
  arrivalTime: Instant
  /** The oldest fetch among the forecasts this leg reads */
  fetchedAt?: Instant
  /** Forecast points, start to finish */
  checkpoints: WeatherCheckpointDto[]
  /** The wind stretch by stretch, from one checkpoint to the next */
  segments: WindSegmentDto[]
  /** Distance ridden against, across and with the wind */
  windExposure: WindExposureDto
  /** The leg's dominant wind: circular mean of the directions, mean speed, highest gust */
  prevailingWind?: WindDto
  /** The first checkpoint where rain becomes likely, if any */
  rainAlert?: WeatherRainAlertDto
  /** The leg's weather in one line, for its card: the first checkpoint's hour, the extremes over the checkpoints, the rain alert — as TripStageWeatherDto.summary for a stage. Present when status is OK, STALE or NOT_YET_AVAILABLE (then status and availableFrom only). */
  summary?: RideWeatherSummaryDto
  /** For a ride's leg: the weather at the ride's meeting point when this group leaves (startTime), sunrise and sunset included — RideWeatherDto.departure is the same at the ride's own time. Same states: conditions for OK and STALE only, UNAVAILABLE when the cache has no hour near the group's start, NOT_YET_AVAILABLE when the group leaves beyond the horizon. Absent on a trip's legs, whose departure TripStageWeatherDto.departure carries. */
  departure?: DepartureWeatherDto
}
