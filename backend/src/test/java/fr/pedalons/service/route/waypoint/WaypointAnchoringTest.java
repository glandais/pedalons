package fr.pedalons.service.route.waypoint;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.enums.WaypointOrigin;
import fr.pedalons.enums.WaypointType;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * Placing waypoints on a track (docs/LEDGER_*.md WEB-100, C3c, W4): pure geometry, no Quarkus.
 *
 * <p>The fixtures are straight lines north (or a square) at 45°N, a point every 100 m, whose
 * stored distances are the ones of the axis.
 */
class WaypointAnchoringTest {

  private static final double M_PER_DEG_LAT = Math.PI / 180 * 6_371_008.8;
  private static final double LAT0 = 45.0;
  private static final double LNG0 = 6.0;

  private static double lat(double metersNorth) {
    return LAT0 + metersNorth / M_PER_DEG_LAT;
  }

  private static double lng(double lngBase, double metersEast) {
    return lngBase + metersEast / (M_PER_DEG_LAT * Math.cos(Math.toRadians(LAT0)));
  }

  /** North from the origin, a point every 100 m, {@code length} metres. */
  private static List<TrackPoint> north(double fromDist, double lngBase, int length) {
    List<TrackPoint> points = new ArrayList<>();
    for (int m = 0; m <= length; m += 100) {
      points.add(new TrackPoint(lat(m), lng(lngBase, 0), 100, fromDist + m));
    }
    return points;
  }

  private static TrackAxis straight(int length) {
    return TrackAxis.ofPointLists(List.of(north(0, LNG0, length)));
  }

  /** Out 1 000 m and back by the same road: 2 000 m, two passages by every point. */
  private static TrackAxis outAndBack() {
    List<TrackPoint> points = new ArrayList<>(north(0, LNG0, 1000));
    for (int m = 900; m >= 0; m -= 100) {
      points.add(new TrackPoint(lat(m), LNG0, 100, 2000 - m));
    }
    return TrackAxis.ofPointLists(List.of(points));
  }

  private static WaypointDraft draft(double lat, double lng, Double hint, Double hintTotal) {
    return new WaypointDraft(
        null, lat, lng, "p", null, WaypointType.INFO, WaypointOrigin.AUTHOR, hint, hintTotal);
  }

  private static WaypointDraft draft(double lat, double lng) {
    return draft(lat, lng, null, null);
  }

  private static Double place(TrackAxis axis, WaypointDraft draft) {
    return WaypointAnchoring.anchor(axis, List.of(draft)).getFirst().distance();
  }

  @Test
  void pointOnStraightLine_distanceIsItsProjection() {
    Double distance = place(straight(1000), draft(lat(450), lng(LNG0, 10)));

    assertNotNull(distance);
    assertEquals(450, distance, 1.0);
  }

  @Test
  void at49m_isOnTrack_at51m_isOffTrack() {
    TrackAxis axis = straight(1000);

    assertNotNull(place(axis, draft(lat(500), lng(LNG0, 49))));
    assertNull(place(axis, draft(lat(500), lng(LNG0, 51))));
  }

  @Test
  void outAndBack_withoutHint_takesFirstPassage() {
    Double distance = place(outAndBack(), draft(lat(500), lng(LNG0, 5)));

    assertEquals(500, distance, 1.0);
  }

  @Test
  void outAndBack_withHint_takesNearestPassage() {
    Double distance = place(outAndBack(), draft(lat(500), lng(LNG0, 5), 1480.0, null));

    assertEquals(1500, distance, 1.0);
  }

  @Test
  void hint_isScaledToTheNewLength() {
    // 1 100 m on a track of 4 400 m is 550 m on one of 2 000: the first passage. Unscaled, 1 100
    // would be nearer the second one
    Double distance = place(outAndBack(), draft(lat(500), lng(LNG0, 5), 1100.0, 4400.0));

    assertEquals(500, distance, 1.0);
  }

  @Test
  void editorDistance_isUsedAsIs() {
    Double distance = place(outAndBack(), draft(lat(500), lng(LNG0, 5), 1450.0, null));

    assertEquals(1500, distance, 1.0);
  }

  @Test
  void sharedVertex_countsAsOnePassage() {
    // Exactly on the vertex at 500 m: both segments around it are candidates, at the same place
    Double distance = place(straight(1000), draft(lat(500), LNG0));

    assertEquals(500, distance, 0.5);
  }

  @Test
  void uTurnWithin50m_isOnePassage() {
    // 1 000 m north, 30 m east, 1 000 m back south: the point at the top is near the three legs
    List<TrackPoint> points = new ArrayList<>(north(0, LNG0, 1000));
    double east = lng(LNG0, 30);
    points.add(new TrackPoint(lat(1000), east, 100, 1030));
    for (int m = 900; m >= 0; m -= 100) {
      points.add(new TrackPoint(lat(m), east, 100, 2030 - m));
    }
    TrackAxis axis = TrackAxis.ofPointLists(List.of(points));
    WaypointDraft draft = draft(lat(1000), lng(LNG0, 15));

    Double first = place(axis, draft);
    Double hinted =
        place(
            axis,
            new WaypointDraft(
                null,
                draft.lat(),
                draft.lng(),
                "p",
                null,
                WaypointType.INFO,
                WaypointOrigin.AUTHOR,
                2000.0,
                null));

    assertNotNull(first);
    assertEquals(1015, first, 5.0);
    assertEquals(first, hinted, "one passage: the hint has nothing to choose");
  }

  @Test
  void multiTrack_distanceIsCumulative_withoutGap() {
    // The second track starts far away, its own distances from 0: the axis does not count the gap
    List<TrackPoint> second = north(0, LNG0 + 0.1, 1000);
    TrackAxis axis = TrackAxis.ofPointLists(List.of(north(0, LNG0, 1000), second));

    Double distance = place(axis, draft(lat(300), lng(LNG0 + 0.1, 5)));

    assertNotNull(distance);
    assertEquals(1300, distance, 1.0);
    assertEquals(2000, axis.total(), 0.001);
  }

  @Test
  void zeroLengthSegment_isHarmless() {
    List<TrackPoint> points = new ArrayList<>(north(0, LNG0, 500));
    // A repeated point: a segment of no length, which adds no distance
    points.add(1, points.get(1));
    TrackAxis axis = TrackAxis.ofPointLists(List.of(points));

    Double distance = place(axis, draft(lat(100), lng(LNG0, 2)));

    assertNotNull(distance);
    assertFalse(Double.isNaN(distance));
    assertEquals(100, distance, 1.0);
  }

  @Test
  void offTrack_keepsPosition_nullDistance() {
    WaypointDraft draft = draft(lat(500), lng(LNG0, 400));

    AnchoredWaypoint placed = WaypointAnchoring.anchor(straight(1000), List.of(draft)).getFirst();

    assertNull(placed.distance());
    assertTrue(placed.offTrack());
    assertEquals(draft.lat(), placed.lat());
    assertEquals(draft.lng(), placed.lng());
  }

  @Test
  void loopStartEqualsEnd_withoutHint_isKmZero() {
    // A square of 300 m: the start and the end are the same place, 1 200 m apart along the track
    List<TrackPoint> square = new ArrayList<>();
    square.add(new TrackPoint(lat(0), lng(LNG0, 0), 100, 0));
    square.add(new TrackPoint(lat(300), lng(LNG0, 0), 100, 300));
    square.add(new TrackPoint(lat(300), lng(LNG0, 300), 100, 600));
    square.add(new TrackPoint(lat(0), lng(LNG0, 300), 100, 900));
    square.add(new TrackPoint(lat(0), lng(LNG0, 0), 100, 1200));
    TrackAxis axis = TrackAxis.ofPointLists(List.of(square));

    Double withoutHint = place(axis, draft(lat(0), lng(LNG0, 0)));
    Double nearTheEnd = place(axis, draft(lat(0), lng(LNG0, 0), 1190.0, null));

    assertNotNull(withoutHint);
    assertEquals(0, withoutHint, 1.0);
    assertNotNull(nearTheEnd);
    assertEquals(1200, nearTheEnd, 1.0);
  }
}
