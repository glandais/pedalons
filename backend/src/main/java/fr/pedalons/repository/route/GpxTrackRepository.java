package fr.pedalons.repository.route;

import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.PlannerStateDocument;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
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
}
