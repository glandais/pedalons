package fr.pedalons.enums;

/**
 * Why the last synchronisation attempt of a tracked route failed ({@code gps_route_syncs
 * .last_error}). Persisted as a string under a CHECK constraint: a value added here goes with its
 * Flyway migration, in the same commit (docs/LEDGER_*.md API-71, API-72).
 */
public enum GpsSyncError {
  /** Any other answer of the service, or no answer at all. */
  SERVICE_ERROR,
  /** The token was refused even after a refresh. */
  UNAUTHORIZED,
  /** Garmin's 412: the course permission was withdrawn. */
  PERMISSION_REVOKED,
  /** 429: the connection is paused. */
  RATE_LIMITED,
  /** The domain has no (active) credential for the service any more. */
  NOT_CONFIGURED,
  /** The route or its GPX vanished between planning and sending. */
  ROUTE_UNAVAILABLE
}
