package fr.pedalons.enums;

import org.jspecify.annotations.Nullable;

/** Who put a waypoint on a route (docs/LEDGER_*.md WEB-100, C3c). */
public enum WaypointOrigin {
  /** Placed in the editor by the route's author: it survives a new GPX file. */
  AUTHOR,
  /** Read from a GPX file: replaced by the waypoints of the next file. */
  IMPORTED;

  /** The origin a stored or received name stands for; {@link #IMPORTED} for null or unknown. */
  public static WaypointOrigin parseOrImported(@Nullable String name) {
    if (name == null) {
      return IMPORTED;
    }
    try {
      return valueOf(name);
    } catch (IllegalArgumentException e) {
      return IMPORTED;
    }
  }
}
