package fr.pedalons.enums;

/** Where the surface of a track stands (docs/LEDGER_*.md WEB-100, C1b). */
public enum TrackSurfaceState {
  /** The computation is scheduled or running. */
  PENDING,
  /** The surface is available. */
  READY,
  /** The provider could not match this track (sea, nothing to snap to, too short): for good. */
  UNAVAILABLE
}
