package fr.pedalons.service.route.waypoint;

import fr.pedalons.domain.route.GpxWaypoint;
import fr.pedalons.enums.WaypointOrigin;
import fr.pedalons.enums.WaypointType;
import java.util.Collection;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * A waypoint placed on a track: {@code distance} is its distance along the tracks in order, null
 * when it lies more than {@link WaypointAnchoring#SNAP_RADIUS_M} from every one of them (W5). The
 * position is always the one the author wanted, never its projection.
 */
public record AnchoredWaypoint(
    @Nullable Long id,
    double lat,
    double lng,
    String name,
    @Nullable String description,
    WaypointType type,
    WaypointOrigin origin,
    @Nullable Double distance) {

  public boolean offTrack() {
    return distance == null;
  }

  /** The stored rows as placed waypoints; a row written before C3c reads as INFO. */
  public static List<AnchoredWaypoint> fromRows(Collection<GpxWaypoint> rows) {
    return rows.stream().map(AnchoredWaypoint::fromRow).toList();
  }

  public static AnchoredWaypoint fromRow(GpxWaypoint row) {
    return new AnchoredWaypoint(
        row.getId(),
        row.getGeometry().getPosition().getLat(),
        row.getGeometry().getPosition().getLon(),
        row.getName(),
        row.getDescription(),
        row.typeOrInfo(),
        row.getOrigin(),
        row.getDistanceM());
  }
}
