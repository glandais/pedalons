package fr.pedalons.service.route.waypoint;

import static org.geolatte.geom.builder.DSL.g;
import static org.geolatte.geom.builder.DSL.point;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;

import fr.pedalons.domain.route.GpxWaypoint;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.user.User;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.jspecify.annotations.Nullable;

/**
 * Writes placed waypoints onto a route's rows <b>in place</b> (docs/LEDGER_*.md WEB-100, C3c).
 *
 * <p>Never a {@code clear()} of {@code Route.waypoints} followed by a refill: that collection is an
 * orphan-removal one, and any query between the two deletes the elements for good (HHH90032003).
 * A row whose id the new list carries is updated, a row it no longer carries is removed one by
 * one, and a point with no row is a new one.
 */
public final class WaypointRows {

  /** Distances closer than a centimetre are the same. */
  private static final double DISTANCE_EPSILON_M = 0.01;

  private static final double POSITION_EPSILON_DEG = 1e-9;

  private WaypointRows() {}

  public static void apply(Route route, List<AnchoredWaypoint> anchored, User creator) {
    Map<Long, GpxWaypoint> byId = new HashMap<>();
    for (GpxWaypoint row : route.getWaypoints()) {
      byId.put(row.getId(), row);
    }
    Set<Long> kept = new HashSet<>();
    for (AnchoredWaypoint w : anchored) {
      GpxWaypoint row = w.id() == null ? null : byId.get(w.id());
      if (row != null && kept.add(row.getId())) {
        update(row, w);
      } else {
        route.addWaypoint(
            new GpxWaypoint(
                creator,
                w.name(),
                w.description(),
                point(WGS84, g(w.lng(), w.lat())),
                w.type(),
                w.origin(),
                w.distance()));
      }
    }
    for (GpxWaypoint row : List.copyOf(route.getWaypoints())) {
      if (row.getId() != null && byId.containsKey(row.getId()) && !kept.contains(row.getId())) {
        route.removeWaypoint(row);
      }
    }
  }

  /** Only the distances, by id: what the HD catch-up changes. */
  public static void updateDistances(Route route, List<AnchoredWaypoint> anchored) {
    Map<Long, AnchoredWaypoint> byId = new HashMap<>();
    for (AnchoredWaypoint w : anchored) {
      if (w.id() != null) {
        byId.put(w.id(), w);
      }
    }
    for (GpxWaypoint row : route.getWaypoints()) {
      AnchoredWaypoint w = byId.get(row.getId());
      if (w != null) {
        row.setDistanceM(w.distance());
      }
    }
  }

  private static void update(GpxWaypoint row, AnchoredWaypoint w) {
    row.setName(w.name());
    row.setDescription(w.description());
    row.setType(w.type());
    row.setDistanceM(w.distance());
    if (!samePosition(row, w)) {
      row.setGeometry(point(WGS84, g(w.lng(), w.lat())));
    }
    // The origin stays the row's: only its creator decides it
  }

  private static boolean samePosition(GpxWaypoint row, AnchoredWaypoint w) {
    return Math.abs(row.getGeometry().getPosition().getLat() - w.lat()) < POSITION_EPSILON_DEG
        && Math.abs(row.getGeometry().getPosition().getLon() - w.lng()) < POSITION_EPSILON_DEG;
  }

  /**
   * Whether the rows already are {@code anchored}: same size, and every point names a row (by id)
   * with the same content. Writing it again would change nothing.
   *
   * @param withDistance whether the distances take part (a catch-up that re-anchors them compares
   *     without)
   */
  public static boolean sameContent(
      Collection<GpxWaypoint> rows, List<AnchoredWaypoint> anchored, boolean withDistance) {
    if (rows.size() != anchored.size()) {
      return false;
    }
    Map<Long, GpxWaypoint> byId = new HashMap<>();
    rows.forEach(r -> byId.put(r.getId(), r));
    for (AnchoredWaypoint w : anchored) {
      GpxWaypoint row = w.id() == null ? null : byId.remove(w.id());
      if (row == null
          || row.typeOrInfo() != w.type()
          || !Objects.equals(row.getName(), w.name())
          || !Objects.equals(row.getDescription(), w.description())
          || row.getOrigin() != w.origin()
          || !samePosition(row, w)
          || (withDistance && !sameDistance(row.getDistanceM(), w.distance()))) {
        return false;
      }
    }
    return true;
  }

  public static boolean sameDistance(@Nullable Double a, @Nullable Double b) {
    if (a == null || b == null) {
      return a == null && b == null;
    }
    return Math.abs(a - b) < DISTANCE_EPSILON_M;
  }
}
