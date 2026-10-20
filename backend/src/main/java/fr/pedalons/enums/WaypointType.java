package fr.pedalons.enums;

import org.jspecify.annotations.Nullable;

/**
 * What a waypoint of a route is for (docs/LEDGER_*.md WEB-100, C3c). The twelve types the owner
 * validated, each with its GPX {@code sym}, FIT {@code course_point} and Hammerhead value in {@code
 * infrastructure.gpx.WaypointFormats}.
 *
 * <p>Stored as a string without a database check: a new value ships in two releases (the first one
 * reads it, the second one writes it), or the previous release of a rolling deploy would fail on
 * it. {@link #parseOrInfo} is how a value this release does not know is read.
 */
public enum WaypointType {
  REGROUP,
  SUPPLY,
  WATER,
  CAFE,
  TOILETS,
  DANGER,
  SUMMIT,
  VIEWPOINT,
  BIKE_SHOP,
  REAL_START,
  SPLIT,
  INFO;

  /** The type a stored or received name stands for; {@link #INFO} for null or an unknown one. */
  public static WaypointType parseOrInfo(@Nullable String name) {
    if (name == null) {
      return INFO;
    }
    try {
      return valueOf(name);
    } catch (IllegalArgumentException e) {
      return INFO;
    }
  }
}
