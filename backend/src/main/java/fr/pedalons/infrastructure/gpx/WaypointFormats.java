package fr.pedalons.infrastructure.gpx;

import fr.pedalons.enums.WaypointType;
import io.github.glandais.fit.FitCoursePointType;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import org.jspecify.annotations.Nullable;

/**
 * The twelve {@link WaypointType}s in every format they travel in (docs/LEDGER_*.md WEB-100, C3c):
 * GPX {@code sym} and {@code type}, FIT {@code course_point}, Garmin Courses API, Hammerhead.
 * Pure: no I/O, no entity.
 *
 * <p>Every export method is an exhaustive {@code switch}, so that adding a type fails the build
 * until each format has its answer.
 */
public final class WaypointFormats {

  /** The longest name a FIT course point carries (W6), in code points. */
  public static final int FIT_NAME_MAX = 15;

  /** A cut at a word is taken only when it leaves at least this many code points. */
  private static final int WORD_CUT_MIN = 8;

  private WaypointFormats() {}

  // ------------------------------------------------------------------ export

  /** The GPX {@code <sym>} (Garmin symbol names) Pédalons writes. */
  public static String garminSymbol(WaypointType type) {
    return switch (type) {
      case REGROUP -> "Flag, Blue";
      case SUPPLY -> "Food Source";
      case WATER -> "Drinking Water";
      case CAFE -> "Restaurant";
      case TOILETS -> "Restroom";
      case DANGER -> "Danger Area";
      case SUMMIT -> "Summit";
      case VIEWPOINT -> "Scenic Area";
      case BIKE_SHOP -> "Car Repair";
      case REAL_START -> "Flag, Green";
      case SPLIT -> "Flag, Red";
      case INFO -> "Information";
    };
  }

  /** The FIT {@code course_point} type (W2, W3). */
  public static FitCoursePointType fitType(WaypointType type) {
    return switch (type) {
      case REGROUP -> FitCoursePointType.MEETING_SPOT;
      case SUPPLY -> FitCoursePointType.AID_STATION;
      case WATER -> FitCoursePointType.WATER;
      case CAFE -> FitCoursePointType.FOOD;
      case TOILETS -> FitCoursePointType.TOILET;
      case DANGER -> FitCoursePointType.DANGER;
      case SUMMIT -> FitCoursePointType.SUMMIT;
      case VIEWPOINT -> FitCoursePointType.OVERLOOK;
      case BIKE_SHOP -> FitCoursePointType.GEAR;
      case REAL_START -> FitCoursePointType.CHECKPOINT;
      case SPLIT -> FitCoursePointType.ALERT;
      case INFO -> FitCoursePointType.INFO;
    };
  }

  /** The GPX {@code <type>}: the FIT name in lower case, which the FIT export shares. */
  public static String gpxType(WaypointType type) {
    return fitType(type).name().toLowerCase(Locale.ROOT);
  }

  /** The {@code coursePointType} of Garmin's Courses API: the FIT enum name. */
  public static String courseApiType(WaypointType type) {
    return fitType(type).name();
  }

  /**
   * The value Hammerhead keeps for both {@code <sym>} and {@code <type>}: one of the nine it
   * accepts through its import (Karoo trial of docs/LEDGER_*.md WEB-100, C3a).
   */
  public static String hammerhead(WaypointType type) {
    return switch (type) {
      case SUPPLY, CAFE -> "Food";
      case WATER -> "Water";
      case DANGER -> "Danger";
      case SUMMIT -> "Summit";
      case REGROUP, TOILETS, VIEWPOINT, BIKE_SHOP, REAL_START, SPLIT, INFO -> "Generic";
    };
  }

  /** The name a point without one shows on a device. */
  public static String label(WaypointType type) {
    return switch (type) {
      case REGROUP -> "Regroupement";
      case SUPPLY -> "Ravitaillement";
      case WATER -> "Eau";
      case CAFE -> "Café";
      case TOILETS -> "Toilettes";
      case DANGER -> "Danger";
      case SUMMIT -> "Sommet";
      case VIEWPOINT -> "Point de vue";
      case BIKE_SHOP -> "Atelier vélo";
      case REAL_START -> "Départ réel";
      case SPLIT -> "Séparation";
      case INFO -> "Info";
    };
  }

  // ------------------------------------------------------------------ import

  private static final Map<String, WaypointType> IMPORT = new HashMap<>();

  static {
    // The twelve symbols Pédalons writes come first: a Pédalons GPX comes back unchanged
    for (WaypointType type : WaypointType.values()) {
      IMPORT.put(normalize(garminSymbol(type)), type);
      // And the canonical names, which the sanitizer writes (a sanitized document stays stable)
      IMPORT.put(normalize(type.name()), type);
    }
    put(WaypointType.REGROUP, "meeting_spot");
    put(WaypointType.SUPPLY, "aid_station", "energy_gel", "sports_drink");
    put(WaypointType.WATER, "water", "water source");
    put(WaypointType.CAFE, "fast food", "food", "coffee", "cafe", "café");
    put(WaypointType.TOILETS, "toilet", "toilets");
    put(
        WaypointType.DANGER,
        "danger",
        "caution",
        "warning",
        "obstacle",
        "sharp_curve",
        "steep_incline");
    put(
        WaypointType.SUMMIT,
        "hors_category",
        "first_category",
        "second_category",
        "third_category",
        "fourth_category");
    put(WaypointType.VIEWPOINT, "overlook", "viewpoint");
    put(WaypointType.BIKE_SHOP, "gear", "bike_shop", "bike shop");
    put(WaypointType.REAL_START, "start");
    // "checkpoint" and "alert" alone are the controls and warnings of other tools, not the real
    // start and the split of Pédalons: they stay INFO (E9). "Flag, Green" and "Flag, Red" say it.
    put(
        WaypointType.INFO,
        "info",
        "generic",
        "checkpoint",
        "alert",
        "parking",
        "camping",
        "lodging",
        "geocache");
  }

  private static void put(WaypointType type, String... keys) {
    for (String key : keys) {
      IMPORT.put(normalize(key), type);
    }
  }

  private static String normalize(String value) {
    return value.strip().toLowerCase(Locale.ROOT).replaceAll("\\s+", " ");
  }

  /**
   * The type a file's waypoint stands for (W7): its {@code <sym>} first, then its {@code <type>},
   * ignoring case and repeated spaces; {@link WaypointType#INFO} when neither says more.
   */
  public static WaypointType fromGpx(@Nullable String sym, @Nullable String type) {
    WaypointType fromSym = lookup(sym);
    if (fromSym != null && fromSym != WaypointType.INFO) {
      return fromSym;
    }
    WaypointType fromType = lookup(type);
    return fromType != null ? fromType : WaypointType.INFO;
  }

  private static @Nullable WaypointType lookup(@Nullable String value) {
    if (value == null || value.isBlank()) {
      return null;
    }
    return IMPORT.get(normalize(value));
  }

  // ------------------------------------------------------------------ FIT name

  /**
   * The name of a FIT course point (W6): control characters out, empty means the type's label, cut
   * to {@value #FIT_NAME_MAX} <b>code points</b> (never UTF-16 units) and, when it can be done
   * without losing most of it, at the last space.
   */
  public static String fitName(@Nullable String name, WaypointType type) {
    String cleaned = name == null ? "" : name.replaceAll("\\p{Cntrl}", " ").strip();
    if (cleaned.isEmpty()) {
      return label(type);
    }
    if (cleaned.codePointCount(0, cleaned.length()) <= FIT_NAME_MAX) {
      return cleaned;
    }
    int end = cleaned.offsetByCodePoints(0, FIT_NAME_MAX);
    String cut = cleaned.substring(0, end);
    int space = cut.lastIndexOf(' ');
    if (space >= 0 && cut.codePointCount(0, space) >= WORD_CUT_MIN) {
      cut = cut.substring(0, space);
    }
    return cut.strip();
  }
}
