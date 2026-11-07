package fr.pedalons.enums;

import java.util.Locale;
import org.jspecify.annotations.Nullable;

/**
 * Surface class of a stretch of a saved track (docs/LEDGER_*.md WEB-100, C1b). This is the grouping
 * the clients draw. The codes of a version 1 document are osm-surface's raw values, grouped here on
 * reading; a version 2 document stores the {@link #code()} of the class itself (docs/LEDGER_*.md
 * API-150), the projection from osm-route-details being {@code RouteDetailsSurfaces}.
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

  /**
   * The code a version 2 document stores for this class. Every one is read back as this class by
   * {@link #ofCode}, in this release and in the previous one: a rolling deploy or a rollback serves
   * those documents right.
   */
  public String code() {
    return name().toLowerCase(Locale.ROOT);
  }

  /**
   * The class of a stored code (a Valhalla value, a {@link #code()} or a reserved code); anything
   * else is UNKNOWN.
   */
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
