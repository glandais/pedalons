import type { Instant } from './instant.ts'
import type { TripStageWeatherDto } from './tripStageWeatherDto.ts'
import type { WeatherAttributionDto } from './weatherAttributionDto.ts'
import type { WeatherStatus } from './weatherStatus.ts'

/**
 * A trip's weather, stage by stage: each stage's route at its estimated passages. Read from the server's cache only — the forecast is refreshed in the background, never on request.
 */
export interface TripWeatherDto {
  /** Overall state, over the stages not over yet. OK and STALE (shown, flagged as old) carry a forecast for at least one stage; NOT_YET_AVAILABLE (every stage with a route is beyond the horizon) comes with availableFrom; UNAVAILABLE (nothing in cache yet, or the provider failing) offers to retry; NO_LOCATION (no stage not over yet has a route) is worth a word to the organisers only; OUT_OF_RANGE (finished, cancelled, draft) shows nothing. Each stage also has its own, in its leg. */
  status: WeatherStatus
  /** For NOT_YET_AVAILABLE: when the first forecast opens, seven days before the first stage with a route leaves */
  availableFrom?: Instant
  /** The oldest fetch among the forecasts read */
  fetchedAt?: Instant
  /** One per live stage, in stage order (as TripDto.stages), stages already over (their estimated end passed) included with leg.status OUT_OF_RANGE; a stage under way keeps its forecast; a single one without stageId for a trip without stages. Empty when the trip is not published. */
  stages: TripStageWeatherDto[]
  /** The credit the forecast's licence asks for */
  attribution: WeatherAttributionDto
}
