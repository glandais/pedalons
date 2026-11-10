package fr.pedalons.dto.gps.response;

import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;

/**
 * Where each route of a page stands at the caller's GPS services in automatic sync
 * (docs/LEDGER_*.md API-120), <b>for the caller asking</b>: built from their own connections only.
 *
 * <p>Built by {@code fr.pedalons.service.gps.sync.GpsSyncLookup}, always in bulk for a whole page
 * or response — at most two queries, whatever the number of routes, none for an anonymous caller.
 *
 * @param byRouteId route id → its statuses, sorted by service; a route absent from the map is held
 *     by none of the caller's synced services
 */
public record RouteGpsSyncStatuses(Map<Long, List<RouteGpsSyncStatusDto>> byRouteId) {

  /** Nothing known — what an anonymous caller sees, and a response not meant to report a state. */
  public static final RouteGpsSyncStatuses NONE = new RouteGpsSyncStatuses(Map.of());

  /** This route's statuses, one per service and sorted by service; empty when there is none. */
  public List<RouteGpsSyncStatusDto> forRoute(@Nullable Long routeId) {
    return routeId == null ? List.of() : byRouteId.getOrDefault(routeId, List.of());
  }

  /**
   * The value of a DTO's {@code gpsSyncStatuses} field: {@link #forRoute}, or {@code null} when it
   * is empty — Jackson is configured {@code NON_NULL}, so the field is left out of the JSON rather
   * than repeated as {@code []} on every row of a list. Absent and empty mean the same thing.
   */
  public @Nullable List<RouteGpsSyncStatusDto> fieldFor(@Nullable Long routeId) {
    List<RouteGpsSyncStatusDto> statuses = forRoute(routeId);
    return statuses.isEmpty() ? null : statuses;
  }
}
