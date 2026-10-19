package fr.pedalons.enums;

import org.jspecify.annotations.Nullable;

/**
 * Surface class of a stretch of a saved track (docs/LEDGER_*.md WEB-100, C1b). The stored codes are
 * the raw values of the provider; this is the grouping the clients draw.
 */
public enum TrackSurface {
  /** Valhalla {@code paved_smooth}, {@code paved}. */
  PAVED,
  /** {@code paved_rough}. */
  PAVED_ROUGH,
  /** {@code compacted}, {@code gravel}, {@code fine_gravel}. */
  GRAVEL,
  /** {@code dirt}. */
  DIRT,
  /** {@code path}, {@code impassable}. */
  PATH,
  /** Not matched on the network, or no surface tagged. */
  UNKNOWN,
  /** A straight line of the route planner (a DIRECT piece). */
  OFF_NETWORK;

  /** The class of a stored code (a Valhalla value or a reserved code); anything else is UNKNOWN. */
  public static TrackSurface ofCode(@Nullable String code) {
    if (code == null) {
      return UNKNOWN;
    }
    return switch (code) {
      case "paved_smooth", "paved" -> PAVED;
      case "paved_rough" -> PAVED_ROUGH;
      case "compacted", "gravel", "fine_gravel" -> GRAVEL;
      case "dirt" -> DIRT;
      case "path", "impassable" -> PATH;
      case "off_network" -> OFF_NETWORK;
      default -> UNKNOWN;
    };
  }
}
