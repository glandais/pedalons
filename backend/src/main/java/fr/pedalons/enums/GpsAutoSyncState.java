package fr.pedalons.enums;

/**
 * Where the automatic route sync of one GPS service connection stands, as the profile shows it
 * (docs/LEDGER_*.md API-120).
 */
public enum GpsAutoSyncState {
  /** The member did not turn it on for this service. */
  OFF,
  /** Every route the member should have at the service is there, as it should be. */
  UP_TO_DATE,
  /** Something is waiting to be sent, updated or removed. */
  PENDING,
  /** The last attempt at one of the routes failed; it is retried with a backoff. */
  FAILING,
  /** The service refuses our token (or the permission was withdrawn): only a reconnection helps. */
  RECONNECT_REQUIRED
}
