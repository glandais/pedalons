import type { DepartureWeatherDto } from './departureWeatherDto.ts'
import type { Instant } from './instant.ts'
import type { WeatherAttributionDto } from './weatherAttributionDto.ts'
import type { WeatherLegDto } from './weatherLegDto.ts'
import type { WeatherStatus } from './weatherStatus.ts'

/**
 * A ride's weather, for its detail page: the meeting point at departure, then one leg per group. Read from the server's cache only — the forecast is refreshed in the background, never on request.
 */
export interface RideWeatherDto {
  /** Overall state. OK and STALE (shown, flagged as old) carry the forecast; NOT_YET_AVAILABLE comes with availableFrom; UNAVAILABLE (nothing in cache yet, or the provider failing) offers to retry; NO_LOCATION is worth a word to the organisers only; OUT_OF_RANGE (over — its last group back, the ride's estimated end —, cancelled) shows nothing. A ride that has left but whose groups are still out, or still to leave, keeps its forecast. */
  status: WeatherStatus
  /** For NOT_YET_AVAILABLE: when the forecast opens, seven days before the departure */
  availableFrom?: Instant
  /** The oldest fetch among the forecasts read */
  fetchedAt?: Instant
  /** The meeting point when the ride leaves (its dateTime). Each leg carries its own, at the group's start. */
  departure: DepartureWeatherDto
  /** One per group, in group order; a single one without groupId for a ride without groups. Empty for OUT_OF_RANGE, NO_LOCATION and NOT_YET_AVAILABLE. */
  legs: WeatherLegDto[]
  /** The credit the forecast's licence asks for */
  attribution: WeatherAttributionDto
}
