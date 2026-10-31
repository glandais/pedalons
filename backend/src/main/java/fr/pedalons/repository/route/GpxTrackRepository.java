package fr.pedalons.repository.route;

import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.PlannerStateDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import io.hypersistence.utils.hibernate.type.util.JsonConfiguration;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.geolatte.geom.G2D;
import org.geolatte.geom.LineString;
import org.jspecify.annotations.Nullable;

/**
 * Direct reads of the GPX tracks, for what must not go through {@code Route#getTracks()}: loading
 * that collection reads every track's {@code track_points} JSON, which the weather only needs on a
 * cache miss.
 *
 * <p>No domain filter: callers come with routes they already resolved through a ride.
 */
@ApplicationScoped
public class GpxTrackRepository implements PanacheRepository<GpxTrack> {

  /**
   * Track ids per route, ascending — the order the weather chains a multi-track route in. One
   * query for all the routes, without the track points.
   */
  public Map<Long, List<Long>> findIdsByRouteIds(Collection<Long> routeIds) {
    if (routeIds.isEmpty()) {
      return Map.of();
    }
    Map<Long, List<Long>> ids = new HashMap<>();
    getEntityManager()
        .createQuery(
            "select t.route.id, t.id from GpxTrack t where t.route.id in :routeIds"
                + " order by t.route.id, t.id",
            Object[].class)
        .setParameter("routeIds", routeIds)
        .getResultList()
        .forEach(
            row -> ids.computeIfAbsent((Long) row[0], k -> new ArrayList<>()).add((Long) row[1]));
    return ids;
  }

  /** The tracks themselves, in id order. */
  public List<GpxTrack> findTracksByIds(Collection<Long> ids) {
    if (ids.isEmpty()) {
      return List.of();
    }
    return list("id in ?1 order by id", ids);
  }

  /**
   * The planner state column of each track of a route, in id order: a projection, so no {@code
   * track_points} is read (docs/LEDGER_*.md WEB-100). A track without state is a null element.
   */
  public List<@Nullable PlannerStateDocument> findPlannerStates(Long routeId) {
    return getEntityManager()
        .createQuery(
            "select t.plannerState from GpxTrack t where t.route.id = :routeId order by t.id",
            PlannerStateDocument.class)
        .setParameter("routeId", routeId)
        .getResultList();
  }

  /** A track's id and its points, read without the rest of the row. */
  public record TrackPoints(Long trackId, List<GpxTrack.TrackPoint> points) {}

  /**
   * The points of each track of a route, in id order: a projection, so no planner state is read
   * (docs/LEDGER_*.md WEB-100, C1b).
   */
  public List<TrackPoints> findPoints(Long routeId) {
    return getEntityManager()
        .createQuery(
            "select t.id, t.trackPoints from GpxTrack t where t.route.id = :routeId order by t.id",
            Object[].class)
        .setParameter("routeId", routeId)
        .getResultList()
        .stream()
        .map(row -> new TrackPoints((Long) row[0], castPoints(row[1])))
        .toList();
  }

  /**
   * The raw line of each track of a route by track id, as {@code [lng, lat]} pairs, tracks whose
   * line is not known (a row that predates the column) left out: a projection, so neither the
   * points, the planner state nor the surfaces are read (docs/LEDGER_*.md API-147).
   */
  public Map<Long, List<double[]>> findRawLines(Long routeId) {
    Map<Long, List<double[]>> out = new HashMap<>();
    getEntityManager()
        .createQuery(
            "select t.id, t.rawGeometry from GpxTrack t where t.route.id = :routeId order by t.id",
            Object[].class)
        .setParameter("routeId", routeId)
        .getResultList()
        .forEach(
            row -> {
              if (row[1] instanceof LineString<?> line) {
                out.put((Long) row[0], lngLat(line));
              }
            });
    return out;
  }

  private static List<double[]> lngLat(LineString<?> line) {
    List<double[]> out = new ArrayList<>(line.getNumPositions());
    for (int i = 0; i < line.getNumPositions(); i++) {
      if (line.getPositionN(i) instanceof G2D p) {
        out.add(new double[] {p.getLon(), p.getLat()});
      }
    }
    return out;
  }

  @SuppressWarnings("unchecked")
  private static List<GpxTrack.TrackPoint> castPoints(Object points) {
    return (List<GpxTrack.TrackPoint>) points;
  }

  /**
   * The surface documents of a route's tracks by track id, tracks without one left out: a
   * projection, so neither the points nor the planner state are read (docs/LEDGER_*.md WEB-100,
   * C1b).
   */
  public Map<Long, TrackSurfaceDocument> findSurfaces(Long routeId) {
    Map<Long, TrackSurfaceDocument> out = new HashMap<>();
    getEntityManager()
        .createQuery(
            "select t.id, t.surfaces from GpxTrack t where t.route.id = :routeId order by t.id",
            Object[].class)
        .setParameter("routeId", routeId)
        .getResultList()
        .forEach(
            row -> {
              if (row[1] != null) {
                out.put((Long) row[0], (TrackSurfaceDocument) row[1]);
              }
            });
    return out;
  }

  /**
   * As {@link #findSurfaces(Long)}, for a batch of routes: one query whatever their number, keyed
   * by route id then track id. Routes without any stored document are absent.
   */
  public Map<Long, Map<Long, TrackSurfaceDocument>> findSurfacesByRouteIds(
      Collection<Long> routeIds) {
    if (routeIds.isEmpty()) {
      return Map.of();
    }
    Map<Long, Map<Long, TrackSurfaceDocument>> out = new HashMap<>();
    getEntityManager()
        .createQuery(
            "select t.route.id, t.id, t.surfaces from GpxTrack t where t.route.id in :routeIds",
            Object[].class)
        .setParameter("routeIds", routeIds)
        .getResultList()
        .forEach(
            row -> {
              if (row[2] != null) {
                out.computeIfAbsent((Long) row[0], k -> new HashMap<>())
                    .put((Long) row[1], (TrackSurfaceDocument) row[2]);
              }
            });
    return out;
  }

  /**
   * Stores the surface of a track, with no read of the row (its points are not needed). Native
   * with a cast of the serialized document, which leaves nothing to the binding of a JSON type in
   * an update.
   */
  public void updateSurfaces(Long trackId, TrackSurfaceDocument surfaces) {
    getEntityManager()
        .createNativeQuery("update gpx_tracks set surfaces = cast(:doc as jsonb) where id = :id")
        .setParameter("doc", JsonConfiguration.INSTANCE.getObjectMapperWrapper().toString(surfaces))
        .setParameter("id", trackId)
        .executeUpdate();
  }

  /** A track's id and its number of stored points, without reading them. */
  public record TrackSize(Long trackId, int points) {}

  /**
   * The id and the number of stored points of each track of a route, in id order: a native
   * projection, so neither the points nor any lazy column are loaded (docs/LEDGER_*.md API-147,
   * phase D).
   */
  public List<TrackSize> findSizes(Long routeId) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        getEntityManager()
            .createNativeQuery(
                "select id, jsonb_array_length(track_points) from gpx_tracks"
                    + " where route_id = :routeId order by id")
            .setParameter("routeId", routeId)
            .getResultList();
    return rows.stream()
        .map(r -> new TrackSize(((Number) r[0]).longValue(), ((Number) r[1]).intValue()))
        .toList();
  }

  /**
   * Writes a track's raw line unless it has one by now (docs/LEDGER_*.md API-147, phase D): a save
   * writes the line of the track it puts, and that one wins.
   *
   * @return whether the row was written
   */
  public boolean fillRawGeometry(Long trackId, LineString<G2D> raw) {
    return getEntityManager()
            .createQuery(
                "update GpxTrack t set t.rawGeometry = :raw"
                    + " where t.id = :id and t.rawGeometry is null")
            .setParameter("raw", raw)
            .setParameter("id", trackId)
            .executeUpdate()
        > 0;
  }
}
