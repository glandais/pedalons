package fr.pedalons.enums;

/**
 * Where one route stands at one of the user's GPS services (docs/LEDGER_*.md API-120, API-121).
 * Declared from best to worst: when several tracking rows of the same route and service merge, the
 * worst wins.
 */
public enum GpsRouteSyncState {
  /** At the service, as it should be. */
  SENT,
  /**
   * At the service, but an older version than the route's current GPX, and nothing will update it:
   * a manual upload (Pédalons never updates one on its own), or any route while the sync is off.
   * Sending it again updates it in place.
   */
  OUTDATED,
  /** To be sent or updated: the worker's next ticks. */
  PENDING,
  /**
   * The last attempt failed. Retried with a backoff a few times ({@code
   * GpsRouteSyncExecutor.MAX_ATTEMPTS}), then left until the route or the ride changes.
   */
  FAILING,
  /** The connection waits for a reconnection. */
  RECONNECT_REQUIRED
}
