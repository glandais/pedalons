package fr.pedalons.service.route.generator;

import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * A street-graph edge ridden by a team track, as osm-route-details api 1.7 reports it (design §12.1).
 * The record is JSON-free: lot 1 maps the response and passes the geometry as received.
 *
 * @param from start of the COMPLETE edge in travel direction, even when the track does not reach
 *     it; null = unknown end
 * @param to end of the complete edge in travel direction; null = unknown end
 * @param partial the track does not cover the complete edge
 * @param lengthM length of the complete edge; null iff {@code from} or {@code to} is null
 * @param traversedM length covered by the track
 * @param fromOffsetM offsets along the complete edge counted from {@code from}; null iff {@code
 *     from} is null
 * @param geometry the traversed part only, snapped, travel order
 * @param gainM gain over the traversed part
 * @param trackType api 1.8, absent today
 * @param bicycle api 1.8, absent today; absent is untagged or mixed, NOT forbidden
 * @param foot api 1.8, absent today; diagnostics only
 */
public record TrackEdge(
    @Nullable NodeRef from,
    @Nullable NodeRef to,
    boolean partial,
    @Nullable Double lengthM,
    double traversedM,
    @Nullable Double fromOffsetM,
    @Nullable Double toOffsetM,
    Oneway oneway,
    List<LatLon> geometry,
    double gainM,
    double lossM,
    @Nullable EdgeSurface surface,
    @Nullable WayKind wayKind,
    @Nullable OsmTrackType trackType,
    @Nullable Access bicycle,
    @Nullable Access foot) {

  public TrackEdge {
    geometry = List.copyOf(geometry);
    if (!(traversedM >= 0)) {
      throw new IllegalArgumentException("traversedM must be >= 0: " + traversedM);
    }
  }
}
