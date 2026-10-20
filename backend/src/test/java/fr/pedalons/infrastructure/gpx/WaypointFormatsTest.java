package fr.pedalons.infrastructure.gpx;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.enums.WaypointType;
import io.github.glandais.fit.FitCoursePointType;
import java.util.Set;
import org.junit.jupiter.api.Test;

/** The twelve waypoint types in every format (docs/LEDGER_*.md WEB-100, C3c). */
class WaypointFormatsTest {

  private static final Set<String> HAMMERHEAD_NINE =
      Set.of(
          "Food",
          "Water",
          "Parking",
          "Camping",
          "Lodging",
          "Geocache",
          "Summit",
          "Generic",
          "Danger");

  @Test
  void everyType_hasSymbolFitCourseApiHammerheadAndLabel() {
    for (WaypointType type : WaypointType.values()) {
      assertFalse(WaypointFormats.garminSymbol(type).isBlank(), type.name());
      assertEquals(
          WaypointFormats.fitType(type).name().toLowerCase(java.util.Locale.ROOT),
          WaypointFormats.gpxType(type));
      assertEquals(WaypointFormats.fitType(type).name(), WaypointFormats.courseApiType(type));
      assertFalse(WaypointFormats.hammerhead(type).isBlank(), type.name());
      assertFalse(WaypointFormats.label(type).isBlank(), type.name());
    }
    assertEquals(FitCoursePointType.MEETING_SPOT, WaypointFormats.fitType(WaypointType.REGROUP));
    assertEquals(FitCoursePointType.AID_STATION, WaypointFormats.fitType(WaypointType.SUPPLY));
    assertEquals(FitCoursePointType.FOOD, WaypointFormats.fitType(WaypointType.CAFE));
    assertEquals(FitCoursePointType.TOILET, WaypointFormats.fitType(WaypointType.TOILETS));
    assertEquals(FitCoursePointType.OVERLOOK, WaypointFormats.fitType(WaypointType.VIEWPOINT));
    assertEquals(FitCoursePointType.GEAR, WaypointFormats.fitType(WaypointType.BIKE_SHOP));
    // W3
    assertEquals(FitCoursePointType.CHECKPOINT, WaypointFormats.fitType(WaypointType.REAL_START));
    assertEquals(FitCoursePointType.ALERT, WaypointFormats.fitType(WaypointType.SPLIT));
    assertEquals("Flag, Green", WaypointFormats.garminSymbol(WaypointType.REAL_START));
  }

  @Test
  void hammerheadValues_areAmongTheNine() {
    for (WaypointType type : WaypointType.values()) {
      assertTrue(HAMMERHEAD_NINE.contains(WaypointFormats.hammerhead(type)), type.name());
    }
    assertEquals("Food", WaypointFormats.hammerhead(WaypointType.SUPPLY));
    assertEquals("Water", WaypointFormats.hammerhead(WaypointType.WATER));
    assertEquals("Danger", WaypointFormats.hammerhead(WaypointType.DANGER));
    assertEquals("Summit", WaypointFormats.hammerhead(WaypointType.SUMMIT));
    assertEquals("Generic", WaypointFormats.hammerhead(WaypointType.REGROUP));
  }

  @Test
  void pedalonsGpx_roundTripsAllTwelveTypes() {
    for (WaypointType type : WaypointType.values()) {
      assertEquals(
          type,
          WaypointFormats.fromGpx(
              WaypointFormats.garminSymbol(type), WaypointFormats.gpxType(type)),
          type.name());
      assertEquals(type, WaypointFormats.fromGpx(WaypointFormats.garminSymbol(type), null));
    }
  }

  @Test
  void canonicalNames_areRecognised() {
    // What the sanitizer writes, and so what a second pass reads
    for (WaypointType type : WaypointType.values()) {
      assertEquals(type, WaypointFormats.fromGpx(null, type.name()), type.name());
    }
  }

  @Test
  void symWinsOverType() {
    assertEquals(WaypointType.REAL_START, WaypointFormats.fromGpx("Flag, Green", "info"));
    assertEquals(WaypointType.CAFE, WaypointFormats.fromGpx("Restaurant", "water"));
  }

  @Test
  void checkpointOrAlertAlone_isInfo() {
    assertEquals(WaypointType.INFO, WaypointFormats.fromGpx(null, "checkpoint"));
    assertEquals(WaypointType.INFO, WaypointFormats.fromGpx(null, "alert"));
    assertEquals(WaypointType.INFO, WaypointFormats.fromGpx("Generic", "alert"));
  }

  @Test
  void matching_ignoresCaseAndSpaces() {
    assertEquals(WaypointType.WATER, WaypointFormats.fromGpx("  DRINKING   water ", null));
    assertEquals(WaypointType.SUMMIT, WaypointFormats.fromGpx(null, "Summit"));
    assertEquals(WaypointType.CAFE, WaypointFormats.fromGpx("Food", "Food"));
  }

  @Test
  void unknown_isInfo() {
    assertEquals(WaypointType.INFO, WaypointFormats.fromGpx(null, null));
    assertEquals(WaypointType.INFO, WaypointFormats.fromGpx("", " "));
    assertEquals(WaypointType.INFO, WaypointFormats.fromGpx("Pin, Red", "whatever"));
    assertEquals(WaypointType.INFO, WaypointFormats.fromGpx("Parking", null));
  }

  @Test
  void fitName_cutsAt15CodePoints_notUtf16Units() {
    String bikers = "🚴".repeat(20);
    String cut = WaypointFormats.fitName(bikers, WaypointType.INFO);

    assertEquals(15, cut.codePointCount(0, cut.length()));
    assertEquals(30, cut.length(), "two UTF-16 units each, none of them split");
    assertEquals("🚴".repeat(15), cut);

    assertEquals("é".repeat(15), WaypointFormats.fitName("é".repeat(20), WaypointType.INFO));
    assertEquals("Café du coin", WaypointFormats.fitName("Café du coin", WaypointType.INFO));
  }

  @Test
  void fitName_cutsAtAWordWhenPossible() {
    assertEquals(
        "Ravitaillement",
        WaypointFormats.fitName("Ravitaillement Intermarché", WaypointType.SUPPLY));
    // The only space is too early: a cut at it would leave almost nothing
    assertEquals(
        "Abc defghijklmn", WaypointFormats.fitName("Abc defghijklmnopqrstuvw", WaypointType.INFO));
  }

  @Test
  void fitName_emptyName_isTheTypeLabel() {
    assertEquals("Eau", WaypointFormats.fitName("  ", WaypointType.WATER));
    assertEquals("Café", WaypointFormats.fitName(null, WaypointType.CAFE));
    assertEquals("Départ réel", WaypointFormats.fitName("\n\t", WaypointType.REAL_START));
  }

  @Test
  void fitName_dropsControlCharacters() {
    assertEquals("Café Bar 1", WaypointFormats.fitName("Café\nBar\t1", WaypointType.INFO));
  }
}
