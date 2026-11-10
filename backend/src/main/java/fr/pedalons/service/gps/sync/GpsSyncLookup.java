package fr.pedalons.service.gps.sync;

import fr.pedalons.dto.gps.response.RouteGpsSyncStatusDto;
import fr.pedalons.dto.gps.response.RouteGpsSyncStatuses;
import fr.pedalons.service.gps.sync.GpsRouteSyncService.RouteSyncStatus;
import fr.pedalons.service.security.PedalonsQueryContext;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * Resolves {@code gpsSyncStatuses} for a set of routes, in bulk (docs/LEDGER_*.md API-120): where
 * each route stands at those of the <b>caller's</b> GPS services whose automatic sync is on.
 *
 * <p>One entry per such service that holds the route — an automatic row (one of the caller's rides
 * or trip stages uses it) or a tracked manual upload to that service. A service connected without
 * the automatic sync gives no entry, even with a manual upload: the field reports the sync, not
 * every upload.
 *
 * <p>It costs a page, not a row: {@link GpsRouteSyncService#findRouteStatuses}, at most two
 * queries whatever the number of routes. An anonymous caller, or no route, costs nothing.
 *
 * <p>Only the caller's own rows are read — the user id is the request's, never the routes' owner —
 * and every query filters by the request's domain.
 */
@ApplicationScoped
public class GpsSyncLookup {

  private static final Comparator<RouteGpsSyncStatusDto> BY_SERVICE =
      Comparator.comparing(RouteGpsSyncStatusDto::serviceType);

  @Inject GpsRouteSyncService syncService;

  @Inject PedalonsQueryContext pedalonsContext;

  /** The statuses of these routes; null ids are ignored. */
  public RouteGpsSyncStatuses forRoutes(Collection<Long> routeIds) {
    Long userId = pedalonsContext.getUserIdNullable();
    if (userId == null) {
      return RouteGpsSyncStatuses.NONE;
    }
    List<Long> ids = routeIds.stream().filter(Objects::nonNull).distinct().toList();
    if (ids.isEmpty()) {
      return RouteGpsSyncStatuses.NONE;
    }
    Map<Long, List<RouteSyncStatus>> found =
        syncService.findRouteStatuses(pedalonsContext.getDomainId(), userId, ids);
    Map<Long, List<RouteGpsSyncStatusDto>> byRoute = new HashMap<>();
    found.forEach((routeId, statuses) -> {
      List<RouteGpsSyncStatusDto> dtos =
          statuses.stream()
              .filter(RouteSyncStatus::autoSync)
              .map(s -> new RouteGpsSyncStatusDto(s.serviceType(), s.state(), s.syncedAt()))
              .sorted(BY_SERVICE)
              .toList();
      if (!dtos.isEmpty()) {
        byRoute.put(routeId, dtos);
      }
    });
    return byRoute.isEmpty() ? RouteGpsSyncStatuses.NONE : new RouteGpsSyncStatuses(byRoute);
  }
}
