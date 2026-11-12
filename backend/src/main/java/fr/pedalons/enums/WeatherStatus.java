package fr.pedalons.enums;

/**
 * What a ride's weather — or one part of it — can say. A client meeting a value it does not know
 * shows nothing.
 */
public enum WeatherStatus {
  /** Forecast in cache and fresh. */
  OK,
  /** Forecast in cache but older than it should be: shown, and flagged. */
  STALE,
  /** More than seven days ahead: comes with {@code availableFrom}. */
  NOT_YET_AVAILABLE,
  /** In the window, but nothing in cache (not fetched yet, or the provider is failing). */
  UNAVAILABLE,
  /** The ride has neither a meeting point nor a route with a start. */
  NO_LOCATION,
  /** Cancelled, or the local day of its end is over: nothing to show. */
  OUT_OF_RANGE
}
